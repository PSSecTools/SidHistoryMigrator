function Resolve-TaskConfiguration {
	<#
	.SYNOPSIS
		Loads a migration scope configuration as a hashtable.

	.DESCRIPTION
		Internal helper that selects TaskPath when provided, otherwise FallbackPath.
		Checks the selected path, imports the PowerShell data file, and converts its
		contents to a hashtable. Reports a terminating error for a missing path,
		nonexistent file, or failed import. Does not validate the per-task scope schema.

	.PARAMETER TaskPath
		The explicit configuration-file path. Null or empty values select FallbackPath.

	.PARAMETER FallbackPath
		The configuration-file path used only when TaskPath is null or empty. An invalid
		explicit TaskPath fails rather than falling back to this value.

	.INPUTS
		None. Parameters do not accept pipeline input.

	.OUTPUTS
		System.Collections.Hashtable
		The imported task configuration, including any Scopes and Logging entries.

	.EXAMPLE
		PS C:\> Resolve-TaskConfiguration -TaskPath $null -FallbackPath 'C:\SidMigration\Scopes.psd1'

		Loads the fallback file within the module's session state.

	.NOTES
		Not exported. Uses Import-PSFPowerShellDataFile rather than executing the file
		as a script. Only use configuration files controlled by trusted administrators.

	.LINK
		Invoke-SHMigration
	#>
	[OutputType([hashtable])]
	[CmdletBinding()]
	param (
		[AllowEmptyString()]
		[AllowNull()]
		[string]
		$TaskPath,

		[AllowEmptyString()]
		[AllowNull()]
		[string]
		$FallbackPath
	)
	process {
		$effectivePath = $TaskPath
		if (-not $effectivePath) { $effectivePath = $FallbackPath }

		if (-not $effectivePath) {
			Stop-PSFFunction -String 'Resolve-TaskConfiguration.Error.NoPathSpecified' -EnableException $true -Cmdlet $PSCmdlet
		}

		if (-not (Test-Path -LiteralPath $effectivePath)) {
			Stop-PSFFunction -String 'Resolve-TaskConfiguration.Error.PathNotFound' -StringValues $effectivePath -EnableException $true -Cmdlet $PSCmdlet
		}

		try {
			Import-PSFPowerShellDataFile -Path $effectivePath -ErrorAction Stop | ConvertTo-PSFHashtable		}
		catch {
			Stop-PSFFunction -String 'Resolve-TaskConfiguration.Error.FailedToLoad' -StringValues $effectivePath -EnableException $true -Cmdlet $PSCmdlet -ErrorRecord $_
		}
	}
}