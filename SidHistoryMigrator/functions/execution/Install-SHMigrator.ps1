function Install-SHMigrator {
	<#
	.SYNOPSIS
		Configures this computer to run scheduled SID history migrations.

	.DESCRIPTION
		Persists module paths at PSFramework's SystemDefault scope, creates a local
		machine document-encryption certificate if needed, and registers the Sid History
		Migrator scheduled task to invoke Invoke-SHMigration as SYSTEM every three hours.
		Also initializes and tests the SidHistoryMigration Windows event log provider.

	.PARAMETER ConfigPath
		An existing directory in which task definitions and encrypted credentials
		will be stored. Becomes SidHistoryMigrator.Path.ConfigRoot.

	.PARAMETER TaskPath
		The path to the PowerShell data file containing per-task Scopes and optional
		Logging settings. Becomes SidHistoryMigrator.Path.TaskPath. This command stores
		the path but does not create or validate the file's contents.

	.PARAMETER LoggingRoot
		An optional directory for per-task JSON action logs. Becomes
		SidHistoryMigrator.Path.LoggingRoot. If omitted, the current setting is kept;
		changing ConfigPath does not recalculate an already initialized logging path.

	.INPUTS
		None. Parameters do not accept pipeline input.

	.OUTPUTS
		None. Configures paths, a certificate, a scheduled task, and event logging.

	.EXAMPLE
		PS C:\> Install-SHMigrator -ConfigPath 'C:\SidMigration' -TaskPath 'C:\SidMigration\Scopes.psd1' -LoggingRoot 'C:\SidMigration\Logs'

		Configures the migration host using an existing configuration directory and
		an explicit log directory. Create the scope data file before running migrations.

	.NOTES
		Run elevated on Windows. The scheduled task uses Windows PowerShell and SYSTEM,
		which must be able to load the module, read the configuration, decrypt credentials,
		and write logs. Scope files and stored secrets should have restricted ACLs.
		Installation does not create migration task definitions or migrate accounts.
		This command does not support WhatIf.

	.LINK
		New-SHTask

	.LINK
		Invoke-SHMigration

	.LINK
		about_SidHistoryMigrator
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

		if ($LoggingRoot) {
			Write-PSFMessage -Level Host -String 'Install-SHMigrator.Execute.LoggingRoot'
			Set-PSFConfig -Module SidHistoryMigrator -Name 'Path.LoggingRoot' -Value $LoggingRoot -PassThru | Register-PSFConfig -Scope SystemDefault -ErrorAction Stop
		}

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