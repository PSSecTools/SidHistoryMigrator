function Register-SystemTask {
	<#
	.SYNOPSIS
		Creates a scheduled task running as system.
		
	.DESCRIPTION
		Creates a scheduled task running as system.
		Helper command simplifying setting up simpler scheduled task configurations that run PowerShell as System account.
		Registers or replaces a task with the same name. The task runs at highest privilege
		and ignores new invocations while an existing instance is still running.
	
	.PARAMETER Name
		Name of the task to create.
	
	.PARAMETER Scriptblock
		The PowerShell code to execute.
		Executed as a UTF-16 encoded command with NoProfile. Captured local variables
		are not serialized; the code must be self-contained in the scheduled process.
	
	.PARAMETER Description
		Description to include in the task.
	
	.PARAMETER Schedule
		On what schedule to execute the task.
		Supports different schedule types, which can be provided in any combination:
		- Boot: Runs on Startup
		- Daily: Runs daily at Midnight.
		- Daily-02:00: Runs daily at 2am.
		- Daily-3h: Runs daily, 3 hours from now.
		- Short-00:30: Runs every 30 minutes.
		- Short-15m: Runs every 15 minutes.
	
	.PARAMETER Limit
		Maximum duration a task may take before being given up upon by the scheduler.
		Will run without interruption or limit if set to 0.
		Defaults to three days (3d).
	
	.PARAMETER UsePWSH
		Task should run on pwsh.exe / PowerShell 7.
		Requires PowerShell 7 to be installed and on Path for the system account.
	
	.PARAMETER ComputerName
		Computer(s) to install the task on.
		Defaults to localhost.
	
	.PARAMETER Credential
		Credentials to use to set up the task through Invoke-PSFCommand, not credentials
		for the scheduled process. The scheduled process always runs as SYSTEM.

	.PARAMETER WhatIf
		If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
	
	.PARAMETER Confirm
		If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

	.INPUTS
		None. Parameters do not accept pipeline input.

	.OUTPUTS
		None. Registers the scheduled task on the selected computers.
	
	.EXAMPLE
		PS C:\> Register-SystemTask -Name 'Sid History Migrator' -Schedule 'Short-03:00' -ScriptBlock { Invoke-SHMigration }
		
		Registers the local migration task to run every three hours using Windows PowerShell.
		This helper is available only within the module's session state.

	.NOTES
		Not exported. Requires Windows ScheduledTasks commands and administrative rights
		on the target computers. The module must be discoverable by the SYSTEM account
		when the scheduled code invokes its commands.

	.LINK
		Install-SHMigrator
	#>
	[CmdletBinding(SupportsShouldProcess = $true)]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Name,

		[Parameter(Mandatory = $true)]
		[Scriptblock]
		$Scriptblock,

		[string]
		$Description,

		[string[]]
		$Schedule,

		[PSFTimeSpan]
		$Limit = '3d',

		[switch]
		$UsePWSH,

		[PSFComputer[]]
		$ComputerName = $env:COMPUTERNAME,

		[PSCredential]
		$Credential
	)
	begin {
		function ConvertTo-TaskSchedule {
			<#
			.SYNOPSIS
				Converts schedule notation into Windows scheduled-task triggers.

			.DESCRIPTION
				Local helper for Register-SystemTask. Creates startup, daily, or daily
				triggers with repetition. Throws when a pattern or repetition interval is invalid.

			.PARAMETER Schedule
				Schedule strings, accepted directly or through the pipeline. Boot runs at
				startup. Daily optionally includes a PSFDateTime value after a hyphen and
				defaults to midnight if no time can be parsed. Short requires a PSFTimeSpan
				interval, such as Short-15m, and repeats within a daily one-day window.

			.INPUTS
				System.String[]
				Schedule notation passed through the pipeline.

			.OUTPUTS
				Microsoft.Management.Infrastructure.CimInstance
				Scheduled-task trigger objects created by New-ScheduledTaskTrigger.

			.EXAMPLE
				PS C:\> 'Daily-02:00', 'Boot' | ConvertTo-TaskSchedule

				Creates a daily 02:00 trigger and a startup trigger within the parent scope.
			#>
			[CmdletBinding()]
			param (
				[Parameter(ValueFromPipeline = $true)]
				[string[]]
				$Schedule
			)

			process {
				foreach ($entry in $Schedule) {
					switch -regex ($entry) {
						'^Boot$' { New-ScheduledTaskTrigger -AtStartup }
						'^Daily' {
							$null, $timeNotation, $null = $entry -split '-'
							$timeOfDay = $timeNotation -as [PSFDateTime]
							if (-not $timeOfDay) { $timeOfDay = [DateTime]::Now.Date }
							New-ScheduledTaskTrigger -Daily -At $timeOfDay
						}
						'^Short-' {
							$null, $timeNotation, $null = $entry -split '-'
							$interval = $timeNotation -as [PSFTimeSpan]
							if (-not $interval) {
								throw "Invalid schedule notation, unable to parse interval: $entry"
							}
							$timeOfDay = [DateTime]::Now.Date
							$repTrigger = New-ScheduledTaskTrigger -RepetitionInterval $interval -At $timeOfDay -Once -RepetitionDuration '1.00:00:00'
							$trigger = New-ScheduledTaskTrigger -Daily -At $timeOfDay
							$trigger.Repetition = $repTrigger.Repetition
							$trigger
						}
						default {
							throw "Invalid schedule notation, unable to recognize pattern: $entry"
						}
					}
				}
			}
		}
	}
	process {
		$command = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($Scriptblock.ToString()))
		$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -EncodedCommand $command"
		if ($UsePWSH) { $action.Execute = 'pwsh.exe' }
		$principal = New-ScheduledTaskPrincipal -UserId SYSTEM -LogonType Password -RunLevel Highest
		$triggers = $Schedule | ConvertTo-TaskSchedule
		$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit $Limit

		$param = @{
			Action    = $action
			Settings  = $settings
			Trigger   = $triggers
			Principal = $principal
		}
		if ($Description) { $param.Description = $Description }
		$task = New-ScheduledTask @param

		Invoke-PSFProtectedCommand -Action "Creating the scheduled task $Name" -Target ($ComputerName -join ", ") -ScriptBlock {
			Invoke-PSFCommand -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
				param ($Task, $Name)
				$null = $Task | Register-ScheduledTask -TaskName $Name -Force
			} -ArgumentList $task, $Name
		} -EnableException $true -PSCmdlet $PSCmdlet
	}
}