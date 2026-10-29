function Get-SHTask {
	[CmdletBinding()]
	param (
		[string]
		$Name = '*'
	)
	begin {
		$taskPath = Join-Path -Path (Get-PSFConfigValue -FullName 'SidHistoryMigrator.Path.ConfigRoot') -ChildPath Tasks
		if (-not (Test-Path -LiteralPath $taskPath)) {
			$null = New-Item -Path $taskPath -ItemType Directory -Force
		}
	}
	process {
		Get-ChildItem -Path $taskPath -Filter *.clidat | ForEach-Object {
			Import-PSFClixml -Path $_.FullName
		} | Where-Object Name -like $Name
	}
}