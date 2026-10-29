function Test-LdapCredential {
	[OutputType([bool])]
	[CmdletBinding()]
	param (
		[string]
		$Server,

		[PSCredential]
		$Credential
	)
	process {
		try { $null = Get-LdapObject -Server $Server -Credential $Credential -LdapFilter '(objectCategory=domainDNS)' -ErrorAction Stop }
		catch { return $false }
		$true
	}
}