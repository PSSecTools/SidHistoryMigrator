function Test-LdapCredential {
	<#
	.SYNOPSIS
		Tests whether an LDAP domain query completes without an error.

	.DESCRIPTION
		Internal helper that searches for a domainDNS object using the specified server
		and credential. Returns false if the query throws and true otherwise. A true result
		means the query completed, not that any object was returned or migration rights exist.

	.PARAMETER Server
		The LDAP server or domain to query. If omitted, uses the default directory context.

	.PARAMETER Credential
		The credential used for the query. If omitted, uses the calling identity.

	.INPUTS
		None. Parameters do not accept pipeline input.

	.OUTPUTS
		System.Boolean
		True when the query does not throw; otherwise false.

	.EXAMPLE
		PS C:\> Test-LdapCredential -Server 'dc1.contoso.com' -Credential $credential

		Checks LDAP query access within the module's session state.

	.NOTES
		Not exported. Connectivity, name resolution, and other query failures also
		produce false; this helper does not distinguish an invalid password from them.

	.LINK
		Get-LdapObject
	#>
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