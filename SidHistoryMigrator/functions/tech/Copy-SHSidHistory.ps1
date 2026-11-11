function Copy-SHSidHistory {
	<#
	.SYNOPSIS
		Copies a source principal's SID history to a destination principal.

	.DESCRIPTION
		Copies a source principal's SID history to a destination principal.	
		Several prerequisites must be met for this to succeed, for details see:
		Get-Help about_SidHistoryMigrator

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
		If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
	
	.PARAMETER Confirm
		If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

	.EXAMPLE
		PS C:\> $source = New-SHSession -Server 'contoso.com' -Credential (Get-Credential)
		PS C:\> $target = New-SHSession -Server 'fabrikam.org' -Credential (Get-Credential)
		PS C:\> try { Copy-SHSidHistory -From $source -To $target -FromIdentity 'alice' -ToIdentity 'alice.new' } finally { $source.Dispose(); $target.Dispose() }

		Authenticates to both domains and copyies alice's SID history to alice.new.
		Disposes both sessions afterward.

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