function Get-SHAttributeConverter {
	<#
	.SYNOPSIS
		Retrieves attribute conversion logic that has previously been registered.
	
	.DESCRIPTION
		Retrieves attribute conversion logic that has previously been registered.
		Using Register-SHAttributeConverter, it is possible to customize how attributes on Principals from the source domain map to attributes on Principals in the destination domain in a SID History Migration.
		Each conversion is specifically from ONE Source attribute to ONE Destination attribute.
	
	.PARAMETER FromAttribute
		Filter by attribute providing the value in the source domain.
		Defaults to: *
	
	.PARAMETER ToAttribute
		Filter by attribute receiving the value in the destination domain.
		Defaults to: *
	
	.EXAMPLE
		PS C:\> Get-SHAttributeConverter

		Lists all registered attribute converters.
	#>
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