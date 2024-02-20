# Managing relative paths to all the necessary files is a pain
$thisScript = $MyInvocation.MyCommand.Path
$buildDir = Split-Path $thisScript -Parent
$gitRoot = $getLocation = (Get-Location).Path
$functionsFile = Join-Path -Path $buildDir -ChildPath "functions.psm1"

# Importing some dependencies
Write-Output "Importing functions from: $functionsFile"
import-module $functionsFile
Write-Output "Importing module dbatools. Info: dbatools.io"
import-module dbatools

# Reading target JDBC URLs
$jdbcUrl = Get-JdbcUrl
$sideCarUrl = Get-SideCarJdbcUrl
$server = Get-ServerFromJdbcUrl $jdbcUrl
$instance = Get-InstanceFromJdbcUrl $jdbcUrl
$database = Get-DatabaseFromJdbcUrl $jdbcUrl
$serverInstance = $server
if ($instance -notlike ""){
    $serverInstance = "$server\$instance"
}

if ($sideCarUrl -like ""){
    Write-Output "No sidecar required"
}
else {
    $sideCarServer = Get-ServerFromJdbcUrl $sideCarUrl
    $sideCarInstance = Get-InstanceFromJdbcUrl $sideCarUrl
    $sideCarDatabase = Get-DatabaseFromJdbcUrl $sideCarUrl
    $sideCarServerInstance = "$sideCarServer\$sideCarInstance"
    
    $sideCarReadable = $sideCarServerInstance + "." + $sideCarDatabase + ".dbo.flyway_schema_history_$database"

    Write-Output "Sidecar required: $sideCarReadable"

    $createSideCarDbSql = @"
USE master;
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = '$sideCarDatabase')
BEGIN
    CREATE DATABASE $sideCarDatabase;
END
"@
    Invoke-DbaQuery -SqlInstance $sideCarServerInstance -Query $createSideCarDbSql

    # Ensuring Flyway Schema history table exists on sidecar database
    Write-Output "Verifying flyway_schema_history table exists on $sideCarDatabase on $sideCarServerInstance."
    if (Test-SideCarFlywaySchemaHistoryTableExists -serverInstance $sideCarServerInstance -sideCarDatabase $sideCarDatabase -deploymentDatabase $database){
        Write-Output "  flyway_schema_history DOES exists on $sideCarServerInstance."
    }
    else {
        Write-Output "  flyway_schema_history table DOES NOT exist on $sideCarDatabase on $sideCarServerInstance. Adding it now."
        New-SideCarFlywaySchemaHistoryTable -serverInstance $sideCarServerInstance -sideCarDatabase $sideCarDatabase -deploymentDatabase $database
        if (Test-SideCarFlywaySchemaHistoryTableExists -serverInstance $sideCarServerInstance -sideCarDatabase $sideCarDatabase -deploymentDatabase $database){
            Write-Output "  flyway_schema_history table successfully added to $sideCarDatabase on $sideCarServerInstance."
        }
        else {
            Write-Error "Failed to create flyway_schema_history table to $sideCarDatabase on $sideCarServerInstance!"
        }
    }

    # Ensuring Flyway Schema history table exists on sidecar database
    Write-Output "Verifying flyway_schema_history view exists on $database on $serverInstance."
    if (Test-FlywaySchemaHistoryViewExists -serverInstance $serverInstance -database $database){
        Write-Output "  flyway_schema_history view DOES exists on $serverInstance."
    }
    else {
        Write-Output "  flyway_schema_history view DOES NOT exist on $database on $serverInstance. Adding it now."
        New-FlywaySchemaHistoryView -serverInstance $sideCarServerInstance -sideCarDatabase $sideCarDatabase -deploymentDatabase $database
        if (Test-FlywaySchemaHistoryViewExists -serverInstance $serverInstance -database $database){
            Write-Output "  flyway_schema_history view successfully added to $database on $serverInstance."
        }
        else {
            Write-Error "Failed to create flyway_schema_history table to $database on $serverInstance!"
        }
    }

}