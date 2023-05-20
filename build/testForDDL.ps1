param (
    $flywayRoot,
    $licenceKey = ""
)

$ErrorActionPreference = "stop"

$thisScript = $MyInvocation.MyCommand.Path
$buildDir = Split-Path $thisScript -Parent
$gitRoot = Split-Path $buildDir -Parent
$fullyQualifiedFlywayRoot = "$gitRoot\$flywayRoot"
Write-Output "Importing helper functions from $buildDir\functions.psm1."
import-module "$buildDir\functions.psm1"

$targetUrl = Get-JdbcUrl -flywayRoot $flywayRoot

$server = Get-ServerFromJdbcUrl $targetUrl
$instance = Get-InstanceFromJdbcUrl $targetUrl
$database = Get-DatabaseFromJdbcUrl $targetUrl

Write-Output "Importing module dbatools (required)."
import-module dbatools

$timestamp = Get-Date -Format FileDateTime
$tempDatabaseName = "temp_test_db_" + $database + $timestamp

Write-Output "Given parameters:"
Write-Output "  flywayRoot: $flywayRoot"
Write-Output "  timestamp:  $timestamp"

$serverInstance = $server
if ($instance -notlike ""){
    $serverInstance = "$server\$instance"
}

$scratchUrl = $targetUrl.replace(";databaseName=$database",";databaseName=$tempDatabaseName")
$dmlUrl = $scratchUrl.replace(";integratedSecurity=true",";integratedSecurity=false;user=dml_user;password=DML_pa55w0rd")

$locations = "filesystem:$gitRoot\$flywayRoot\migrations"
$serverInstance = $server
if ($instance -notlike ""){
    $serverInstance = "$server\$instance"
}

Write-Output "Derived parameters:"
Write-Output "  thisScript:     $thisScript"
Write-Output "  gitRoot:        $gitRoot"
Write-Output "  server:         $server"
Write-Output "  instance:       $instance"
Write-Output "  database:       $database"
Write-Output "  tempDatabaseName: $tempDatabaseName"
Write-Output "  buildDir:       $buildDir"
Write-Output "  locations:      $locations"
Write-Output "  serverInstance: $serverInstance"
Write-Output "  targetUrl:      $targetUrl"
Write-Output "  scratchUrl:     $scratchUrl"
Write-Output "  dmlUrl:         $dmlUrl"
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

# Running flyway info to get FlywaySchemaHistory and pending scripts data
Write-Output "Running flyway info with telemetry off"
$startTime = Get-Date -Format HH:mm:ss.fff
Write-Output "Executing: & flyway info -url=""$targetUrl"" -licenseKey=[omitted] -outputType=""Json"""
Write-output "  Starting at: $startTime"
$flywayInfo = (& flyway info -url="$targetUrl" -locations="$locations" -licenseKey="$licenceKey" -outputType="Json") | ConvertFrom-Json #We should really pull the locations from the conf file instead.
$completionTime = Get-Date -Format HH:mm:ss.fff
Write-output "  Finished at: $completionTime"
Write-Output $flywayInfo.migrations | Format-Table -Property version, description, state, filepath

# Building the scratch database
Write-Output "Creating temp database for DML testing."
Invoke-DbaQuery -SqlInstance $serverInstance -Query $createDatabaseSql

# Creating our DML user
Write-Output "Creating a sql user on the temp database with only DML access."
Invoke-DbaQuery -SqlInstance $serverInstance -Query $createDmlUserSql


# Dropping our scratch database
Write-Output "Deleting temp database."
Invoke-DbaQuery -SqlInstance $serverInstance -Query $dropDatabaseSql
