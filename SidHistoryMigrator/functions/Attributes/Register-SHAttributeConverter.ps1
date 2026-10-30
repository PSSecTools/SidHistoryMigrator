function Register-SHAttributeConverter {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$FromAttribute,

		[Parameter(Mandatory = $true)]
		[string]
		$ToAttribute,

		[Parameter(Mandatory = $true)]
		[PSFScriptblock]
		$Code
	)
	process {
		$script:_AttributeConverters["$FromAttribute-$ToAttribute"] = [PSCustomObject]@{
			PSTypeName = 'SidHistoryMigrator.AttributeConverter'
			From       = $FromAttribute
			To         = $ToAttribute
			Code       = $Code
		}
	}
}