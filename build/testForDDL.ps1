param (
    $server,
    $instance = "",
    $database,
    $flywayRoot,
    $licenceKey = ""
)

$ErrorActionPreference = "stop"
import-module dbatools
$timestamp = Get-Date -Format FileDateTime
$tempDatabaseName = "temp_test_db_" + $database + $timestamp

Write-Output "Given parameters:"
Write-Output "  server:     $server"
Write-Output "  instance:   $instance"
Write-Output "  database:   $database"
Write-Output "  flywayRoot: $flywayRoot"
Write-Output "  timestamp:  $timestamp"

$thisScript = $MyInvocation.MyCommand.Path
$buildDir = Split-Path $thisScript -Parent
$gitRoot = Split-Path $buildDir -Parent
$fullyQualifiedFlywayRoot = "$gitRoot\$flywayRoot"

Write-Output "Importing helper functions from $buildDir\functions.psm1."
import-module "$buildDir\functions.psm1"

$locations = "filesystem:$gitRoot\$flywayRoot\migrations"
$serverInstance = $server
if ($instance -notlike ""){
    $serverInstance = "$server\$instance"
}

$targetUrl = Get-JdbcUrl -server $server -instance $instance -database $database
$scratchUrl = Get-JdbcUrl -server $server -instance $instance -database $tempDatabaseName
$dmlUrl = $scratchUrl.replace(";integratedSecurity=true",";integratedSecurity=false;user=dml_user;password=DML_pa55w0rd")

Write-Output "Derived parameters:"
Write-Output "  thisScript:     $thisScript"
Write-Output "  gitRoot:        $gitRoot"
Write-Output "  buildDir:       $buildDir"
Write-Output "  locations:      $locations"
Write-Output "  serverInstance: $serverInstance"
Write-Output "  targetUrl:      $targetUrl"
Write-Output "  scratchUrl:     $scratchUrl"
Write-Output "  scratchUrl:     $dmlUrl"
Write-Output "  fullyQualifiedFlywayRoot: $fullyQualifiedFlywayRoot"
Write-Output "  flywayHistoryDataScript:  $flywayHistoryDataScript"

$getHistorySql = @"
USE $database;
SELECT * FROM dbo.flyway_schema_history
"@

$createDatabaseSql = @"
CREATE DATABASE $tempDatabaseName
"@

$createDmlUserSql = @"
USE $tempDatabaseName;
IF NOT EXISTS (SELECT * FROM sys.syslogins WHERE name = 'dml_user')
BEGIN
    CREATE LOGIN dml_user WITH PASSWORD = 'My_password';
END

CREATE USER dml_user FOR LOGIN dml_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO dml_user;
"@

$dropDatabaseSql = @"
USE master;
DROP DATABASE $tempDatabaseName;
"@

# Getting the FlywaySchemaHistory data
Write-Output "Getting flyway_schema_history data."
$fshData = Invoke-DbaQuery -SqlInstance $serverInstance -Query $getHistorySql
$fshData | Format-Table


# Building the scratch database
Write-Output "Creating temp database for DML testing."
Invoke-DbaQuery -SqlInstance $serverInstance -Query $createDatabaseSql

# Creating our DML user
Write-Output "Creating a sql user on the temp database with only DML access."
Invoke-DbaQuery -SqlInstance $serverInstance -Query $createDmlUserSql


# Dropping our scratch database
Write-Output "Deleting temp database."
Invoke-DbaQuery -SqlInstance $serverInstance -Query $dropDatabaseSql
