function Test-SHDomainController {
	<#
	.SYNOPSIS
		Reports selected domain-controller prerequisites for SID history migration.

	.DESCRIPTION
		Resolves a domain controller, checks Account Management auditing through PowerShell
		remoting, and verifies that the supplied account is a direct member of Domain Admins
		in that domain. For a source domain, also checks for the <NetBIOSName>$$$ group.
		Returns one object per detected issue and does not change domain configuration.

	.PARAMETER Server
		The domain or domain controller to inspect. A recognized writable replica is
		used directly; otherwise, the domain's PDC emulator is selected.

	.PARAMETER Credential
		The credential used for LDAP queries and PowerShell remoting. Use a domain-qualified
		user name (DOMAIN\user or user@domain). Direct Domain Admins membership is checked;
		nested membership or equivalent delegated permissions do not satisfy the check.

	.PARAMETER Type
		Source or Destination. Source additionally requires the special migration group.

	.INPUTS
		None. Parameters do not accept pipeline input.

	.OUTPUTS
		System.Management.Automation.PSCustomObject
		Issue objects with Server, Type (Auditing, Group, or Account), and Issue properties.
		No issue objects are emitted when these checks find no problems.

	.EXAMPLE
		PS C:\> Test-SHDomainController -Server 'source.contoso.com' -Credential (Get-Credential) -Type Source

		Reports source-domain auditing, migration-group, and account-membership issues.

	.EXAMPLE
		PS C:\> Test-SHDomainController -Server 'target.contoso.com' -Credential (Get-Credential) -Type Destination

		Checks the destination domain without requiring the source-only migration group.

	.NOTES
		Requires Windows, auditpol, and PowerShell remoting access to the selected controller.
		The auditing check uses English auditpol category names and output values. These
		checks are not a complete guarantee that DsAddSidHistory will succeed; connectivity,
		security policy, and other environment prerequisites can still prevent migration.

	.LINK
		Copy-SHSidHistory
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
			<#
			.SYNOPSIS
				Creates a domain-controller prerequisite issue record.

			.DESCRIPTION
				Internal helper local to Test-SHDomainController. Packages one failed
				prerequisite check for the calling command's output.

			.PARAMETER Server
				The domain controller on which the issue was detected.

			.PARAMETER Type
				The issue category, such as Auditing, Group, or Account.

			.PARAMETER Issue
				The explanatory message and any suggested remediation.

			.INPUTS
				None. Parameters do not accept pipeline input.

			.OUTPUTS
				System.Management.Automation.PSCustomObject
				An object with Server, Type, and Issue properties.

			.EXAMPLE
				PS C:\> New-TestResult -Server 'dc1.contoso.com' -Type Auditing -Issue 'Auditing is not configured.'

				Creates an issue record within the parent command's scope.
			#>
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