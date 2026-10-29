function Resolve-DomainController {
	[CmdletBinding()]
	param (
		[string]
		$Server,

		[PSCredential]
		$Credential,

		[ValidateSet('PDC', 'Random')]
		[string]
		$Mode = 'PDC',

		$Domain
	)
	begin {
		$adParam = @{}
		if ($Server) { $adParam.Server = $Server }
		if ($Credential) { $adParam.Credential = $Credential }
	}
	process {
		if (-not $Domain) { $Domain = Get-LdapDomain @adParam }

		if ($Server -in $Domain.ReplicaDirectoryServers) { return $Server }
		switch ($Mode) {
			Random { $Domain.ReplicaDirectoryServers | Get-Random }
			default { $Domain.PDCEmulator }
		}
	}
}