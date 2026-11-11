function Import-SHCredential {
	<#
	.SYNOPSIS
		Loads and decrypts a saved migration credential.

	.DESCRIPTION
		Loads and decrypts a saved migration credential.
		This command can fail with a terminating error if the secret specified does not exist or the certificate it was encrypted with is unavailable.
		It will also fail, if the current account does not have access rights to the private key.
		If you run this task under an account who does not have local admin rights, ensure you assign read permissions on the private key (e.g. through the certificates mmc console).

	.PARAMETER Name
		Name of the credential to retrieve.
		In this system, that is generally the domain name of the target domain as specified during Migration Task creation.

	.EXAMPLE
		PS C:\> $credential = Import-SHCredential -Name 'contoso.com'

		Loads the saved credential for the "contoso.com" domain.
	#>
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
		$filename = "$([convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Name)).Trim('=')).psd1"
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