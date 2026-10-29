function Copy-SHSidHistory {
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