function Import-SHCredential {
	<#
	.SYNOPSIS
		Loads and decrypts a saved migration credential.

	.DESCRIPTION
		Reads the named credential from the Secrets directory beneath
		SidHistoryMigrator.Path.ConfigRoot, resolves its certificate by the saved
		thumbprint, and decrypts the user name and password into a PSCredential.
		Reports a terminating error if the file or certificate cannot be found.

	.PARAMETER Name
		The exact name supplied to Export-SHCredential. Migration tasks use their
		From and To values as credential names. Wildcards are not supported.

	.INPUTS
		None. Parameters do not accept pipeline input.

	.OUTPUTS
		System.Management.Automation.PSCredential
		The decrypted credential.

	.EXAMPLE
		PS C:\> $credential = Import-SHCredential -Name 'source.contoso.com'

		Loads the saved source-domain credential for subsequent directory operations.

	.NOTES
		The calling identity needs access to the private key of the certificate used
		when the credential was exported. Do not write the decrypted password to logs.

	.LINK
		Export-SHCredential
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