function Remove-SHCredential {
	<#
	.SYNOPSIS
		Deletes a saved migration credential.

	.DESCRIPTION
		Deletes a saved migration credential.
		This usually needs not be called directly and is called as part of Remove-SHTask, when deleting the entire migration task.
		Once a SID History Migration is complete, there is no more need to store Domain Admin credentials on disk, encrypted or not.

	.PARAMETER Name
		The exact name supplied to Export-SHCredential.
		Wildcards are not supported.

	.EXAMPLE
		PS C:\> Remove-SHCredential -Name 'contoso.com'

		Deletes the credential stored for the retired domain.
	#>
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

		if (-not (Test-Path -Path $filePath)) { return }

		Remove-Item -LiteralPath $filePath -Force
	}
}