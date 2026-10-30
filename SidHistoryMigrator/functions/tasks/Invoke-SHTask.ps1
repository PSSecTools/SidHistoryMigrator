function Invoke-SHTask {
	<#
	.SYNOPSIS
		Scans configured source scopes and migrates a saved task's matching principals.

	.DESCRIPTION
		Loads the task's saved credentials, tests LDAP access to both endpoints, and uses
		PSFramework runspace workers to search source users and groups and match destination
		objects using the task's configured attributes. Skips AdminCount-protected principals
		unless AllowAdminCount is enabled, and avoids copying SID history already present.
		Records matching failures, migration results, and test-mode outcomes in a JSON action log.

	.PARAMETER Task
		A single task definition returned by Get-SHTask. This parameter does not accept
		pipeline input; supply the object explicitly.

	.PARAMETER Config
		A hashtable containing a Scopes collection. Each scope requires Path (a source
		distinguished name) and can specify Filter (an LDAP filter) and Type (User or Group).
		Omitting Type searches both categories. Searches currently use Subtree scope;
		a SearchScope entry is not applied. Null or empty Scopes cause the task to be skipped.

	.INPUTS
		None. Parameters do not accept pipeline input.

	.OUTPUTS
		None. Writes task results through Write-ActionLog rather than returning them.

	.EXAMPLE
		PS C:\> $task = Get-SHTask -Name 'Pilot'
		PS C:\> $config = @{ Scopes = @(@{ Path = 'OU=Pilot,DC=source,DC=contoso,DC=com'; Type = 'User' }) }
		PS C:\> Invoke-SHTask -Task $task -Config $config

		Runs the saved Pilot task for users beneath the source Pilot OU. Use a task
		saved with TestRun enabled to record WouldMigrate without writing SID history.

	.NOTES
		Tasks normally run through Invoke-SHMigration, which also configures logging providers.
		TestRun still performs authentication, directory reads, and JSON log writes. This
		command has no WhatIf parameter. Worker failures are generally logged per principal
		or scope rather than returned as output objects. Common result statuses include
		NoMatch, Ambiguous, Pending, Migrated, WouldMigrate, Failed, and Skipped.

	.LINK
		Invoke-SHMigration

	.LINK
		New-SHTask
	#>
	[CmdletBinding()]
	param (
		$Task,

		[AllowNull()]
		[hashtable]
		$Config
	)
	begin {
		$code_UserScan = {
			param ($Scope)

			$ErrorActionPreference = 'Stop'
			trap {
				Write-PSFMessage @msgParam -Level Error -String 'Invoke-SHTask.Error.Scope.Unexpected' -StringValues $Scope.Path, "$_" -ErrorRecord $_ -ErrorStack -Tag fail, unexpected, 500
				return
			}

			function Write-Result {
				<#
				.SYNOPSIS
					Queues a principal-matching or migration result.

				.DESCRIPTION
					Helper local to the task's scan worker. Creates a timestamped record and
					writes it to a queue in the current PSFramework runspace workflow.

				.PARAMETER FromUser
					The source LDAP principal, including its SamAccountName.

				.PARAMETER ToUser
					The matched destination principal, if one was found.

				.PARAMETER ErrorRecord
					An optional error. Overrides Status with Failed and Message with its text.

				.PARAMETER Status
					The processing state, such as Pending, Migrated, NoMatch, or Ambiguous.

				.PARAMETER Message
					Optional explanatory text for the record.

				.PARAMETER Queue
					The current workflow queue to receive the record. Defaults to ADUsers for
					migration work; use ActionsTaken for results requiring no migration attempt.

				.INPUTS
					None. Parameters do not accept pipeline input.

				.OUTPUTS
					None. Sends an object to the selected workflow queue.

				.EXAMPLE
					PS C:\> Write-Result -FromUser $principal -Status NoMatch -Message 'No match found' -Queue ActionsTaken

					Queues an unmatched source principal within an active scan worker.
				#>
				[CmdletBinding()]
				param (
					$FromUser,
					$ToUser,
					$ErrorRecord,
					$Status,
					$Message,
					$Queue = 'ADUsers'
				)

				$data = [PSCustomObject]@{
					From       = $FromUser.SamAccountName
					To         = $ToUser.SamAccountName
					FromObject = $FromUser
					ToObject   = $ToUser
					Status     = $Status
					Message    = $Message
					Timestamp  = Get-Date
				}
				if ($ErrorRecord) {
					$data.Status = 'Failed'
					$data.Message = "$ErrorRecord"
				}
				Write-PSFRunspaceQueue -UseCurrent -Name $Queue -Value $data
			}

			<#
			Scope:
			@{
				# Mandatory
				Path = 'OU=Accounts,DC=contoso,DC=com'

				# Optional:
				Filter = '(foo=bar)'
				Type = 'User'
				SearchScope = 'Subtree' # Base, OneLevel
			}
			#>

			if (-not $Scope.Path) {
				Write-PSFMessage @msgParam -Level Error -Tag config -String 'Invoke-SHTask.Error.Scope.NoPath' -Target $Scope
				return
			}

			$fromParam = @{
				Server     = $Task.From
				Credential = $FromCredential
			}
			$toParam = @{
				Server     = $Task.To
				Credential = $ToCredential
			}
			
			$filters = @()
			if ($Scope.Filter) { $filters += $Scope.Filter }
			if ($Scope.Type -eq 'User') { $filters += '(objectCategory=user)' }
			elseif ($Scope.Type -eq 'Group') { $filters += '(objectCategory=group)' }
			else { $filters += '(|(objectCategory=user)(objectCategory=group))' }

			$ldapFilter = '(&{0})' -f ($filters -join '')
			$properties = 'SamAccountName', 'DistinguishedName', 'ObjectGuid', 'ObjectSID', 'sIDHistory', 'AdminCount', 'ObjectClass'
			if ($Task.FromUserAttribute -notin $properties) { $properties += $Task.FromUserAttribute }
			if ($Task.FromGroupAttribute -notin $properties) { $properties += $Task.FromGroupAttribute }
			
			$toProperties = 'SamAccountName', 'DistinguishedName', 'ObjectGuid', 'sIDHistory'
			if ($Task.ToUserAttribute -notin $toProperties) { $toProperties += $Task.ToUserAttribute }
			if ($Task.ToGroupAttribute -notin $toProperties) { $toProperties += $Task.ToGroupAttribute }

			try {
				Write-PSFMessage @msgParam -String 'Invoke-SHTask.Scope.Searching' -StringValues $Scope.Path, $ldapFilter
				$principals = Get-LdapObject @fromParam -SearchBase $Scope.Path -LdapFilter $ldapFilter -Property $properties -ErrorAction Stop
				Write-PSFMessage @msgParam -String 'Invoke-SHTask.Scope.Found' -StringValues @($principals).Count
			}
			catch {
				Write-PSFMessage @msgParam -Level Error -Tag config -String 'Invoke-SHTask.Error.Scope.ErrorRetrieving' -StringValues $Scope.Path, $ldapFilter -Target $Scope -ErrorRecord $_
				return
			}

			$toAttribute = @{
				user  = $Task.ToUserAttribute
				group = $Task.ToGroupAttribute
			}
			$fromAttribute = @{
				user  = $Task.FromUserAttribute
				group = $Task.FromGroupAttribute
			}

			foreach ($principal in $principals) {
				if ($principal.AdminCount -gt 0 -and -not $Task.AllowAdminCount) { continue }

				$targetPrincipal = $null
				try {
					$toFilter = '(&(objectCategory={0})({1}={2}))' -f $principal.ObjectClass, $toAttribute[$principal.ObjectClass], (Convert-SHAttribute -Value $principal.$($fromAttribute[$principal.ObjectClass]) -FromAttribute $fromAttribute[$principal.ObjectClass] -ToAttribute $toAttribute[$principal.ObjectClass])
					$targetPrincipal = Get-LdapObject @toParam -LdapFilter $toFilter -Property $toProperties -ErrorAction Stop
				}
				catch {
					Write-PSFMessage @msgParam -Level Error -String 'Invoke-SHTask.Error.Query' -StringValues $principal.SamAccountName, $principal.ObjectClass, $toFilter -Target $principal -ErrorRecord $_
					Write-Result -FromUser $principal -ErrorRecord $_ -Queue ActionsTaken
					continue
				}

				if (-not $targetPrincipal) {
					Write-PSFMessage @msgParam -Level Error -String 'Invoke-SHTask.Warning.NoMatch' -StringValues $principal.SamAccountName, $principal.$($fromAttribute[$principal.ObjectClass]), $toAttribute[$principal.ObjectClass] -Target $principal
					Write-Result -FromUser $principal -Status 'NoMatch' -Message 'No match found' -Queue ActionsTaken
					continue
				}

				if (@($targetPrincipal).Count -gt 1) {
					Write-PSFMessage @msgParam -Level Error -String 'Invoke-SHTask.Warning.AmbiguousMatch' -StringValues $principal.SamAccountName, $principal.$($fromAttribute[$principal.ObjectClass]), $toAttribute[$principal.ObjectClass], ($targetPrincipal.SamAccountName -join ',') -Target $principal
					Write-Result -FromUser $principal -Status 'Ambiguous' -Message "Multiple Matches: $($targetPrincipal.SamAccountName -join ',')" -Queue ActionsTaken
					continue
				}

				$isMigrated = $targetPrincipal.SidHistory -contains $principal.ObjectSID
				foreach ($sidEntry in $principal.SidHistory) {
					if ($targetPrincipal.SidHistory -contains $sidEntry) { continue }

					$isMigrated = $false
					break
				}

				if ($isMigrated) {
					Write-Result -FromUser $principal -ToUser $targetPrincipal -Status 'Migrated' -Queue ActionsTaken
					continue
				}

				Write-Result -FromUser $principal -ToUser $targetPrincipal -Status 'Pending'
			}
		}
		$code_Migrator = {
			param ($Principal)

			# Since we're writing directly to the queue, there's an empty entry at the end of each Scope search
			if (-not $Principal) { return }

			if (-not $global:FromSession -or -not $global:ToSession) {
				$Principal.Status = 'Skipped'
				$Principal.Message = 'Authentication Failed'
				return $Principal
			}

			try {
				if ($Task.TestRun) {
					Write-PSFMessage @msgParam -String 'Invoke-SHTask.Executing.TestRun' -StringValues $Principal.From, $Principal.To -Target $Principal
					$Principal.Status = 'WouldMigrate'
				}
				else {
					Copy-SHSidHistory -From $global:FromSession -To $global:ToSession -FromIdentity $Principal.From -ToIdentity $Principal.To
					$Principal.Status = 'Migrated'
				}
				$Principal.Timestamp = Get-Date
			}
			catch {
				$Principal.Status = 'Failed'
				$Principal.Message = "$_"
				$Principal.Timestamp = Get-Date
			}
			$Principal
		}
		$code_Migrator_Begin = {
			try {
				$global:FromSession = New-SHSession -Server $Task.From -Credential $FromCredential
			}
			catch {
				$global:FromSession = $null
				Write-PSFMessage @msgParam -Level Error -String 'Invoke-SHTask.Error.AuthenticationFailed' -StringValues $Task.From -ErrorRecord $_
			}
			try {
				$global:ToSession = New-SHSession -Server $Task.To -Credential $ToCredential
			}
			catch {
				$global:ToSession = $null
				Write-PSFMessage @msgParam -Level Error -String 'Invoke-SHTask.Error.AuthenticationFailed' -StringValues $Task.To -ErrorRecord $_
			}
		}
	}
	process {
		Write-PSFMessage -Level Host -String 'Invoke-SHTask.Task.Starting' -StringValues $Task.Name -Target $Task
		if (-not $Config -or -not $Config.Scopes -or @($Config.Scopes).Count -lt 1) {
			Write-PSFMessage -Level Warning -String 'Invoke-SHTask.Task.NoConfig' -StringValues $Task.Name -Tag noop -Target $Task
			return
		}

		#region Preprocessing
		# Get Credentials
		try {
			$variables = @{
				Task           = $Task
				FromCredential = Import-SHCredential -Name $Task.From
				ToCredential   = Import-SHCredential -Name $Task.To
				msgParam       = @{
					FunctionName = 'Invoke-SHTask'
					ModuleName   = 'SidHistoryMigrator'
				}
			}

			$workerEnv = @{
				Modules   = "$($script:ModuleRoot)\SidHistoryMigrator.psm1" # Give access to internals
				Variables = $variables
			}
		}
		catch {
			Write-PSFMessage -Level Error -String 'Invoke-SHTask.Task.Credentials' -StringValues $Task.Name -Tag fail -Target $Task -ErrorRecord $_
			return
		}

		if (-not (Test-LdapCredential -Server $Task.From -Credential $variables.FromCredential)) {
			Write-PSFMessage -Level Error -String 'Invoke-SHTask.Task.BadCredential' -StringValues $Task.Name, $Task.From -Tag fail -Target $Task
			return
		}
		if (-not (Test-LdapCredential -Server $Task.To -Credential $variables.ToCredential)) {
			Write-PSFMessage -Level Error -String 'Invoke-SHTask.Task.BadCredential' -StringValues $Task.Name, $Task.To -Tag fail -Target $Task
			return
		}
		#endregion Preprocessing

		# Prepare Workflow
		$workflow = New-PSFRunspaceWorkflow -Name 'SidMigration_Executor' -Force

		## Prepare Worker: AD Benutzer Scan
		$scanCount = 5
		if (@($Config.Scopes).Count -lt 5) { $scanCount = @($Config.Scopes).Count }
		$null = $workflow | Add-PSFRunspaceWorker -Name 'User Scan' -Count $scanCount -InQueue Scopes -OutQueue ADUsers @workerEnv -ScriptBlock $code_UserScan -CloseOutQueue
		## Prepare Worker: Migrator
		$null = $workflow | Add-PSFRunspaceWorker -Name 'Migrator' -Count 5 -InQueue ADUsers -OutQueue ActionsTaken @workerEnv -ScriptBlock $code_Migrator -Begin $code_Migrator_Begin -CloseOutQueue
		## Load Scope Selectors from Configuration and Start workflow
		$workflow | Write-PSFRunspaceQueue -Name Scopes -BulkValues $Config.Scopes -Close
		$workflow | Start-PSFRunspaceWorkflow

		# Wait for Completion
		$workflow | Wait-PSFRunspaceWorkflow -Queue ActionsTaken
		$results = Read-PSFRunspaceQueue -InputObject $workflow -Name ActionsTaken -All
		$workflow | Remove-PSFRunspaceWorkflow

		# Log Actions
		Write-ActionLog -Data $results -TaskName $Task.Name
	}
}