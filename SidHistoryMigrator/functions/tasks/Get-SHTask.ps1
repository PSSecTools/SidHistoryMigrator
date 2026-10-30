function Get-SHTask {
	<#
	.SYNOPSIS
		Retrieves saved migration task definitions.

	.DESCRIPTION
		Imports task definitions from the Tasks directory beneath
		SidHistoryMigrator.Path.ConfigRoot and filters them by name. These definitions
		contain connection and matching settings, not the scope configuration or passwords.

	.PARAMETER Name
		A wildcard pattern matching task names. Defaults to *, returning every task.

	.INPUTS
		None. Parameters do not accept pipeline input.

	.OUTPUTS
		System.Management.Automation.PSCustomObject
		Saved SidHistoryMigrator.Task definitions, restored by Import-PSFClixml.

	.EXAMPLE
		PS C:\> Get-SHTask

		Returns all saved task definitions.

	.EXAMPLE
		PS C:\> Get-SHTask -Name 'Pilot*'

		Returns task definitions whose names start with Pilot.

	.LINK
		New-SHTask

	.LINK
		Invoke-SHTask
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
		Get-ChildItem -Path $taskPath -Filter *.clidat | ForEach-Object {
			Import-PSFClixml -Path $_.FullName
		} | Where-Object Name -like $Name
	}
}