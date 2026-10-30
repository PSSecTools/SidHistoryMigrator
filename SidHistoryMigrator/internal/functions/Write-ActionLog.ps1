function Write-ActionLog {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[AllowEmptyCollection()]
		[AllowNull()]
		$Data,

		[Parameter(Mandatory = $true)]
		[string]
		$TaskName
	)
	begin {
		$loggingRoot = Get-PSFConfigValue -FullName 'SidHistoryMigrator.Path.LoggingRoot'
		if (-not (Test-Path -LiteralPath $loggingRoot)) {
			$null = New-Item -Path $loggingRoot -ItemType Directory -Force
		}
		$logFile = Join-Path -Path $loggingRoot -ChildPath "$TaskName.json"
	}
	process {
		$config = @{}
		if (Test-Path -Path $logFile) { $config = Import-PSFJson -Path $logFile -AsHashtable }

		foreach ($entry in $Data) {
			# Workers that write directly to queues might lead to null-entries
			if (-not $entry) { continue }
			if ($config[$entry.From].Status -eq 'Migrated') { continue }
			$config[$entry.From] = @{
				FromSAM   = $entry.From
				FromDN    = $entry.FromObject.DistinguishedName
				ToSAM     = $entry.To
				ToDN      = $entry.ToObject.DistinguishedName
				Timestamp = $entry.Timestamp
				Status    = $entry.Status
				Message   = $entry.Message
			}
		}

		$config | Export-PSFJson -Path $logFile -Depth 5
	}
}