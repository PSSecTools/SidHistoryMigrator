function Write-ActionLog {
	<#
	.SYNOPSIS
		Merges migration results into a task's JSON action log.

	.DESCRIPTION
		Internal helper that creates SidHistoryMigrator.Path.LoggingRoot if needed and
		updates <TaskName>.json. Entries are keyed by source SAM account name. Stores source
		and destination names and distinguished names, timestamp, status, and message.
		Existing entries marked Migrated are preserved instead of overwritten.

	.PARAMETER Data
		A result object or collection with From, To, FromObject, ToObject, Timestamp,
		Status, and Message properties. Null collections and null entries are accepted;
		null entries are ignored. Does not accept pipeline input.

	.PARAMETER TaskName
		The task name used as the JSON file's base name. Callers should supply the
		validated name from the task definition.

	.INPUTS
		None. Pass result objects through Data rather than the pipeline.

	.OUTPUTS
		None. Writes or updates the task's JSON file.

	.EXAMPLE
		PS C:\> Write-ActionLog -Data $results -TaskName 'Pilot'

		Merges worker results into Pilot.json within the module's session state.

	.NOTES
		Not exported. The log is a current-state map, not an append-only audit trail.
		Repeated entries for one source SAM name replace each other until Migrated is
		stored. Concurrent writes to the same task log are not coordinated by this helper.

	.LINK
		Invoke-SHTask
	#>
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