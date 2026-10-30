function Get-LdapRootDSE {
	<#
	.SYNOPSIS
		Reads an LDAP server's RootDSE metadata.

	.DESCRIPTION
		Internal helper that binds to LDAP://RootDSE and returns naming contexts,
		server identity, supported capabilities, synchronization information, and
		functional levels. Maps known numeric domain, forest, and controller levels
		to friendly names, including Windows Server 2025 levels. Unknown levels map
		to UnknownDomain, UnknownForest, or Unknown respectively.

	.PARAMETER Server
		An optional LDAP server. If empty or omitted, uses the default directory context.

	.PARAMETER Credential
		Optional credentials for the bind. If null, uses the calling identity.

	.INPUTS
		None. Parameters do not accept pipeline input.

	.OUTPUTS
		System.Management.Automation.PSCustomObject
		A SidHistoryMigrator.RootDSE object containing the selected RootDSE attributes.

	.EXAMPLE
		PS C:\> Get-LdapRootDSE -Server 'dc1.contoso.com' -Credential $credential

		Reads RootDSE from the specified controller within the module's session state.

	.NOTES
		Not exported. Requires Windows directory services and PSFramework's PsfHashtable type.

	.LINK
		Get-LdapDomain

	.LINK
		New-DirectoryEntry
	#>
	[CmdletBinding()]
	param (
		[AllowEmptyString()]
		[string]
		$Server,
		
		[PSCredential]
		[AllowNull()]
		$Credential
	)
	begin {
		$domainModeMap = [PsfHashtable]@{
			'0'  = 'Windows2000Domain'
			'1'  = 'Windows2003InterimDomain'
			'2'  = 'Windows2003Domain'
			'3'  = 'Windows2008Domain'
			'4'  = 'Windows2008R2Domain'
			'5'  = 'Windows2012Domain'
			'6'  = 'Windows2012R2Domain'
			'7'  = 'Windows2016Domain'
			'10' = 'Windows2025Domain'
		}
		$domainModeMap.SetDefaultValue('UnknownDomain')

		$domainControllerMap = [PsfHashtable]@{
			'0'  = 'Windows2000'
			'2'  = 'Windows2003'
			'3'  = 'Windows2008'
			'4'  = 'Windows2008R2'
			'5'  = 'Windows2012'
			'6'  = 'Windows2012R2'
			'7'  = 'Windows2016'
			'10' = 'Windows2025'
		}
		$domainControllerMap.SetDefaultValue('Unknown')

		$forestModeMap = [PsfHashtable]@{
			'0'  = 'Windows2000Forest'
			'1'  = 'Windows2003InterimForest'
			'2'  = 'Windows2003Forest'
			'3'  = 'Windows2008Forest'
			'4'  = 'Windows2008R2Forest'
			'5'  = 'Windows2012Forest'
			'6'  = 'Windows2012R2Forest'
			'7'  = 'Windows2016Forest'
			'10' = 'Windows2025Forest'
		}
		$forestModeMap.SetDefaultValue('UnknownForest')

		$adParam = @{}
		if ($Server) { $adParam.Server = $Server }
		if ($Credential) { $adParam.Credential = $Credential }
	}
	process {
		$entry = New-DirectoryEntry @adParam -Path 'LDAP://RootDSE'

		[PSCustomObject]@{
			PSTypeName                    = 'SidHistoryMigrator.RootDSE'
			DomainFunctionality           = $domainModeMap["$($entry.domainFunctionality)"]
			ForestFunctionality           = $forestModeMap["$($entry.forestFunctionality)"]
			DomainControllerFunctionality = $domainControllerMap["$($entry.domainControllerFunctionality)"]
			RootDomainNamingContext       = $($entry.rootDomainNamingContext)
			LdapServiceName               = $($entry.ldapServiceName)
			IsGlobalCatalogReady          = $($entry.isGlobalCatalogReady)
			SupportedSASLMechanisms       = $($entry.supportedSASLMechanisms)
			SupportedLDAPVersion          = $($entry.supportedLDAPVersion)
			SupportedLDAPPolicies         = $($entry.supportedLDAPPolicies)
			SupportedControl              = $($entry.supportedControl)
			SupportedCapabilities         = $($entry.supportedCapabilities)
			SubschemaSubentry             = $($entry.subschemaSubentry)
			ServerName                    = $($entry.serverName)
			SchemaNamingContext           = $($entry.schemaNamingContext)
			NamingContexts                = $($entry.namingContexts)
			IsSynchronized                = $($entry.isSynchronized)
			HighestCommittedUSN           = $($entry.highestCommittedUSN)
			DsServiceName                 = $($entry.dsServiceName)
			DnsHostName                   = $($entry.dnsHostName)
			DefaultNamingContext          = $($entry.defaultNamingContext)
			CurrentTime                   = $($entry.currentTime)
			ConfigurationNamingContext    = $($entry.configurationNamingContext)
		}
	}
}