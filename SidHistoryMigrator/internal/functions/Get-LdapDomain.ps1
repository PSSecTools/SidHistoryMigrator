function Get-LdapDomain {
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
		$adParam = @{}
		if ($Server) { $adParam.Server = $Server }
		if ($Credential) { $adParam.Credential = $Credential }
	}
	process {
		$domainDNS = Get-LdapObject -LdapFilter '(objectCategory=domainDNS)'
		$rootDSE = Get-LdapRootDSE @adParam

		$ridMaster = Get-LdapObject @adParam -LdapFilter '(objectCategory=*)' -SearchRoot $domainDNS.Ridmanagerreference -SearchScope Base -Property Fsmoroleowner
		$infraMaster = Get-LdapObject @adParam -LdapFilter '(ObjectCategory=*)' -SearchRoot "CN=Infrastructure,$($domainDNS.DistinguishedName)" -SearchScope Base -Property Fsmoroleowner
		$reference = Get-LdapObject @adParam -LdapFilter "(&(objectCategory=Crossref)(ncname=$($domainDNS.DistinguishedName)))" -SearchRoot $rootDSE.ConfigurationNamingContext

		$rootNC = Get-LdapObject @adParam -LdapFilter "(&(objectCategory=Crossref)(ncname=$($rootDSE.RootDomainNamingContext)))" -SearchRoot $rootDSE.ConfigurationNamingContext

		[PSCustomObject]@{
			PSTypeName                         = 'SidHistoryMigrator.DomainInfo'
			AllowedDNSSuffixes                 = $domainDNS.'Msds-Alloweddnssuffixes'
			ChildDomains                       = $null
			ComputersContainer                 = $($domainDNS.Wellknownobjects.Where{ $_ -match 'AA312825768811D1ADED00C04FD8D5CD' } -replace '^.+:')
			DeletedObjectsContainer            = $($domainDNS.Wellknownobjects.Where{ $_ -match '18E2EA80684F11D2B9AA00C04F79F805' } -replace '^.+:')
			DistinguishedName                  = $domainDNS.DistinguishedName
			DNSRoot                            = $reference.DnsRoot
			DomainControllersContainer         = $($domainDNS.Wellknownobjects.Where{ $_ -match 'A361B2FFFFD211D1AA4B00C04FD7D83A' } -replace '^.+:')
			DomainMode                         = $rootDSE.DomainFunctionality
			DomainSID                          = $domainDNS.ObjectSID
			ForeignSecurityPrincipalsContainer = $($domainDNS.Wellknownobjects.Where{ $_ -match '22B70C67D56E4EFB91E9300FCA3DC1AA' } -replace '^.+:')
			Forest                             = $rootNC.DnsRoot
			InfrastructureMaster               = (Get-LdapObject @adParam -LdapFilter '(objectCategory=*)' -SearchRoot ($infraMaster.Fsmoroleowner -split ',', 2)[1] -SearchScope Base -Property DnsHostName).DnsHostName
			LostAndFoundContainer              = $($domainDNS.Wellknownobjects.Where{ $_ -match 'AB8153B7768811D1ADED00C04FD8D5CD' } -replace '^.+:')
			ManagedBy                          = $domainDNS.Managedby
			Name                               = $domainDNS.Name
			NetBIOSName                        = $reference.Netbiosname
			ObjectClass                        = 'domainDNS'
			ObjectGUID                         = $domainDNS.ObjectGuid
			ParentDomain                       = $null
			PDCEmulator                        = (Get-LdapObject @adParam -LdapFilter '(objectCategory=*)' -SearchRoot ($domainDNS.Fsmoroleowner -split ',', 2)[1] -SearchScope Base -Property DnsHostName).DnsHostName
			QuotasContainer                    = $($domainDNS.Wellknownobjects.Where{ $_ -match '6227F0AF1FC2410D8E3BB10615BB5B0F' } -replace '^.+:')
			ReadOnlyReplicaDirectoryServers    = (Get-LdapObject @adParam -LdapFilter '(primaryGroupID=521)' -Property DNSHostName).DnsHostName
			ReplicaDirectoryServers            = (Get-LdapObject @adParam -LdapFilter '(primaryGroupID=516)' -Property DNSHostName).DnsHostName
			RIDMaster                          = (Get-LdapObject @adParam -LdapFilter '(objectCategory=*)' -SearchRoot ($ridMaster.Fsmoroleowner -split ',', 2)[1] -SearchScope Base -Property DnsHostName).DnsHostName
			SystemsContainer                   = $($domainDNS.Wellknownobjects.Where{ $_ -match 'AB1D30F3768811D1ADED00C04FD8D5CD' } -replace '^.+:')
			UsersContainer                     = $($domainDNS.Wellknownobjects.Where{ $_ -match 'A9D1CA15768811D1ADED00C04FD8D5CD' } -replace '^.+:')
			# LastLogonReplicationInterval       = $null
			# LinkedGroupPolicyObjects           = $null
			# PublicKeyRequiredPasswordRolling   = $null
			# SubordinateReferences              = $null
		}
	}
}