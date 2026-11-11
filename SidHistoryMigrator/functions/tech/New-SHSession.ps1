function New-SHSession {
	<#
	.SYNOPSIS
		Creates an authenticated native directory-service session.

	.DESCRIPTION
		Creates an authenticated native directory-service session.	
		Will honor the selected server, but fall back to the PDC Emulator if specifying the domain name.

	.PARAMETER Server
		The domain DNS name or domain-controller DNS name used for discovery and selection.
		Will connect to the PDC Emulator is specifying a domain.

	.PARAMETER Credential
		The credentials to use for the request.

	.EXAMPLE
		PS C:\> $session = New-SHSession -Server 'dc1.contoso.com' -Credential 'CONTOSO\MigrationAdmin'

		Creates a directory-service session to dc1.contoso.com.
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