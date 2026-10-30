Register-SHAttributeConverter -FromAttribute ObjectGUID -ToAttribute 'ms-ds-consistencyguid' -Code {
	param ($Value)

	$guid = $Value -as [guid]
	if (-not $guid) { throw "Not a guid: $Value" }

	$pieces = foreach ($byte in $guid.ToByteArray()) {
		'\{0:x2}' -f $byte
	}
	$pieces -join ''
}