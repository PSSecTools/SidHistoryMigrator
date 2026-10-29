function Import-SHCredential {
	[OutputType([PSCredential])]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Name
	)
	begin {
		$secretPath = Join-Path -Path (Get-PSFConfigValue -FullName 'SidHistoryMigrator.Path.ConfigRoot') -ChildPath Secrets
		if (-not (Test-Path -LiteralPath $secretPath)) {
			$null = New-Item -Path $secretPath -ItemType Directory -Force
		}
	}
	process {
		$filename = "$([convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Name)).Trim("=")).psd1"
		$filePath = Join-Path -Path $secretPath -ChildPath $filename

		if (-not (Test-Path -Path $filePath)) {
			Stop-PSFFunction -String 'Import-SHCredential.Error.SecretNotFound' -StringValues $Name -EnableException $true -Cmdlet $PSCmdlet -Category ObjectNotFound
		}

		$data = Import-PSFPowerShellDataFile -Path $filePath
		try {
			$cert = [System.Security.Cryptography.X509Certificates.X509Certificate2][PSFramework.Parameter.CertificateParameter]$data.Thumbprint
		}
		catch {
			Stop-PSFFunction -String 'Import-SHCredential.Error.CertificateNotFound' -StringValues $Name, $data.Thumbprint -EnableException $true -Cmdlet $PSCmdlet -Category InvalidData
		}

		[PSCredential]::new((Unprotect-CmsMessage -Content $data.UserName -To $cert), (Unprotect-CmsMessage -Content $data.Password -To $cert | ConvertTo-SecureString -AsPlainText -Force))
	}
}