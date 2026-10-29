function New-SHSession {
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