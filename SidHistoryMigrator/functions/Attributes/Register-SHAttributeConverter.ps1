function Register-SHAttributeConverter {
	<#
	.SYNOPSIS
		Register Logic to convert the value of an attribute from one format to another.
	
	.DESCRIPTION
		Register Logic to convert the value of an attribute from one format to another.
		This is used as part of the identity matching process between a principal in the source domain and one in the destination domain.

		When matching principals, a source attribute is used in an LDAP filter for the matching attribute on the other side.
		In case of SamAccountName -> SamAccountName that is easy and requires no adjustments.
		In other cases - such as Guid fields - we can't just use the value from the source straight in an LDAP Filter.
		The value needs conversion.

		This is where attribute converters come in, which tell the system how to process the value in the source attribute so that an LDAP Filter can use it, when matching values in the destination domain.
	
	.PARAMETER FromAttribute
		Which attribute from the Principal in the source domain provides the data to be converted.
		Not used in the conversion logic, this value is used to figure out which converter - if any - to use in a comparison operation.
	
	.PARAMETER ToAttribute
		Which attribute from the Principal in the destination domain will the converted value be compared to.
		Not used in the conversion logic, this value is used to figure out which converter - if any - to use in a comparison operation.
	
	.PARAMETER Code
		The code performing the conversion.
		Receives a single argument - the value to convert - and is expected to provide a single return string that will be used in the LDAP filter to find the match.
	
	.EXAMPLE
		PS C:\> Register-SHAttributeConverter -FromAttribute ObjectGUID -ToAttribute 'ms-ds-consistencyguid' -Code {
			$guid = $_ -as [guid]
			if (-not $guid) { throw "Not a guid: $_" }

			$pieces = foreach ($byte in $guid.ToByteArray()) {
				'\{0:x2}' -f $byte
			}
			$pieces -join ''
		}

		Registers a converter that matches the ObjectGUID attribute from the source domain with the "ms-ds-consistencyguid" attribute in the destination domain.
	#>
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