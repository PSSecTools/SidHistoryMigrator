function Get-SHTask {
	<#
	.SYNOPSIS
		Lists the registered SID History migration tasks.

	.DESCRIPTION
		Lists the registered SID History migration tasks.
		Tasks are the core migration configurations used to describe the main boundaries on how SID histories are migrated from where to where.

		- Use New-SHTask to define new ones.
		- Use Remove-SHTask to delete existing ones.
		- Use Invoke-SHMigrator to execute them.

	.PARAMETER Name
		The name of the task to retrieve.
		Defaults to: *

	.EXAMPLE
		PS C:\> Get-SHTask

		Returns all saved task definitions.

	.EXAMPLE
		PS C:\> Get-SHTask -Name 'Pilot*'

		Returns task definitions whose names start with Pilot.
	#>
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
		(Get-ChildItem -Path $taskPath -Filter *.clidat) | ForEach-Object {
			Import-PSFClixml -Path $_.FullName
		} | Where-Object Name -Like $Name
	}
}