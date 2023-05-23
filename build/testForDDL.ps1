param (
    $flywayRoot,
    $licenceKey = ""
)

$ErrorActionPreference = "stop"

# Redgate telemetry slows things down a lot. Disabling it for speed.
& setx REDGATE_DISABLE_TELEMETRY true

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
#$dmlUrl = $dmlUrl.replace(";encrypt=true",";encrypt=false")


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
    CREATE LOGIN dml_user WITH PASSWORD = 'DML_pa55w0rd';
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
Write-Output "Executing: & flyway info -workingDirectory=""$gitRoot/$flywayRoot"" -configFiles=""$gitRoot/$flywayRoot/flyway.conf"" -licenseKey=[omitted] -outputType=""Json"""
$flywayInfo = (& flyway info -workingDirectory="$gitRoot/$flywayRoot" -configFiles="$gitRoot/$flywayRoot/flyway.conf" -licenseKey="$licenceKey" -outputType="Json") | ConvertFrom-Json

$currentVersion = $flywayInfo.schemaVersion
Write-Output "CurrentVersion is: $currentVersion"

$allMigrations = $flywayInfo.migrations
Write-Output "All migrations are:"
Write-Output $allMigrations | Format-Table -Property version, description, state, filepath

$pendingMigrations = $allMigrations | Where-Object {$_.state -like "Pending"}
Write-Output "Pending migrations are:"
Write-Output $pendingMigrations | Format-Table -Property version, description, state, filepath

# Building the scratch database
Write-Output "Creating temp database $tempDatabaseName for DML testing."
Invoke-DbaQuery -SqlInstance $serverInstance -Query $createDatabaseSql

# Creating our DML user
Write-Output "  Creating a sql user on $tempDatabaseName with only DML access."
Invoke-DbaQuery -SqlInstance $serverInstance -Query $createDmlUserSql

Write-Output "  Bringing the scratch database up to date with target."
Write-Output "    Executing: & flyway migrate -workingDirectory=""$gitRoot/$flywayRoot"" -configFiles=""$gitRoot/$flywayRoot/flyway.conf"" -url=""$scratchUrl"" -target=""$currentVersion"" -licenseKey=[omitted]"
& flyway migrate -workingDirectory="$gitRoot/$flywayRoot" -configFiles="$gitRoot/$flywayRoot/flyway.conf" -url="$scratchUrl" -target="$currentVersion" -licenseKey="$licenceKey"

Write-Output "  Running each pending script against the scratch database, with DML scripts executed as a user with only DML permissions."
$pendingMigrations | ForEach-Object {
    $thisVersion = $_.version
    $isDmlOnly = $false
    if ($_.filepath -like "*\$flywayRoot\migrations\DML\*"){
        $isDmlOnly = $true
    }
    $thisUrl = $scratchUrl
    if ($isDmlOnly){
        $thisUrl = $dmlUrl
    }
    Write-Output "    Executing: & flyway migrate -workingDirectory=""$gitRoot/$flywayRoot"" -configFiles=""$gitRoot/$flywayRoot/flyway.conf"" -url=""$thisUrl"" -target=""$thisVersion"" -licenseKey=[omitted]"
    & flyway migrate -workingDirectory="$gitRoot/$flywayRoot" -configFiles="$gitRoot/$flywayRoot/flyway.conf" -url="$thisUrl" -target="$thisVersion" -licenseKey="$licenceKey"
}

# Dropping our scratch database
Write-Output "Deleting $tempDatabaseName."
Invoke-DbaQuery -SqlInstance $serverInstance -Query $dropDatabaseSql
