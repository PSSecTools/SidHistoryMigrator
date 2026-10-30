function New-SHTask {
	<#
	.SYNOPSIS
		Saves a migration task and its source and destination credentials.

	.DESCRIPTION
		Stores a task definition in the Tasks directory beneath
		SidHistoryMigrator.Path.ConfigRoot. Saves credentials separately using From
		and To as their names. An existing task with the same name is overwritten.
		Creating a task does not execute it or create its LDAP search scopes.

	.PARAMETER Name
		The task name, validated by PSFramework's SafeName rule. The same name must
		identify the task's entry in the migration scope configuration file.

	.PARAMETER Description
		An optional description stored with the task definition.

	.PARAMETER From
		The source domain or domain controller. Also used as the stored source
		credential name. Use the same value consistently across task definitions.

	.PARAMETER FromCredential
		The source-domain credential to encrypt and store.

	.PARAMETER To
		The destination domain or domain controller. Also used as the stored
		destination credential name.

	.PARAMETER ToCredential
		The destination-domain credential to encrypt and store.

	.PARAMETER FromUserAttribute
		The source user attribute used to match destination users. Defaults to SamAccountName.

	.PARAMETER ToUserAttribute
		The destination user attribute compared with FromUserAttribute. Defaults to SamAccountName.

	.PARAMETER FromGroupAttribute
		The source group attribute used to match destination groups. Defaults to SamAccountName.

	.PARAMETER ToGroupAttribute
		The destination group attribute compared with FromGroupAttribute. Defaults to SamAccountName.

	.PARAMETER AllowAdminCount
		Includes source principals whose AdminCount is greater than zero. Such
		principals are skipped by default; enabling this can include privileged accounts.

	.PARAMETER TestRun
		Saves the task in test mode. Execution still authenticates, searches directories,
		and writes logs, but records WouldMigrate instead of copying SID history.

	.INPUTS
		None. Parameters do not accept pipeline input.

	.OUTPUTS
		None. Use Get-SHTask to retrieve the saved definition.

	.EXAMPLE
		PS C:\> $sourceCredential = Get-Credential -Message 'Source domain'
		PS C:\> $targetCredential = Get-Credential -Message 'Destination domain'
		PS C:\> New-SHTask -Name 'Pilot' -From 'source.contoso.com' -FromCredential $sourceCredential -To 'target.contoso.com' -ToCredential $targetCredential -TestRun

		Saves a test-mode task using SamAccountName to match both users and groups.
		Add a Pilot entry with Scopes to the migration configuration before execution.

	.NOTES
		Requires the encryption certificate provisioned by Install-SHMigrator.
		Credentials are shared by From and To values, not task name. Saving credentials
		can therefore affect other tasks. This command does not support WhatIf.

	.LINK
		Get-SHTask

	.LINK
		Invoke-SHMigration

	.LINK
		about_SidHistoryMigrator
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[PsfValidateScript('PSFramework.Validate.SafeName', ErrorString = 'PSFramework.Validate.SafeName')]
		[string]
		$Name,

		[string]
		$Description,
		
		[Parameter(Mandatory = $true)]
		[string]
		$From,
		
		[Parameter(Mandatory = $true)]
		[PSCredential]
		$FromCredential,
		
		[Parameter(Mandatory = $true)]
		[string]
		$To,
		
		[Parameter(Mandatory = $true)]
		[PSCredential]
		$ToCredential,

		[string]
		$FromUserAttribute = 'SamAccountName',

		[string]
		$ToUserAttribute = 'SamAccountName',
		
		[string]
		$FromGroupAttribute = 'SamAccountName',
		
		[string]
		$ToGroupAttribute = 'SamAccountName',

		[switch]
		$AllowAdminCount,

		[Switch]
		$TestRun
	)
	begin {
		$taskPath = Join-Path -Path (Get-PSFConfigValue -FullName 'SidHistoryMigrator.Path.ConfigRoot') -ChildPath Tasks
		if (-not (Test-Path -LiteralPath $taskPath)) {
			$null = New-Item -Path $taskPath -ItemType Directory -Force
		}
	}
	process {
		$config = [PSCustomObject]@{
			PSTypeName         = 'SidHistoryMigrator.Task'
			Name               = $Name
			Description        = $Description
			From               = $From
			To                 = $To
			FromUserAttribute  = $FromUserAttribute
			ToUserAttribute    = $ToUserAttribute
			FromGroupAttribute = $FromGroupAttribute
			ToGroupAttribute   = $ToGroupAttribute
			AllowAdminCount    = $AllowAdminCount.ToBool()
			TestRun            = $TestRun.ToBool()
		}
		$filename = "$([convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Name)).Trim('=')).clidat"
		$exportPath = Join-Path -Path $taskPath -ChildPath $filename
		$config | Export-PSFClixml -Path $exportPath

		Export-SHCredential -Name $From -Credential $FromCredential
		Export-SHCredential -Name $To -Credential $ToCredential
	}
}