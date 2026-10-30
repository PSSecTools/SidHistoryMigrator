function New-DirectoryEntry {
	<#
	.SYNOPSIS
		Creates a DirectoryEntry wrapper for an LDAP path.

	.DESCRIPTION
		Internal helper that normalizes a distinguished name, domain DNS name, or LDAP
		address and constructs a System.DirectoryServices.DirectoryEntry. Optionally
		targets a server and supplies credentials. Does not create an object in Active Directory.

	.PARAMETER Path
		The directory location. LDAP:// paths are retained; distinguished names are
		prefixed with LDAP://; DNS domain names are converted to DC components.
		If omitted, uses the default directory context.

	.PARAMETER Server
		An optional server inserted into the LDAP address. If Path is empty, the
		resulting server-only address uses that server's default context.

	.PARAMETER Credential
		Optional credentials for the DirectoryEntry. Null or PSCredential.Empty uses
		the calling identity. With credentials but neither Path nor Server, derives the
		domain path from USERDNSDOMAIN.

	.INPUTS
		None. Parameters do not accept pipeline input.

	.OUTPUTS
		System.DirectoryServices.DirectoryEntry
		The directory entry wrapper. Binding can be deferred until a property is accessed.

	.EXAMPLE
		PS C:\> New-DirectoryEntry

		Creates a wrapper for the default context within the module's session state.

	.EXAMPLE
		PS C:\> New-DirectoryEntry -Path 'OU=Accounts,DC=contoso,DC=com' -Server 'dc1.contoso.com' -Credential $credential

		Creates a wrapper targeting the Accounts OU on the specified server.

	.NOTES
		Not exported. Requires Windows directory services. Call Dispose when an entry
		created directly by a caller is no longer needed. This helper does not test
		whether the LDAP object exists or whether credentials are valid.

	.LINK
		Get-LdapObject
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
	[CmdletBinding()]
	param (
		[string]
		$Path,
		
		[AllowEmptyString()]
		[string]
		$Server,
		
		[PSCredential]
		[AllowNull()]
		$Credential
	)
	
	if (-not $Path) { $resolvedPath = '' }
	elseif ($Path -like 'LDAP://*') { $resolvedPath = $Path }
	elseif ($Path -notlike '*=*') { $resolvedPath = 'LDAP://DC={0}' -f ($Path -split '\.' -join ',DC=') }
	else { $resolvedPath = "LDAP://$($Path)" }
	
	if ($Server -and ($resolvedPath -notlike "LDAP://$($Server)/*")) {
		$resolvedPath = ('LDAP://{0}/{1}' -f $Server, $resolvedPath.Replace('LDAP://', '')).Trim('/')
	}
	
	if (($null -eq $Credential) -or ($Credential -eq [PSCredential]::Empty)) {
		if ($resolvedPath) { New-Object System.DirectoryServices.DirectoryEntry($resolvedPath) }
		else {
			$entry = New-Object System.DirectoryServices.DirectoryEntry
			New-Object System.DirectoryServices.DirectoryEntry(('LDAP://{0}' -f $entry.distinguishedName[0]))
		}
	}
	else {
		if ($resolvedPath) { New-Object System.DirectoryServices.DirectoryEntry($resolvedPath, $Credential.UserName, $Credential.GetNetworkCredential().Password) }
		else { New-Object System.DirectoryServices.DirectoryEntry(('LDAP://DC={0}' -f ($env:USERDNSDOMAIN -split '\.' -join ',DC=')), $Credential.UserName, $Credential.GetNetworkCredential().Password) }
	}
}
