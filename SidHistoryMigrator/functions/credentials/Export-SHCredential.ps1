function Export-SHCredential {
	<#
	.SYNOPSIS
		Encrypts and saves a named migration credential.

	.DESCRIPTION
		Encrypts the user name and password with the CMS document-encryption certificate
		CN=Sid History Migrator Secrets Manager. Saves the certificate thumbprint and
		encrypted values in the Secrets directory beneath SidHistoryMigrator.Path.ConfigRoot.
		Saving an existing name replaces its stored credential.

	.PARAMETER Name
		The name used to retrieve or remove the credential. Migration tasks use their
		From and To server or domain strings as credential names.

	.PARAMETER Credential
		The credential to encrypt and save.

	.INPUTS
		None. Parameters do not accept pipeline input.

	.OUTPUTS
		None. Writes an encrypted credential file.

	.EXAMPLE
		PS C:\> Export-SHCredential -Name 'source.contoso.com' -Credential (Get-Credential)

		Prompts for a credential and saves it under the source domain name.

	.NOTES
		Run Install-SHMigrator first to provision the encryption certificate. The identity
		that later imports the credential needs access to its private key. Credentials
		are shared by name across tasks; replacing one affects every task using that name.

	.LINK
		Import-SHCredential

	.LINK
		Remove-SHCredential
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