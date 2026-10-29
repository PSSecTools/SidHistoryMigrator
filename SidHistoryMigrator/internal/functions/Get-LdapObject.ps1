function Get-LdapObject {
	<#
        .SYNOPSIS
            Use LDAP to search in Active Directory

        .DESCRIPTION
            Utilizes LDAP to perform swift and efficient LDAP Queries.

        .PARAMETER LdapFilter
            The search filter to use when searching for objects.
            Must be a valid LDAP filter.

        .PARAMETER Property
            The properties to retrieve.
            Keep bandwidth in mind and only request what is needed.

        .PARAMETER SearchRoot
            The root path to search in.
            This generally expects either the distinguished name of the Organizational unit or the DNS name of the domain.
            Alternatively, any legal LDAP protocol address can be specified.

        .PARAMETER Configuration
            Rather than searching in a specified path, switch to the configuration naming context.

        .PARAMETER Raw
            Return the raw AD object without processing it for PowerShell convenience.

		.PARAMETER NoMethod
			Do not add a ToString method to the objects returned.
			This offers greater convenience but also adds a low per-object performance overhead.

        .PARAMETER PageSize
            Rather than searching in a specified path, switch to the schema naming context.

        .PARAMETER MaxSize
            The maximum number of items to return.

        .PARAMETER SearchScope
            Whether to search all OUs beneath the target root, only directly beneath it or only the root itself.
	
		.PARAMETER AddProperty
			Add additional properties to the output object.
			Use to optimize performance, avoiding needing to use Add-Member.

        .PARAMETER Server
            The server to contact for this query.

        .PARAMETER Credential
            The credentials to use for authenticating this query.
	
		.PARAMETER TypeName
			The name to give the output object

        .EXAMPLE
            PS C:\> Get-LdapObject -LdapFilter '(PrimaryGroupID=516)'
            
            Searches for all objects with primary group ID 516 (hint: Domain Controllers).
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