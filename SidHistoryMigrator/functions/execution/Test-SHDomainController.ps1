function Test-SHDomainController {
	<#
	.SYNOPSIS
		Tests, whether the targeted domain(controller) is correctly configured for SID History Migration.

	.DESCRIPTION
		Tests, whether the targeted domain(controller) is correctly configured for SID History Migration:
		
		- Is the account used a _direct_ member of the Domain Admins?
		- Has the DC auditing for "Account Management" (Success AND Failure) configured?
		- In the source domain, does a group with name "<NetBIOSName>$$$" exist?

		It does not verify the trust between the domains that are part of the migration!

	.PARAMETER Server
		The domain or domain controller to inspect.
		Resolves to the PDC Emulator if specifying the domain.

	.PARAMETER Credential
		The credentials to use.
		Both to run some of the tests, as well as to verify, whether they would be valid credentials to use for the migration.

	.PARAMETER Type
		Whether the DC is on the Source or Destination side of the migration.

	.EXAMPLE
		PS C:\> Test-SHDomainController -Server 'contoso.com' -Credential $cred -Type Source

		Reports whether contoso.com's PDC Emulator is correctly configured as the source for a SID History Migration.

	.EXAMPLE
		PS C:\> Test-SHDomainController -Server 'fabrikam.org' -Credential $destCred -Type Destination

		Reports whether fabrikam.org's PDC Emulator is correctly configured as the destination for a SID History Migration.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[PSFComputer]
		$Server,

		[Parameter(Mandatory = $true)]
		[PSCredential]
		$Credential,

		[Parameter(Mandatory = $true)]
		[ValidateSet('Source', 'Destination')]
		[string]
		$Type
	)
	begin {
		$adParam = @{
			Server     = $Server
			Credential = $Credential
		}

		function New-TestResult {
			[CmdletBinding()]
			param (
				$Server,
				$Type,
				$Issue
			)

			[PSCustomObject]@{
				Server = $Server
				Type   = $Type
				Issue  = $Issue
			}
		}
	}
	process {
		$domain = Get-LdapDomain @adParam
		$computerName = Resolve-DomainController @adParam -Domain $domain

		# Auditing
		$config = Invoke-Command -ComputerName $computerName -Credential $Credential -ScriptBlock {
			$data = $(auditpol /get /category:"Account Management" /r) | ConvertFrom-Csv
			[PSCustomObject]@{
				Data         = $data
				IsConfigured = -not ($data.'Inclusion Setting' | Where-Object { $_ -ne 'Success and Failure' })
			}
		}
		if (-not $config.IsConfigured) {
			New-TestResult -Server $computerName -Type Auditing -Issue "Auditing for 'Account Management' must be enabled. Enable by GPO or running 'auditpol /set /category:`"Account Management`" /success:enable /failure:enable'"
		}

		# Migration Group
		if ($Type -eq 'Source') {
			$migrationGroup = Get-LdapObject @adParam -LdapFilter "(&(objectCategory=group)(samAccountName=$($domain.NetBiosName)`$`$`$))"
			if (-not $migrationGroup) {
				New-TestResult -Server $computerName -Type Group -Issue "In the source domain, a group with the name '<NetBIOSName>`$`$`$' must exist (its exact path matters not, it needs no members or memberships, it just needs to exist)."
			}
		}

		# Domain Admins
		if ($Credential.UserName -match '@') { $accountName, $domainName = $Credential.UserName -split '@' }
		elseif ($Credential.UserName -match '\\') { $domainName, $accountName = $Credential.UserName -split '\\' }
		else {
			New-TestResult -Server $computerName -Type Account -Issue "Failed to resolve user domain for $($Credential.UserName)"
			return
		}
		if ($domain.NetBiosName -ne $domainName -and $domain.DnsRoot -ne $domainName) {
			New-TestResult -Server $computerName -Type Account -Issue "User must be a direct member of Domain Admins, however $($Credential.UserName) is not a member of $($domain.DnsRoot) domain. Resolved domain: $($domainName)"
			return
		}
		$group = Get-LdapObject @adParam -LdapFilter "(&(objectCategory=group)(objectSID=$($domain.DomainSID)-512))" -Property DistinguishedName
		$groupMember = Get-LdapObject @adParam -LdapFilter "(&(memberOf=$($group.DistinguishedName))(samAccountName=$accountName))"
		if (-not $groupMember) {
			New-TestResult -Server $computerName -Type Account -Issue "User must be a direct member of Domain Admins, however $($Credential.UserName) is not a member. Nested group memberships do not count. Equivalent permissions are not sufficient."
			return
		}
	}
}