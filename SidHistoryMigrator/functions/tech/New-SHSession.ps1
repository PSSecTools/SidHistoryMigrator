function New-SHSession {
	<#
	.SYNOPSIS
		Creates an authenticated native directory-service session.

	.DESCRIPTION
		Discovers domain information through LDAP, creates native password credentials,
		and binds a DSSession to the domain. Uses Server directly when it matches a writable
		replica's DNS name; otherwise, connects to the discovered PDC emulator.
		The returned session can be used by Copy-SHSidHistory.

	.PARAMETER Server
		The domain DNS name or domain-controller DNS name used for discovery and selection.

	.PARAMETER Credential
		The credential used for LDAP discovery and the native directory-service bind.
		Prefer the DOMAIN\user format for the native credential parser. Unqualified names
		use USERDNSDOMAIN; the native parser does not separately split UPN-style names.

	.INPUTS
		None. Parameters do not accept pipeline input.

	.OUTPUTS
		SidHistoryMigrator.DSSession
		An authenticated session with Domain and Server fields. Implements IDisposable.

	.EXAMPLE
		PS C:\> $session = New-SHSession -Server 'dc1.contoso.com' -Credential (Get-Credential -UserName 'CONTOSO\MigrationAdmin')
		PS C:\> try { $session | Select-Object Domain, Server } finally { $session.Dispose() }

		Creates a native session, displays the selected domain and server, and releases it.

	.NOTES
		Requires Windows and the module's native interop assembly. Call Dispose when the
		session is no longer needed to release native binding and credential handles.
		Domain discovery currently begins in the default LDAP context; see
		about_SidHistoryMigrator for the Get-LdapDomain discovery limitation.

	.LINK
		Copy-SHSidHistory

	.LINK
		about_SidHistoryMigrator
	#>
	[OutputType([SidHistoryMigrator.DSSession])]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Server,
		
		[Parameter(Mandatory = $true)]
		[PSCredential]
		$Credential
	)

	$domain = Get-LdapDomain -Server $Server -Credential $Credential -ErrorAction Stop
	if ($Server -in $domain.ReplicaDirectoryServers) { $dc = $Server }
	else { $dc = $domain.PdcEmulator }

	$session = [SidHistoryMigrator.DSSession]::new()
	$session.Credential = $Credential
	$session.Authenticate()
	$session.Connect($domain.DnsRoot, $dc)
	$session
}