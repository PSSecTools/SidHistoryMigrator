function Remove-SHTask {
	<#
	.SYNOPSIS
		Removes previously registered SID History migration tasks.

	.DESCRIPTION
		Removes previously registered SID History migration tasks.
		Use this to conclude a migration project.

		Optionally choose whether to retain the credentials used in this task,
		something that might be necessary when multiple tasks operate against the same domain, as the credentials are shared.

		If you later need to remove credentials manually, use the Remove-SHCredential command.

	.PARAMETER Name
		Name of the task to remove.

	.PARAMETER KeepCredentials
		Deletes the task without deleting its saved credentials.
		Necessary when other tasks operate still use the credentials.

	.EXAMPLE
		PS C:\> Remove-SHTask -Name 'Pilot'

		Deletes the Pilot task.

	.EXAMPLE
		PS C:\> Remove-SHTask -Name 'Pilot' -KeepCredentials

		Deletes the Pilot task while preserving shared domain credentials.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
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
		$filename = "$([convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Name)).Trim('=')).clidat"
		$filePath = Join-Path -Path $taskPath -ChildPath $filename

		if (-not (Test-Path -LiteralPath $filePath)) { return }

		if ($KeepCredentials) {
			Remove-Item -LiteralPath $filePath -Force
			return
		}

		$taskData = Import-PSFClixml -Path $filePath
		Remove-Item -LiteralPath $filePath -Force
		$remainingTaskDomains = Get-SHTask | ForEach-Object { $_.From, $_.To } | Remove-PSFNull
		if ($remainingTaskDomains -notcontains $taskData.From) { Remove-SHCredential -Name $taskData.From }
		if ($remainingTaskDomains -notcontains $taskData.To) { Remove-SHCredential -Name $taskData.To }
	}
}