function Remove-SHTask {
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