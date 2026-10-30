function Get-LdapObject {
	<#
	.SYNOPSIS
		Searches Active Directory with an LDAP filter.

	.DESCRIPTION
		Internal helper using DirectorySearcher to perform paged LDAP searches. By default,
		returns PowerShell objects, converts ObjectGuid and ObjectSID to their .NET types,
		and reduces ObjectClass to its most specific value. Other property values are
		emitted as returned by the directory. Can return raw SearchResult objects instead.

	.PARAMETER LdapFilter
		The required LDAP search filter, also accepted at position zero. Values interpolated
		into filters must already be escaped for LDAP; this helper does not escape them.

	.PARAMETER Property
		Attributes to retrieve. Defaults to *, requesting all normal attributes.
		Alias: Properties. Request only the attributes needed to reduce query cost.

	.PARAMETER SearchRoot
		The search base as a distinguished name, domain DNS name, or LDAP path. Defaults
		to the directory context selected by New-DirectoryEntry. Alias: SearchBase.
		Cannot be combined with Configuration.

	.PARAMETER Configuration
		Searches CN=Configuration beneath the default context selected for the bind
		instead of an explicit SearchRoot. Uses a separate parameter set.

	.PARAMETER Raw
		Returns System.DirectoryServices.SearchResult objects rather than converted objects.
		Property conversion, AddProperty, and TypeName are not applied. Use NoMethod as
		well to avoid adding the helper's ToString script method to raw results.

	.PARAMETER NoMethod
		Skips adding a ToString script method that returns DistinguishedName or AdsPath.
		Avoids the per-object Add-Member overhead.

	.PARAMETER PageSize
		The LDAP query page size, from 1 through 1000. Defaults to 1000. Controls paging,
		not the total number of results returned.

	.PARAMETER MaxSize
		The searcher's total result-size limit when greater than zero. Defaults to zero,
		which leaves the limit unset; directory server limits still apply. Alias: SizeLimit.

	.PARAMETER SearchScope
		Base searches only the root object; OneLevel searches its immediate children;
		Subtree searches the root and all descendants. Defaults to Subtree.

	.PARAMETER AddProperty
		A hashtable of additional properties to merge into each converted result. Keys
		must not collide with properties already in the result. Ignored with Raw.

	.PARAMETER Server
		The optional LDAP server to contact. If omitted, uses the default directory context.

	.PARAMETER Credential
		Optional credentials for the query. If omitted, uses the calling identity.

	.PARAMETER TypeName
		An optional PowerShell type name for converted objects. Overrides the default
		type name derived from ObjectClass. Hidden from normal parameter discovery.

	.INPUTS
		None. Parameters do not accept pipeline input.

	.OUTPUTS
		System.Management.Automation.PSCustomObject
		Converted directory objects by default.
		System.DirectoryServices.SearchResult
		Raw directory search results when Raw is enabled.

	.EXAMPLE
		PS C:\> Get-LdapObject -LdapFilter '(primaryGroupID=516)' -Property DNSHostName

		Retrieves writable domain-controller DNS names within the module's session state.

	.EXAMPLE
		PS C:\> Get-LdapObject -LdapFilter '(objectCategory=group)' -SearchBase 'OU=Groups,DC=contoso,DC=com' -SearchScope OneLevel -Property SamAccountName

		Searches only the immediate children of the specified OU for groups.

	.NOTES
		Not exported by the manifest. Defines the internal alias ldap. Uses Windows
		directory services and does not require the ActiveDirectory PowerShell module.

	.LINK
		New-DirectoryEntry
	#>
	[Alias('ldap')]
	[CmdletBinding(DefaultParameterSetName = 'SearchRoot')]
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[string]
		$LdapFilter,
		
		[Alias('Properties')]
		[string[]]
		$Property = '*',
		
		[Parameter(ParameterSetName = 'SearchRoot')]
		[Alias('SearchBase')]
		[string]
		$SearchRoot,
		
		[Parameter(ParameterSetName = 'Configuration')]
		[switch]
		$Configuration,
		
		[switch]
		$Raw,

		[switch]
		$NoMethod,
		
		[ValidateRange(1, 1000)]
		[int]
		$PageSize = 1000,
		
		[Alias('SizeLimit')]
		[int]
		$MaxSize,
		
		[System.DirectoryServices.SearchScope]
		$SearchScope = 'Subtree',
		
		[System.Collections.Hashtable]
		$AddProperty,
		
		[string]
		$Server,
		
		[PSCredential]
		$Credential,
		
		[Parameter(DontShow = $true)]
		[string]
		$TypeName
	)
	
	begin {
		#region Utility Functions
		function Get-PropertyName {
			<#
			.SYNOPSIS
				Returns the preferred output name for an LDAP property.

			.DESCRIPTION
				Preserves the casing requested by the caller, uses canonical casing for
				common Active Directory properties, and title-cases all other names.

			.PARAMETER Key
				The property name returned by the DirectorySearcher.

			.PARAMETER Property
				The property names originally requested by the caller.

			.EXAMPLE
				PS C:\> Get-PropertyName -Key 'samaccountname' -Property 'samAccountName'

				Returns samAccountName, preserving the caller's requested casing.
			#>
			[OutputType([string])]
			[CmdletBinding()]
			param (
				[string]
				$Key,
				
				[string[]]
				$Property
			)
			
			if ($hit = @($Property).Where{ $_ -eq $Key }) { return $hit[0] }
			if ($Key -eq 'ObjectClass') { return 'ObjectClass' }
			if ($Key -eq 'ObjectGuid') { return 'ObjectGuid' }
			if ($Key -eq 'ObjectSID') { return 'ObjectSID' }
			if ($Key -eq 'DistinguishedName') { return 'DistinguishedName' }
			if ($Key -eq 'SamAccountName') { return 'SamAccountName' }
			$script:culture.TextInfo.ToTitleCase($Key)
		}
		#endregion Utility Functions
		
		$script:culture = Get-Culture

		#region Prepare Searcher
		$searcher = New-Object system.directoryservices.directorysearcher
		$searcher.PageSize = $PageSize
		$searcher.SearchScope = $SearchScope
		
		if ($MaxSize -gt 0) {
			$Searcher.SizeLimit = $MaxSize
		}
		
		if ($SearchRoot) {
			$searcher.SearchRoot = New-DirectoryEntry -Path $SearchRoot -Server $Server -Credential $Credential
		}
		else {
			$searcher.SearchRoot = New-DirectoryEntry -Server $Server -Credential $Credential
		}
		if ($Configuration) {
			$searcher.SearchRoot = New-DirectoryEntry -Path ('LDAP://CN=Configuration,{0}' -f $searcher.SearchRoot.distinguishedName[0]) -Server $Server -Credential $Credential
		}
		
		Write-Verbose "Searching $($SearchScope) in $($searcher.SearchRoot.Path)"
		
		if ($Credential) {
			$searcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry($searcher.SearchRoot.Path, $Credential.UserName, $Credential.GetNetworkCredential().Password)
		}
		
		$searcher.Filter = $LdapFilter
		
		foreach ($propertyName in $Property) {
			$null = $searcher.PropertiesToLoad.Add($propertyName)
		}
		
		Write-Verbose "Search filter: $LdapFilter"
		#endregion Prepare Searcher

		#region Processor
		$processor = {
			$ldapobject = $_
			if ($Raw) {
				$ldapobject
				continue
			}
			#region Process/Refine Output Object
			$resultHash = @{ }
			foreach ($key in $ldapobject.Properties.Keys) {
				$resultHash[(Get-PropertyName -Key $key -Property $Property)] = switch ($key) {
					'ObjectClass' { $ldapobject.Properties[$key][@($ldapobject.Properties[$key]).Count - 1] }
					'ObjectGuid' { [guid]::new(([byte[]]($($ldapobject.Properties[$key])))) }
					'ObjectSID' { [System.Security.Principal.SecurityIdentifier]::new(([byte[]]($($ldapobject.Properties[$key]))), 0) }
						
					default { $($ldapobject.Properties[$key]) }
				}
			}
			if ($resultHash.ContainsKey('ObjectClass')) { $resultHash['PSTypeName'] = $resultHash['ObjectClass'] }
			if ($TypeName) { $resultHash['PSTypeName'] = $TypeName }
			if ($AddProperty) { $resultHash += $AddProperty }
			[pscustomobject]$resultHash
			#endregion Process/Refine Output Object
		}
		#endregion Processor
	}
	process {
		try {
			if ($NoMethod) {
				$searcher.FindAll() | ForEach-Object $processor
			}
			else {
				$searcher.FindAll() | ForEach-Object $processor | Add-Member -MemberType ScriptMethod -Name ToString -Value {
					if ($this.DistinguishedName) { return $this.DistinguishedName }
					return $this.AdsPath
				} -PassThru -Force
			}
		}
		catch {
			throw
		}
	}
}