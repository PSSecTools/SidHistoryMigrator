function Resolve-TaskConfiguration {
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