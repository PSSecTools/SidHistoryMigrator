function Convert-SHAttribute {
	<#
	.SYNOPSIS
		Performs the attribute value conversion into the form an LDAP filter can use in the destination domain.
	
	.DESCRIPTION
		Performs the attribute value conversion into the form an LDAP filter can use in the destination domain.

		When matching principals, a source attribute is used in an LDAP filter for the matching attribute on the other side.
		In case of SamAccountName -> SamAccountName that is easy and requires no adjustments.
		In other cases - such as Guid fields - we can't just use the value from the source straight in an LDAP Filter.
		The value needs conversion.

		This command is responsible for that conversion.

		Use Register-SHAttributeConverter to define custom conversion logic (more details on that in that command's help).
		If no converter is assigned to a given attribute comparison, the value of the source attribute is used as string in the LDAP filter searching for a matching principal in the destination domain.
	
	.PARAMETER Value
		The value that was in the current Principal's attribute we are using for the comparison.
	
	.PARAMETER FromAttribute
		The name of the attribute providing the value on the source principal.
	
	.PARAMETER ToAttribute
		The name of the attribute we compare the value to on potential destination principals.
	
	.EXAMPLE
		PS C:\> Convert-SHAttribute -Value $principal.$sourceAttribute -FromAttribute $sourceAttribute -ToAttribute $destinationAttribute

		Returns the string value used to search for a matching principal in the destination domain for the current $principal, based on the value of that principal's source attribute value.
	#>
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