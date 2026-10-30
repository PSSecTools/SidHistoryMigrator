# This is where the strings go, that are written by
# Write-PSFMessage, Stop-PSFFunction or the PSFramework validation scriptblocks
@{
	'Convert-SHAttribute.Error.ConversionFailed'      = 'Faled to convert {0} from {1} to {2}' # $Value, $FromAttribute, $ToAttribute
	
	'Copy-SidHistory.Error.Warning'                   = "SId History migration may fail if one of several conditions apply:`n- Accounts used are Domain Admins`n- There is a trust between the domain (source must trust destination)`n- In the source domain there is a group named '<DomainNetBIOSName>`$`$`$'`n- Source and Target DC must have the auditing for 'Account Management' enabled for Success and Failure.`nRun 'Test-SHDomainController' to check the configuration of DC and domain." # 
	'Copy-SidHistory.Executing'                       = 'Migrating SID History from {0} (in {2}) to {1} (in {3})' # $FromIdentity, $ToIdentity, $From.Domain, $To.Domain

	'Import-SHCredential.Error.CertificateNotFound'   = 'The certificate needed to decrypt/access the secret {0} was not found: {1}' # $Name, $data.Thumbprint
	'Import-SHCredential.Error.SecretNotFound'        = 'The requested secret was not found: {0}.' # $Name
	
	'Export-SHCredential.Error.NoCertificate'         = 'There is no certificate to protect the secret with. Ensure you have ruzn Install-SHMigrator first!' # 
	
	'Install-SHMigrator.Execute.LoggingRoot'          = 'Configuring the path where the actual per-principal migration-state is logged.' # 
	'Install-SHMigrator.Execute.RegisteringTask'      = 'Registering the scheduled task used to operate the migrator on a schedule' # 
	'Install-SHMigrator.Execute.SecretsCertificate'   = 'Initializing the certificate used to protect credentials with.' # 
	'Install-SHMigrator.Execute.SetConfigRoot'        = 'Configuring the path where the main configuration is stored' # $ConfigPath
	'Install-SHMigrator.Execute.SettingLogging'       = 'Installing Eventlog Logging' # 
	'Install-SHMigrator.Execute.TaskPath'             = 'Configuring the path for the task to {0}' # $TaskPath
	'Install-SHMigrator.TestLogMessage'               = 'Sid History Migration Logging has been configured.' # 
	
	'Invoke-SHMigration.Error.Failed'                 = 'An unexpected error happened during SID history migration!' # 

	'Invoke-SHTask.Error.AuthenticationFailed'        = 'Failed to authenticate to {0}' # $Task.From
	'Invoke-SHTask.Error.Query'                       = 'Error retrieving matching principals for {1} {0} | Filter: {2}' # $principal.SamAccountName, $principal.ObjectCategory, $toFilter
	'Invoke-SHTask.Error.Scope.ErrorRetrieving'       = 'Error searching for principals in source under "{0}" with filter "{1}". Ensure the scope configuration is correct (e.g. the specified path exists)' # $Scope.Path, $ldapFilter
	'Invoke-SHTask.Error.Scope.NoPath'                = 'Invalid scope configuration: No Path (OU) specified!' # 
	'Invoke-SHTask.Executing.TestRun'                 = '[No Action] Would have migrated SID History from {0} to {1}' # $Principal.From, $Principal.To
	'Invoke-SHTask.Scope.Found'                       = 'Found {0} principals in the specified scope (before excluding AdminCount entities)' # @($principals).Count
	'Invoke-SHTask.Scope.Searching'                   = 'Searching for principals under "{0}" with filter "{1}"' # $Scope.Path, $ldapFilter
	'Invoke-SHTask.Task.BadCredential'                = 'Error validating task {0}: Domain Credentials provided for {1} are invalid.' # $Task.Name, $Task.From
	'Invoke-SHTask.Task.Credentials'                  = 'Failed to retrieve credentials for task {0}' # $Task.Name
	'Invoke-SHTask.Task.NoConfig'                     = 'No configuration provided for task {0}. Skipping.' # $Task.Name
	'Invoke-SHTask.Task.Starting'                     = 'Starting to process task {0}' # $Task.Name
	'Invoke-SHTask.Warning.AmbiguousMatch'            = 'Principal {0} with {2} "{1}" resolves to more than one principal: {3}. Refusing to migrate in an ambiguous situation.' # $principal.SamAccountName, $principal.$($fromAttribute[$principal.ObjectCategory]), $toAttribute[$principal.ObjectCategory], ($targetPrincipal.SamAccountName -join ',')
	'Invoke-SHTask.Warning.NoMatch'                   = 'Principal {0} with {2} "{1}" does not resolve to a principal in the destination domain!' # $principal.SamAccountName, $principal.$($fromAttribute[$principal.ObjectCategory]), $toAttribute[$principal.ObjectCategory]

	'Resolve-TaskConfiguration.Error.FailedToLoad'    = 'Failed to load task configuration from {0}' # $effectivePath
	'Resolve-TaskConfiguration.Error.NoPathSpecified' = 'No task configuration specified!' # 
	'Resolve-TaskConfiguration.Error.PathNotFound'    = 'The specified path to the task configuration file was not found: {0}' # $effectivePath
}