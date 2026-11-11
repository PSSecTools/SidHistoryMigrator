function Export-SHCredential {
	<#
	.SYNOPSIS
		Encrypts and saves a named migration credential.

	.DESCRIPTION
		Encrypts and saves a named migration credential.
		Expects the module to have been properly installed through the "Install-SHMigrator" command:

		- Encrypted Credentials are written to a "Secrets" folder under the ConfigPath specified during installation.
		- Encryption is performed with the latest certificate with the subject "CN=Sid History Migrator Secrets Manager" that it can find with a private key for.
		
		If a secret of the specified name already exists, it will be overwritten without prompt.

	.PARAMETER Name
		The name under which the certificate will be stored (and later retrieved).
		Migration Tasks store their credentials under the domain/server name specified during task creation, and thus read th secrets using that respective name.

	.PARAMETER Credential
		The credential to encrypt and save.

	.EXAMPLE
		PS C:\> Export-SHCredential -Name 'contoso.com' -Credential (Get-Credential)

		Prompts for a credential and saves it under the specified domain name.
	#>
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
		$data | ConvertTo-PSFPsd1 | Set-PSFFileContent -Path $filePath
	}
}