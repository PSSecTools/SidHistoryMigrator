function Test-SHDomainController {
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