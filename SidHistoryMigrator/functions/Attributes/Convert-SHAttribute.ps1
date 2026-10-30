function Convert-SHAttribute {
	[OutputType([string])]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[AllowEmptyCollection()]
		[AllowEmptyString()]
		[AllowNull()]
		$Value,

		[Parameter(Mandatory = $true)]
		[string]
		$FromAttribute,

		[Parameter(Mandatory = $true)]
		[string]
		$ToAttribute
	)
	process {
		$converter = $script:_AttributeConverters["$FromAttribute-$ToAttribute"]
		if (-not $converter) { return $Value -as [string] }

		try { $($converter.Code.InvokeEx($false, $Value, $null, $Null, $true, $true, $Value)) -as [string] }
		catch {
			Stop-PSFFunction -String 'Convert-SHAttribute.Error.ConversionFailed' -StringValues $Value, $FromAttribute, $ToAttribute -ErrorRecord $_ -EnableException $true -Cmdlet $PSCmdlet
		}
	}
}