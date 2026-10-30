function Invoke-SHMigration {
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