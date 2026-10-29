function Export-SHCredential {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Name,
		
		[Parameter(Mandatory = $true)]
		[PSCredential]
		$Credential
	)
	begin {
		$secretPath = Join-Path -Path (Get-PSFConfigValue -FullName 'SidHistoryMigrator.Path.ConfigRoot') -ChildPath Secrets
		if (-not (Test-Path -LiteralPath $secretPath)) {
			$null = New-Item -Path $secretPath -ItemType Directory -Force
		}

		try {
			$cert = [System.Security.Cryptography.X509Certificates.X509Certificate2][PSFramework.Parameter.CertificateParameter]'CN=Sid History Migrator Secrets Manager'
		}
		catch {
			Stop-PSFFunction -String 'Export-SHCredential.Error.NoCertificate' -EnableException $true -Cmdlet $PSCmdlet -Category InvalidData
		}
	}
	process {
		$data = @{
			Thumbprint = $cert.Thumbprint
			UserName   = (Protect-CmsMessage -To $cert -Content $Credential.UserName).PSObject.BaseObject
			Password   = (Protect-CmsMessage -To $cert -Content $Credential.GetNetworkCredential().Password).PSObject.BaseObject
		}

		$filename = "$([convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Name)).Trim('=')).psd1"
		$filePath = Join-Path -Path $secretPath -ChildPath $filename
		$data | ConvertTo-PSFPSd1 | Set-PSFFileContent -Path $filePath
	}
}