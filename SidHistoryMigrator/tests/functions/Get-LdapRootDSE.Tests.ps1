BeforeAll {
	# Load only these functions: other internal commands are still placeholders.
	. "$PSScriptRoot\..\..\internal\functions\Get-LdapObject.ps1"
	. "$PSScriptRoot\..\..\internal\functions\Get-LdapRootDSE.ps1"
}

Describe 'Get-LdapRootDSE' {
	BeforeEach {
		Mock Get-LdapObject {
			[pscustomobject]@{
				dnsHostName = 'dc1.contoso.com'
				namingContexts = @('DC=contoso,DC=com', 'CN=Configuration,DC=contoso,DC=com')
			}
		}
	}

	It 'Queries only RootDSE using the existing LDAP helper' {
		$null = Get-LdapRootDSE

		Should -Invoke Get-LdapObject -Times 1 -Exactly -ParameterFilter {
			$LdapFilter -eq '(objectClass=*)' -and
			$SearchRoot -eq 'LDAP://RootDSE' -and
			$SearchScope -eq [System.DirectoryServices.SearchScope]::Base -and
			$MaxSize -eq 1 -and
			$TypeName -eq 'SidHistoryMigrator.LdapRootDSE'
		}
	}

	It 'Uses the default server and current credentials when none are specified' {
		$null = Get-LdapRootDSE

		Should -Invoke Get-LdapObject -Times 1 -Exactly -ParameterFilter {
			-not $Server -and $null -eq $Credential
		}
	}

	It 'Requests the Get-ADRootDSE default attributes' {
		$null = Get-LdapRootDSE

		Should -Invoke Get-LdapObject -Times 1 -Exactly -ParameterFilter {
			$expected = @(
				'configurationNamingContext', 'currentTime', 'defaultNamingContext',
				'dnsHostName', 'domainControllerFunctionality', 'domainFunctionality',
				'dsServiceName', 'forestFunctionality', 'highestCommittedUSN',
				'isGlobalCatalogReady', 'isSynchronized', 'ldapServiceName',
				'namingContexts', 'rootDomainNamingContext', 'schemaNamingContext',
				'serverName', 'subschemaSubentry', 'supportedCapabilities',
				'supportedControl', 'supportedLDAPPolicies', 'supportedLDAPVersion',
				'supportedSASLMechanisms'
			)
			@($Property).Count -eq $expected.Count -and
			-not (Compare-Object -ReferenceObject $expected -DifferenceObject $Property)
		}
	}

	It 'Passes an explicit server and port through unchanged' {
		$null = Get-LdapRootDSE -Server 'lds.contoso.com:50000'

		Should -Invoke Get-LdapObject -Times 1 -Exactly -ParameterFilter {
			$Server -eq 'lds.contoso.com:50000'
		}
	}

	It 'Passes explicit credentials through unchanged' {
		$credential = [PSCredential]::new('CONTOSO\testuser', [System.Security.SecureString]::new())
		$null = Get-LdapRootDSE -Credential $credential

		Should -Invoke Get-LdapObject -Times 1 -Exactly -ParameterFilter {
			$Credential.UserName -eq 'CONTOSO\testuser'
		}
	}

	It 'Adds requested attributes without replacing the defaults' {
		$null = Get-LdapRootDSE -Property supportedExtension, dsSchemaAttrCount

		Should -Invoke Get-LdapObject -Times 1 -Exactly -ParameterFilter {
			$Property -contains 'supportedExtension' -and
			$Property -contains 'dsSchemaAttrCount' -and
			$Property -contains 'defaultNamingContext' -and
			$Property.Count -eq 24
		}
	}

	It 'Accepts the Properties alias and the wildcard alongside explicit attributes' {
		$null = Get-LdapRootDSE -Properties '*', supportedExtension

		Should -Invoke Get-LdapObject -Times 1 -Exactly -ParameterFilter {
			$Property -contains '*' -and
			$Property -contains 'supportedExtension' -and
			$Property -contains 'defaultNamingContext'
		}
	}

	It 'Does not request duplicate attributes regardless of casing' {
		$null = Get-LdapRootDSE -Property DNSHOSTNAME, supportedExtension, SUPPORTEDEXTENSION

		Should -Invoke Get-LdapObject -Times 1 -Exactly -ParameterFilter {
			@($Property | Where-Object { $_ -eq 'dnsHostName' }).Count -eq 1 -and
			@($Property | Where-Object { $_ -eq 'supportedExtension' }).Count -eq 1 -and
			$Property.Count -eq 23
		}
	}

	It 'Preserves the object and multivalued attributes returned by the LDAP helper' {
		$result = Get-LdapRootDSE

		@($result).Count | Should -Be 1
		$result.dnsHostName | Should -Be 'dc1.contoso.com'
		$result.namingContexts.Count | Should -Be 2
		$result.namingContexts[1] | Should -Be 'CN=Configuration,DC=contoso,DC=com'
	}

	It 'Propagates LDAP connection and authentication failures' {
		Mock Get-LdapObject { throw 'LDAP bind failed' }

		{ Get-LdapRootDSE -ErrorAction Stop } | Should -Throw '*LDAP bind failed*'
	}

	It 'Rejects an empty property name' {
		{ Get-LdapRootDSE -Property '' } | Should -Throw
		Should -Invoke Get-LdapObject -Times 0 -Exactly
	}
}