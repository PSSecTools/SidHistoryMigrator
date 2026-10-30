function Copy-SHSidHistory {
	<#
	.SYNOPSIS
		Copies a source principal's SID history to a destination principal.

	.DESCRIPTION
		Calls the native DsAddSidHistory API through the module's DirectoryTools class,
		using authenticated sessions for domains in different forests. Adds the source
		principal's SID, and its SID history for native-mode source domains, to an existing
		destination principal; it does not create accounts.
		Native migration failures are reported as terminating errors.

	.PARAMETER From
		An authenticated source-domain DSSession created by New-SHSession.

	.PARAMETER To
		An authenticated destination-domain DSSession created by New-SHSession.

	.PARAMETER FromIdentity
		The source user or group's SAM account name, without a domain prefix.

	.PARAMETER ToIdentity
		The destination user or group's SAM account name, without a domain prefix.
		Defaults to FromIdentity when omitted or empty.

	.PARAMETER WhatIf
		Shows the intended SID history operation without calling the native migration API.

	.PARAMETER Confirm
		Requests confirmation before calling the native migration API.

	.INPUTS
		None. Parameters do not accept pipeline input.

	.OUTPUTS
		None.

	.EXAMPLE
		PS C:\> $source = New-SHSession -Server 'source.contoso.com' -Credential (Get-Credential)
		PS C:\> $target = New-SHSession -Server 'target.contoso.com' -Credential (Get-Credential)
		PS C:\> try { Copy-SHSidHistory -From $source -To $target -FromIdentity 'alice' -ToIdentity 'alice.new' -WhatIf } finally { $source.Dispose(); $target.Dispose() }

		Authenticates to both domains and previews copying alice's SID history to alice.new.
		Disposes both sessions afterward. Remove WhatIf only when ready to perform the write.

	.NOTES
		Requires Windows and the native SID history migration prerequisites in both domains.
		The native API requires the source session to target the source PDC emulator.
		WhatIf suppresses the migration write, not session creation or authentication.
		Test-SHDomainController checks selected prerequisites but is not exhaustive.

	.LINK
		New-SHSession

	.LINK
		Test-SHDomainController

	.LINK
		https://learn.microsoft.com/en-us/windows/win32/api/ntdsapi/nf-ntdsapi-dsaddsidhistoryw
	#>
	[CmdletBinding(SupportsShouldProcess = $true)]
	param (
		[Parameter(Mandatory = $true)]
		[SidHistoryMigrator.DSSession]
		$From,

		[Parameter(Mandatory = $true)]
		[SidHistoryMigrator.DSSession]
		$To,

		[Parameter(Mandatory = $true)]
		[string]
		$FromIdentity,

		[AllowEmptyString()]
		[string]
		$ToIdentity
	)
	if (-not $ToIdentity) { $ToIdentity = $FromIdentity }

	Invoke-PSFProtectedCommand -ActionString 'Copy-SidHistory.Executing' -ActionStringValues $FromIdentity, $ToIdentity, $From.Domain, $To.Domain -Target $FromIdentity -ScriptBlock {
		[SidHistoryMigrator.DirectoryTools]::ImportSIDHistory($From, $To, $FromIdentity, $ToIdentity)
	} -EnableException $true -PSCmdlet $PSCmdlet -ErrorEvent {
		Write-PSFMessage -Level Warning -String 'Copy-SidHistory.Error.Warning' -Once MeetPrerequisites
	}
}