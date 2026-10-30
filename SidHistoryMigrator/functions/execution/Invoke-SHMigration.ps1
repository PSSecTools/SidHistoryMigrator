function Invoke-SHMigration {
	<#
	.SYNOPSIS
		Executes saved migration tasks using a scope configuration file.

	.DESCRIPTION
		Loads a PowerShell data file, retrieves all saved task definitions, and invokes
		each task with the configuration entry matching its name. Enables Windows event
		logging and any PSFramework logging providers specified by the file's Logging entry.
		Tasks without configured Scopes are logged and skipped.

	.PARAMETER TaskPath
		An existing PowerShell data file defining task-name keys with Scopes arrays and
		an optional top-level Logging entry. If omitted, uses SidHistoryMigrator.Path.TaskPath.
		A scope requires Path and can specify an LDAP Filter and Type (User or Group).

	.INPUTS
		None. Parameters do not accept pipeline input.

	.OUTPUTS
		None. Results are written to per-task JSON action logs and configured logging providers.

	.EXAMPLE
		PS C:\> Invoke-SHMigration

		Runs all saved tasks using the scope configuration path registered during installation.

	.EXAMPLE
		PS C:\> Invoke-SHMigration -TaskPath 'C:\SidMigration\PilotScopes.psd1'

		Runs saved tasks against an explicitly selected scope configuration file.

	.NOTES
		Requires Windows event logging access, saved credentials, and directory connectivity.
		There is no WhatIf parameter. Save tasks with New-SHTask -TestRun to suppress SID
		history writes while retaining authentication, directory searches, and logging.

	.LINK
		Install-SHMigrator

	.LINK
		Invoke-SHTask

	.LINK
		about_SidHistoryMigrator
	#>
	[CmdletBinding()]
	param (
		[PSFFileSingle]
		$TaskPath
	)
	begin {
		Set-PSFLoggingProvider -Name eventlog -InstanceName SidHistoryMigrator -Enabled $true -LogName 'SidHistoryMigration' -Source 'SidHistoryMigrator' -NumericTagAsID $true -Wait
	}
	process {
		$ErrorActionPreference = 'Stop'
		trap {
			Write-PSFMessage -Level Error -String 'Invoke-SHMigration.Error.Failed' -ErrorRecord $_ -ErrorStack
			if ($tasksConfig.Logging) { Disable-PSFLoggingProvider -Config $tasksConfig.Logging }
			Disable-PSFLoggingProvider -Name eventlog -InstanceName SidHistoryMigrator
			throw $_
		}

		$tasksConfig = Resolve-TaskConfiguration -TaskPath $TaskPath -FallbackPath (Get-PSFConfigValue -FullName 'SidHistoryMigrator.Path.TaskPath')
		if ($tasksConfig.Logging) { Set-PSFLoggingProvider -Config $tasksConfig.Logging }
		$tasks = Get-SHTask
		foreach ($task in $tasks) {
			Invoke-SHTask -Task $task -Config $tasksConfig.$($task.Name)
		}
	}
	end {
		if ($tasksConfig.Logging) { Disable-PSFLoggingProvider -Config $tasksConfig.Logging }
		Disable-PSFLoggingProvider -Name eventlog -InstanceName SidHistoryMigrator
	}
}