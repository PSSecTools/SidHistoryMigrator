Register-SHAttributeConverter -FromAttribute ObjectGUID -ToAttribute 'ms-ds-consistencyguid' -Code {
	$guid = $_ -as [guid]
	if (-not $guid) { throw "Not a guid: $_" }

	$pieces = foreach ($byte in $guid.ToByteArray()) {
		'\{0:x2}' -f $byte
	}
	$pieces -join ''
}