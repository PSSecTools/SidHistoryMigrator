function Register-SystemTask {
	<#
	.SYNOPSIS
		Creates a scheduled task running as system.
		
	.DESCRIPTION
		Creates a scheduled task running as system.
		Helper command simplifying setting up simpler scheduled task configurations that run PowerShell as System account.
	
	.PARAMETER Name
		Name of the task to create.
	
	.PARAMETER Scriptblock
		The PowerShell code to execute.
		Will be executed as encoded command.
	
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
		Defaults to unlimited.
	
	.PARAMETER UsePWSH
		Task should run on pwsh.exe / PowerShell 7.
		Requires PowerShell 7 to be installed and on Path for the system account.
	
	.PARAMETER ComputerName
		Computer(s) to install the task on.
		Defaults to localhost.
	
	.PARAMETER Credential
		Credentials to use to set up the task.

	.PARAMETER WhatIf
		If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
	
	.PARAMETER Confirm
		If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.
	
	.EXAMPLE
		PS C:\> Register-SystemTask -Name SPSiteDecryptor.Main -Schedule 'Daily-02:00', Boot -ScriptBlock { Invoke-SPSiteDecryption } -Limit '00:00:00' -Confirm:$false -UsePWSH
		
		Registers the task 'SPSiteDecryptor.Main' on the local computer.
		- It will run on boot and every day on 2am.
		- It will execute "Invoke-SPSiteDecryption" when run.
		- There is no time limit on how long the task may take.
		- It will run on PowerShell 7.
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