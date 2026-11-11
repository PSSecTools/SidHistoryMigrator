function Install-SHMigrator {
	<#
	.SYNOPSIS
		Configures this computer to run scheduled SID history migrations.

	.DESCRIPTION
		Configures this computer to run scheduled SID history migrations.

		This will perform the following steps:
		- Configure the path to the folder where the system will maintain its runtime data (such as task configurations or encrypted secrets)
		- Configure the path to the file that will be used as default task configuration (See project readme for details: https://github.com/PSSecTools/SidHistoryMigrator)
		- Configure the path to where the principal-level logs for each task should be stored
		- Create a scheduled task running under SYSTEM that performs the configured migrations every 3 hours (task can be modified after creation, or deleted if only manual execution is needed)
		- Set up a dedicated eventlog to which the system will log its operational messages

	.PARAMETER ConfigPath
		Path to the folder where the system will maintain its runtime data (such as task configurations or encrypted secrets)
		
	.PARAMETER TaskPath
		The path to the PowerShell data file containing per-task Scopes and optional logging settings.
		See project readme for details: https://github.com/PSSecTools/SidHistoryMigrator

	.PARAMETER LoggingRoot
		Path to where the per-principal logs will be written, one for each Task.
		Defaults to "<ConfigPath>\Logs" if not specified

	.EXAMPLE
		PS C:\> Install-SHMigrator -ConfigPath 'C:\SidMigration' -TaskPath 'C:\SidMigration\Scopes.psd1'

		Configures the migration host using an empty local directory.
		Create the scope data file before running migrations.

	.EXAMPLE
		PS C:\> Install-SHMigrator -ConfigPath 'C:\SidMigration' -TaskPath '\\contoso.com\it-operations\migration\SIDHistory\configuration.psd1' -LoggingRoot '\\contoso.com\it-operations\migration\SIDHistory\Logs'

		Configures the migration host using an empty local directory.
		Specifies both the Task configuration paths and Logging Root on a DFS share, allowing most configurations to be performed without logging into the system.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[PSFDirectorySingle]
		$ConfigPath,

		[Parameter(Mandatory = $true)]
		[string]
		$TaskPath,

		[string]
		$LoggingRoot
	)
	process {
		# Configure Path in Registry
		Write-PSFMessage -Level Host -String 'Install-SHMigrator.Execute.SetConfigRoot' -StringValues $ConfigPath
		Set-PSFConfig -Module SidHistoryMigrator -Name 'Path.ConfigRoot' -Value $ConfigPath -PassThru | Register-PSFConfig -Scope SystemDefault -ErrorAction Stop
		
		# Configure Task File Path
		Write-PSFMessage -Level Host -String 'Install-SHMigrator.Execute.TaskPath' -StringValues $TaskPath
		Set-PSFConfig -Module SidHistoryMigrator -Name 'Path.TaskPath' -Value $TaskPath -PassThru | Register-PSFConfig -Scope SystemDefault -ErrorAction Stop

		if (-not $LoggingRoot) { $LoggingRoot = Join-Path -Path $ConfigPath -ChildPath Logs }
		else { Write-PSFMessage -Level Host -String 'Install-SHMigrator.Execute.LoggingRoot' }
		Set-PSFConfig -Module SidHistoryMigrator -Name 'Path.LoggingRoot' -Value $LoggingRoot -PassThru | Register-PSFConfig -Scope SystemDefault -ErrorAction Stop

		# Create Secret Encryption Certificate, if needed
		$cert = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {
			$_.Subject -eq 'CN=Sid History Migrator Secrets Manager' -and $_.HasPrivateKey
		}
		if (-not $cert) {
			Write-PSFMessage -Level Host -String 'Install-SHMigrator.Execute.SecretsCertificate'
			$null = New-SelfSignedCertificate -Subject 'CN=Sid History Migrator Secrets Manager' -CertStoreLocation Cert:\LocalMachine\My -Type DocumentEncryptionCert
		}

		# Create Scheduled Task
		Write-PSFMessage -Level Host -String 'Install-SHMigrator.Execute.RegisteringTask'
		Register-SystemTask -Name 'Sid History Migrator' -Schedule 'Short-03:00' -Scriptblock {
			Invoke-SHMigration
		} -Description 'Executes the SID History Migration Workflow'

		Write-PSFMessage -Level Host -String 'Install-SHMigrator.Execute.SettingLogging'
		Set-PSFLoggingProvider -Name eventlog -InstanceName SidHistoryMigrator -Enabled $true -LogName 'SidHistoryMigration' -Source 'SidHistoryMigrator' -IncludeTags test -Wait
		Write-PSFMessage -String 'Install-SHMigrator.TestLogMessage' -Tag test
		Disable-PSFLoggingProvider -Name eventlog -InstanceName SidHistoryMigrator
	}
}