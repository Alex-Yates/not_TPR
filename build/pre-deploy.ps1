param (
    $flywayRoot
)

# If any part of the script fails, stop
$ErrorActionPreference = "stop"

Write-Output ""
Write-Output ""
Write-Output "*****"
Write-Output ""
Write-Output "EXECUTING PRE-DEPLOY"
Write-Output "Purpose:"
Write-Output "- Ensure sp_generate_merge exists on target server"
Write-Output "- Ensure flyway_schema_history_data.sql script exists in flyway root in git"
Write-Output "- Ensure flyway_schema_history table exists on target database"
Write-Output ""
Write-Output "-"
Write-Output ""

# Managing relative paths to all the necessary files is a pain
$thisScript = $MyInvocation.MyCommand.Path
$buildDir = Split-Path $thisScript -Parent
$gitRoot = $getLocation = (Get-Location).Path
$fullyQualifiedFlywayRoot = Join-Path -Path $gitRoot -ChildPath $flywayRoot
$functionsFile = Join-Path -Path $buildDir -ChildPath "functions.psm1"

# Logging a bunch of parameters for convenience/troubleshooting
Write-Output "Given parameters:"
Write-Output "- flywayRoot: $flywayRoot"
Write-Output "Derived parameters:"
Write-Output "- thisScript:               $thisScript"
Write-Output "- buildDir:                 $buildDir"
Write-Output "- gitRoot:                  $gitRoot"
Write-Output "- functionsFile:            $functionsFile"
Write-Output "- fullyQualifiedFlywayRoot: $fullyQualifiedFlywayRoot"
Write-Output ""

# Importing some dependencies
Write-Output "Importing functions from: $functionsFile"
import-module $functionsFile
Write-Output "Importing module dbatools. Info: dbatools.io"
import-module dbatools
Write-Output ""

# Using a few functions from $buildDir\functions.psm1 to grab some required info from the flyway.conf file
Write-Output "Using imported functions to read Flyway.conf file and interpret target SQL Server deploy info."
$flywayHistoryDataScript = Get-FlywaySchemaHistoryDataScriptPath -FlywayRoot $fullyQualifiedFlywayRoot
$jdbcUrl = Get-JdbcUrl -flywayRoot $flywayRoot
$server = Get-ServerFromJdbcUrl $jdbcUrl
$instance = Get-InstanceFromJdbcUrl $jdbcUrl
$database = Get-DatabaseFromJdbcUrl $jdbcUrl
$serverInstance = $server
if ($instance -notlike ""){
    $serverInstance = "$server\$instance"
}

# Logging a bunch of parameters for convenience/troubleshooting
Write-Output "Info found:"
Write-Output "- jdbcUrl:        $jdbcUrl"
Write-Output "- server:         $server"
Write-Output "- instance:       $instance"
Write-Output "- database:       $database"
Write-Output "- serverInstance: $serverInstance"
Write-Output "- flywayHistoryDataScript:  $flywayHistoryDataScript"
Write-Output ""

# Ensuring sp_generate_merge exists on target server
Write-Output "Verifying sp_generate_merge exists in master database on $serverInstance."
if (Test-SpGenerateMergeExists -serverInstance $serverInstance){
    Write-Output "  sp_generate_merge DOES exists in master database on $serverInstance."
}
else {
    Write-Output "  sp_generate_merge DOES NOT exist in master database on $serverInstance. Adding it now."
    New-SpGenerateMerge -serverInstance $serverInstance -buildDir $buildDir
    if (Test-SpGenerateMergeExists -serverInstance $serverInstance){
        Write-Output "  sp_generate_merge successfully created in master database on $serverInstance."
    }
    else {
        Write-Error "Failed to create sp_generate_merge in master database on $serverInstance!"
    }
}

# Ensuring flyway schema history script exists in source control
Write-Output "Verifying flyway schema history data script exists at $flywayHistoryDataScript."
if (Test-FlywaySchemaHistoryDataScriptExists -flywayRoot $fullyQualifiedFlywayRoot){
    Write-Output "  flyway schema history data script DOES exists at $flywayHistoryDataScript."
}
else {
    Write-Output "  flyway schema history data script DOES NOT exist on $database on $serverInstance. Adding it now."
    New-FlywaySchemaHistoryDataScript -flywayRoot $fullyQualifiedFlywayRoot
    if (Test-FlywaySchemaHistoryDataScriptExists -flywayRoot $fullyQualifiedFlywayRoot){
        Write-Output "  flyway schema history data script successfully added  at $flywayHistoryDataScript."
    }
    else {
        Write-Error "Failed to create flyway schema history data script at $flywayHistoryDataScript."
    }
} 

# Ensuring Flyway Schema history table exists on target server
Write-Output "Verifying flyway_schema_history table exists on $database on $serverInstance."
if (Test-FlywaySchemaHistoryTableExists -serverInstance $serverInstance -database $database){
    Write-Output "  flyway_schema_history DOES exists on $serverInstance."
}
else {
    Write-Output "  flyway_schema_history table DOES NOT exist on $database on $serverInstance. Adding it now."
    New-FlywaySchemaHistoryTable -serverInstance $serverInstance -database $database -buildDir $buildDir
    Write-Output "  Populating flyway_schema_history table with data from $flywayHistoryDataScript."
    Update-FlywaySchemaHistoryTable -serverInstance $serverInstance -database $database -flywayRoot $fullyQualifiedFlywayRoot
    if (Test-FlywaySchemaHistoryTableExists -serverInstance $serverInstance -database $database){
        Write-Output "  flyway_schema_history table successfully added to $database on $serverInstance."
    }
    else {
        Write-Error "Failed to create flyway_schema_history table to $database on $serverInstance!"
    }
}
