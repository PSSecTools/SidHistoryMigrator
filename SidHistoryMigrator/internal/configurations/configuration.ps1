<#
This is an example configuration file

By default, it is enough to have a single one of them,
however if you have enough configuration settings to justify having multiple copies of it,
feel totally free to split them into multiple files.
#>

<#
# Example Configuration
Set-PSFConfig -Module 'SidHistoryMigrator' -Name 'Example.Setting' -Value 10 -Initialize -Validation 'integer' -Handler { } -Description "Example configuration setting. Your module can then use the setting using 'Get-PSFConfigValue'"
#>

Set-PSFConfig -Module 'SidHistoryMigrator' -Name 'Import.DoDotSource' -Value $false -Initialize -Validation 'bool' -Description "Whether the module files should be dotsourced on import. By default, the files of this module are read as string value and invoked, which is faster but worse on debugging."
Set-PSFConfig -Module 'SidHistoryMigrator' -Name 'Import.IndividualFiles' -Value $false -Initialize -Validation 'bool' -Description "Whether the module files should be imported individually. During the module build, all module code is compiled into few files, which are imported instead by default. Loading the compiled versions is faster, using the individual files is easier for debugging and testing out adjustments."

$configRoot = Join-Path -Path (Get-PSFPath -Name AppData) -ChildPath 'PowerShell/SidHistoryMigrator'
Set-PSFConfig -Module SidHistoryMigrator -Name 'Path.ConfigRoot' -Value $configRoot -Initialize -Validation string -Description 'Path where the module tracks its operations.'
Set-PSFConfig -Module SidHistoryMigrator -Name 'Path.LoggingRoot' -Value (Join-Path (Get-PSFConfigValue -FullName 'SidHistoryMigrator.Path.ConfigRoot') 'logs') -Initialize -Validation string -Description 'Path where the module logs the changes it performs.'
Set-PSFConfig -Module SidHistoryMigrator -Name 'Path.TaskPath' -Value '' -Initialize -Validation string -Description 'Path to the file that contains the config file, mapping which users for which task should be migrated.'