function Remove-SHCredential {
	<#
	.SYNOPSIS
		Deletes a saved migration credential.

	.DESCRIPTION
		Deletes the named credential file from the Secrets directory beneath
		SidHistoryMigrator.Path.ConfigRoot. Does nothing if the file does not exist.
		Does not remove the encryption certificate or any task definitions.

	.PARAMETER Name
		The exact name supplied to Export-SHCredential. Wildcards are not supported.

	.INPUTS
		None. Parameters do not accept pipeline input.

	.OUTPUTS
		None.

	.EXAMPLE
		PS C:\> Remove-SHCredential -Name 'retired.contoso.com'

		Deletes the credential stored for the retired domain.

	.NOTES
		Credentials are shared by name. Removing a credential prevents every task
		using that name from loading it. This command does not prompt for confirmation
		and does not support WhatIf.

	.LINK
		Export-SHCredential

	.LINK
		Remove-SHTask
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
		$filename = "$([convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Name)).Trim("=")).psd1"
		$filePath = Join-Path -Path $secretPath -ChildPath $filename

		if (-not (Test-Path -Path $filePath)) { return }

		Remove-Item -LiteralPath $filePath -Force
	}
}