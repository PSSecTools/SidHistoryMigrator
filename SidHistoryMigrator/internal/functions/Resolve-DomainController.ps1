function Resolve-DomainController {
	<#
	.SYNOPSIS
		Selects a writable domain controller from domain metadata.

	.DESCRIPTION
		Internal helper that returns Server unchanged when it matches an entry in
		ReplicaDirectoryServers. Otherwise, selects the PDC emulator or a random
		writable replica according to Mode. Discovers domain metadata when none is supplied.

	.PARAMETER Server
		The requested domain or controller. Also passed to domain discovery when Domain
		is omitted. Only a value present in ReplicaDirectoryServers is selected directly.

	.PARAMETER Credential
		Optional credentials passed to Get-LdapDomain when Domain is omitted.

	.PARAMETER Mode
		PDC selects Domain.PDCEmulator; Random selects a random entry from
		Domain.ReplicaDirectoryServers. Defaults to PDC. A recognized Server takes precedence.

	.PARAMETER Domain
		Optional preloaded domain metadata with PDCEmulator and ReplicaDirectoryServers
		properties, normally returned by Get-LdapDomain. Avoids repeated discovery.

	.INPUTS
		None. Parameters do not accept pipeline input.

	.OUTPUTS
		System.String
		The selected controller's DNS name when domain metadata contains a usable value.

	.EXAMPLE
		PS C:\> Resolve-DomainController -Domain $domain -Mode Random

		Selects a writable replica from preloaded metadata within the module's session state.

	.NOTES
		Not exported. Selection does not test the controller's reachability or health.

	.LINK
		Get-LdapDomain
	#>
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