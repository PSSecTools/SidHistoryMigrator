function Invoke-SHMigration {
	<#
	.SYNOPSIS
		Executes all configured Migration Tasks.

	.DESCRIPTION
		Executes all configured Migration Tasks.
		This is the main command of the module, executing every task previously defined with the configuration provided.

		For a full Stp-by-Step guide, see the project readme:
		https://github.com/PSSecTools/SidHistoryMigrator

		+ Use New-SHTask to define tasks to execute. All defined tasks are processed, no parameter on this command needed.
		+ Provide a scope configuration for each task, describing where to look for principals to migrate.

		The latter is provided through a config file, either specified by the -TaskPath parameter or picked up automatically from the path defined during installation.
		
		The recommended usage for this module & command is to install it to the computer by running "Install-SHMigrator",
		which will set up a scheduled task that will then run Invoke-SHMigration on a schedule.
		As part of that installation you can provide the path to this file through the installer's "-TaskPath" parameter.

		However that configuration file is specified, this is what it must look like:
		@{
			'<TaskName1>' = <TaskConfiguration>
			'<TaskName2>' = <TaskConfiguration>
			'<TaskName3>' = <TaskConfiguration>
			...
			'<TaskNameN>' = <TaskConfiguration>

			# Optional: Extra Logging Settings
			Logging = @(
				<PSFramework Logging Config>
				...
			)
		}
		The respective task name must match the name chosen when registering it in New-SHTask.

		Each Task Configuration looks like this:
		@{
			Scopes = @(
				<Scope1>
				<Scope2>
				...
				<ScopeN>
			)
		}

		Each scope looks like this:
		@{
			Path = '<distinguishedName>' # Mandatory. DN of Organizational Unit under which to look for principals
			Filter = '<ldap filter>' # Optional. An LDAP Filter to further limit the principals under the defined path
			Type = '<User|Group>' # Optional. Limit Principals to either Group or User
			SearchScope = '<Subtree|Base|OneLevel>' # Optional. Defines how deeply nested the LDAP search for Principals will delve under the defined path.
		}

		Example for a full configuration file:
		@{
			Pilot = @{
				Scopes = @(
					@{ Path = 'OU=USA,OU=Accounts,DC=Contoso,DC=com' }
					@{ Path = 'OU=Brazil,OU=Accounts,DC=Contoso,DC=com'; Type = 'User' }
					@{ Path = 'OU=Japan,OU=Accounts,DC=Contoso,DC=com'; Filter = '(|(department=Research)(department=Development))' }
				)
			}
		}

	.PARAMETER TaskPath
		Path to a Task Configuration file to execute.
		See description for details on how to define them.

	.EXAMPLE
		PS C:\> Invoke-SHMigration

		Runs all saved tasks using the scope configuration path registered during installation.

	.EXAMPLE
		PS C:\> Invoke-SHMigration -TaskPath 'C:\SidMigration\PilotScopes.psd1'

		Runs saved tasks against an explicitly selected scope configuration file.
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
			if ($logging) { Disable-PSFLoggingProvider -Config $logging }
			Disable-PSFLoggingProvider -Name eventlog -InstanceName SidHistoryMigrator
			throw $_
		}

		$logging = $null
		$tasksConfig = Resolve-TaskConfiguration -TaskPath $TaskPath -FallbackPath (Get-PSFConfigValue -FullName 'SidHistoryMigrator.Path.TaskPath')
		$logging = $tasksConfig.Logging | Where-Object { $_.InstanceName -ne 'SidHistoryMigrator' }
		if ($logging) { Set-PSFLoggingProvider -Config $logging -Wait }
		$tasks = Get-SHTask
		foreach ($task in $tasks) {
			Invoke-SHTask -Task $task -Config $tasksConfig.$($task.Name)
		}
	}
	end {
		if ($logging) { Disable-PSFLoggingProvider -Config $logging }
		Disable-PSFLoggingProvider -Name eventlog -InstanceName SidHistoryMigrator
	}
}