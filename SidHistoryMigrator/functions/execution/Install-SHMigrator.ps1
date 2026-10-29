function Install-SHMigrator {
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