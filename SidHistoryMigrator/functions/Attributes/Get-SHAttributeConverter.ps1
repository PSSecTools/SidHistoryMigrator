function Get-SHAttributeConverter {
	[CmdletBinding()]
	param (
		[string]
		$FromAttribute = '*',

		[string]
		$ToAttribute = '*'
	)
	process {
		$script:_AttributeConverters.Values | Where-Object {
			$_.From -like $FromAttribute -and
			$_.To -like $ToAttribute
		}
	}
}