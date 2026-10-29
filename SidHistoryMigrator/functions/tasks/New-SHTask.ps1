function New-SHTask {
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