function Invoke-SHTask {
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

			function Write-Result {
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
			$properties = 'SamAccountName', 'DistinguishedName', 'ObjectGuid', 'OjectSID', 'sIDHistory', 'AdminCount'
			if ($Task.FromUserAttribute -notin $properties) { $properties += $Task.FromUserAttribute }
			if ($Task.FromGroupAttribute -notin $properties) { $properties += $Task.FromGroupAttribute }
			
			$toProperties = 'SamAccountName', 'DistinguishedName', 'ObjectGuid', 'sIDHistory'
			if ($Task.ToUserAttribute -notin $toProperties) { $toProperties += $Task.ToUserAttribute }
			if ($Task.ToGroupAttribute -notin $toProperties) { $toProperties += $Task.ToGroupAttribute }

			try {
				$principals = Get-LdapObject @fromParam -SearchBase $Scope.Path -LdapFilter $ldapFilter -Property $properties -ErrorAction Stop
			}
			catch {
				Write-PSFMessage @msgParam -Level Error -Tag config -String 'Invoke-SHTask.Error.Scope.ErrorRetrieving' -Target $Scope -ErrorRecord $_
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

				$toFilter = '(&(objectCategory={0})({1}={2}))' -f $principal.ObjectCategory, $toAttribute[$principal.ObjectCategory], $principal.$($fromAttribute[$principal.ObjectCategory])
				$targetPrincipal = $null
				try {
					$targetPrincipal = Get-LdapObject @toParam -LdapFilter $toFilter -Property $toProperties -ErrorAction Stop
				}
				catch {
					Write-PSFMessage @msgParam -Level Error -String 'Invoke-SHTask.Error.Query' -StringValues $principal.SamAccountName, $principal.ObjectCategory, $toFilter -Target $principal -ErrorRecord $_
					Write-Result -FromUser $principal -ErrorRecord $_ -Queue ActionsTaken
					continue
				}

				if (-not $targetPrincipal) {
					Write-PSFMessage @msgParam -Level Error -String 'Invoke-SHTask.Warning.NoMatch' -StringValues $principal.SamAccountName, $principal.$($fromAttribute[$principal.ObjectCategory]), $toAttribute[$principal.ObjectCategory] -Target $principal
					Write-Result -FromUser $principal -Status 'NoMatch' -Message 'No match found' -Queue ActionsTaken
					continue
				}

				if (@($targetPrincipal).Count -gt 1) {
					Write-PSFMessage @msgParam -Level Error -String 'Invoke-SHTask.Warning.AmbiguousMatch' -StringValues $principal.SamAccountName, $principal.$($fromAttribute[$principal.ObjectCategory]), $toAttribute[$principal.ObjectCategory], ($targetPrincipal.SamAccountName -join ',') -Target $principal
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

			if (-not $global:FromSession -or -not $global:ToSession) {
				$Principal.Status = 'Skipped'
				$Principal.Message = 'Authentication Failed'
				return $Principal
			}

			try {
				if ($Task.TestRun) {
					Write-PSFMessage @msgParam -String 'Invoke-SHTask.Executing.TestRun' -StringValues $Principal.From, $Principal.To
				}
				else {
					Copy-SHSidHistory -From $global:FromSession -To $global:ToSession -FromIdentity $Principal.From -ToIdentity $Principal.To
				}
				$Principal.Status = 'Migrated'
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
				$global:ToSession = New-SHSession -Server $Task.To -Credential $ToSession
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
		$workflow | Add-PSFRunspaceWorker -Name 'User Scan' -Count $scanCount -InQueue Scopes -OutQueue ADUsers @workerEnv -ScriptBlock $code_UserScan -CloseOutQueue
		## Prepare Worker: Migrator
		$workflow | Add-PSFRunspaceWorker -Name 'Migrator' -Count 5 -InQueue ADUsers -OutQueue ActionsTaken @workerEnv -ScriptBlock $code_Migrator -Begin $code_Migrator_Begin -CloseOutQueue
		## Load Scope Selectors from Configuration and Start workflow
		$workflow | Write-PSFRunspaceQueue -Name Scopes -BulkValues $Config.Scopes -Close
		$workflow | Start-PSFRunspaceWorkflow

		# Wait for Completion
		$workflow | Wait-PSFRunspaceWorkflow
		$results = Read-PSFRunspaceQueue -InputObject $workflow -Name ActionsTaken -All
		$workflow | Remove-PSFRunspaceWorkflow

		# Log Actions
		Write-ActionLog -Data $results -TaskName $Task.Name
	}
}