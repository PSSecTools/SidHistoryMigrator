function New-SHTask {
	<#
	.SYNOPSIS
		Defines a new migration task along with its source and destination credentials.

	.DESCRIPTION
		Defines a new migration task along with its source and destination credentials.
		A Task defines source and destination domains, along with the credentials to use.
		It also defines how principals from the source domain are matched to those in the destination one.

		In case attributes must be converted to match the destination attribute in an LDAP Filter,
		register an attribute converter through "Register-SHAttributeConverter"

		Tasks are persisted in config files on local disk, under the path specified during Install-SHMigrator.

	.PARAMETER Name
		The name of the task.
		Must be unique or it will overwrite a previous task of the same name.

	.PARAMETER Description
		An optional description stored with the task definition.

	.PARAMETER From
		The source domain or domain controller.
		Also used as the stored source credential name.

	.PARAMETER FromCredential
		The source-domain credential to use for the migration.
		Must be a direct member in the "Domain Admins" group.

	.PARAMETER To
		The destination domain or domain controller.
		Also used as the stored destination credential name.

	.PARAMETER ToCredential
		The destination-domain credential to use for the migration.
		Must be a direct member in the "Domain Admins" group.

	.PARAMETER FromUserAttribute
		The source user attribute used to match destination users.
		Defaults to SamAccountName.

	.PARAMETER ToUserAttribute
		The destination user attribute compared with FromUserAttribute.
		Defaults to SamAccountName.

	.PARAMETER FromGroupAttribute
		The source group attribute used to match destination groups.
		Defaults to SamAccountName.

	.PARAMETER ToGroupAttribute
		The destination group attribute compared with FromGroupAttribute.
		Defaults to SamAccountName.

	.PARAMETER AllowAdminCount
		Include source principals whose AdminCount is greater than zero.
		By default, sensitive principals are skipped during SID History migration.

	.PARAMETER TestRun
		Defines the task in test mode.
		Execution still authenticates, searches directories, and writes logs, but refuses to actually perform the migration.
		The logs show records as "WouldMigrate" instead.

	.EXAMPLE
		PS C:\> New-SHTask -Name 'Pilot' -From 'contoso.com' -FromCredential $sourceCredential -To 'fabrikam.org' -ToCredential $targetCredential -TestRun

		Saves a test-mode migration task from "contoso.com" to "fabrikam.org", using SamAccountName to match both users and groups.
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
		if ($Name -eq 'Logging') {
			Stop-PSFFunction -String 'New-SHTask.Error.InvalidName.Logging' -EnableException $true -Cmdlet $PSCmdlet -Category InvalidArgument
		}
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