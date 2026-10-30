function Remove-SHTask {
	<#
	.SYNOPSIS
		Removes task data or its associated saved credentials.

	.DESCRIPTION
		Locates a saved task by its exact name. With KeepCredentials, deletes only
		the task definition. Without KeepCredentials, the current implementation deletes
		the task's source and destination credentials but leaves the task definition in place.
		Does nothing if the task definition does not exist.

	.PARAMETER Name
		The exact name of the saved task. Wildcards are not supported.

	.PARAMETER KeepCredentials
		Deletes the task definition without deleting its saved credentials.

	.INPUTS
		None. Parameters do not accept pipeline input.

	.OUTPUTS
		None.

	.EXAMPLE
		PS C:\> Remove-SHTask -Name 'Pilot' -KeepCredentials

		Deletes the Pilot task definition while preserving shared domain credentials.

	.NOTES
		Without KeepCredentials, the task definition currently remains on disk.
		Credentials are shared by domain or server name, so deleting them can affect
		other tasks. This command does not prompt for confirmation or support WhatIf.

	.LINK
		Get-SHTask

	.LINK
		Remove-SHCredential
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Name,

		[switch]
		$KeepCredentials
	)
	begin {
		$taskPath = Join-Path -Path (Get-PSFConfigValue -FullName 'SidHistoryMigrator.Path.ConfigRoot') -ChildPath Tasks
		if (-not (Test-Path -LiteralPath $taskPath)) {
			$null = New-Item -Path $taskPath -ItemType Directory -Force
		}
	}
	process {
		$filename = "$([convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Name)).Trim("=")).clidat"
		$filePath = Join-Path -Path $taskPath -ChildPath $filename

		if (-not (Test-Path -LiteralPath $filePath)) { return }

		if ($KeepCredentials) {
			Remove-Item -LiteralPath $filePath -Force
			return
		}

		$taskData = Import-PSFClixml -Path $filePath
		Remove-SHCredential -Name $taskData.From
		Remove-SHCredential -Name $taskData.To
	}
}