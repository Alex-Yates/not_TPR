param (
    $flywayRoot,
    $licenceKey = ""
)

# If any part of the script fails, stop
$ErrorActionPreference = "stop"

Write-Output ""
Write-Output ""
Write-Output "*****"
Write-Output ""
Write-Output "EXECUTING MIGRATE"
Write-Output "Purpose:"
Write-Output "- Run pending migrations one at a time"
Write-Output "- DML scripts executed as a temporary DML only user to ensure no accidental DDL statements skip DBA review"
Write-Output ""
Write-Output "-"
Write-Output ""

# Redgate telemetry slows things down a lot. Disabling it for speed.
& setx REDGATE_DISABLE_TELEMETRY true | out-null 

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

Write-Output "Creating a sql login and user on $database with only DML access."
# Generate a random password for the DML user. We don't want any humans using this login!
[Reflection.Assembly]::LoadWithPartialName("System.Web") | out-null
do {
    $randomString = [System.Web.Security.Membership]::GeneratePassword(15,2) # Generates a random 15 char password with 2 special chars
} until ($randomString -match '\d')                                          # GeneratePassword does not guarantee a number character. If no numbers, try again.
$dmlLoginPassword = ConvertTo-SecureString $randomString -AsPlainText -Force # Using a secure string to avoid logging plaintext password in public logs
# A SQL script to create a dmlChecker login/user
$createDmlUserSql = @"
USE $database;
IF NOT EXISTS (SELECT * FROM sys.syslogins WHERE name = 'dmlChecker')
BEGIN
    CREATE LOGIN dmlChecker WITH PASSWORD = '$dmlLoginPassword';
END
CREATE USER dmlChecker FOR LOGIN dmlChecker;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO dmlChecker;
"@
# If login/user already exists, delete, so we can recreate fresh, with known password and expected permissions.
Remove-DbaDbUser -SqlInstance $serverInstance -User dmlChecker | out-null
Remove-DbaLogin -SqlInstance $serverInstance -Login dmlChecker -Force | out-null
# Create login and user, using tsql script above
Invoke-DbaQuery -SqlInstance $serverInstance -Query $createDmlUserSql
Write-Output ""

# Using "flyway info" command to query flyway_schema_history and source code to get a list of pending migrations and infer whether they are listed for DML or DDL.
Write-Output "Running flyway info to discover pending migrations:"
Write-Output "- Executing: "
Write-Output "    & flyway info"
Write-Output "        -workingDirectory=""$gitRoot/$flywayRoot"""
Write-Output "        -configFiles=""$gitRoot/$flywayRoot/flyway.conf"""
Write-Output "        -outputType=""Json"""
Write-Output "        -licenseKey=***"
$flywayInfo = (& flyway info -workingDirectory="$gitRoot/$flywayRoot" -configFiles="$gitRoot/$flywayRoot/flyway.conf" -outputType="Json" -licenseKey="$licenceKey") | ConvertFrom-Json
$currentVersion = $flywayInfo.schemaVersion
Write-Output "- CurrentVersion is: $currentVersion"
$allMigrations = $flywayInfo.migrations
$pendingMigrations = $allMigrations | Where-Object {$_.state -like "Pending"}
Write-Output "- Pending migrations are:"
Write-Output $pendingMigrations | Format-Table -Property version, description, state, filepath
Write-Output ""

# Running flyway migrate one migration at a time, using the default user for DDL, but the DML user, with restricted access, for DML
Write-Output "Running each pending script against the scratch database, with DML scripts executed as a user with only DML permissions."
$dmlUrl = $jdbcUrl.replace(";integratedSecurity=true",";integratedSecurity=false;user=dmlChecker;password=$dmlLoginPassword")
$pendingMigrations | ForEach-Object {
    $thisVersion = $_.version
    $thisDescription = $_.description
    $isDmlOnly = $true
    if ($_.filepath -replace '/', '\' -like "*\migrations\DDL\*"){
        $isDmlOnly = $false
    }
    $thisUrl = $jdbcUrl
    $versionNumberAndDescriptionAsText = "$thisVersion" + ": $thisDescription"
    Write-Output "- Upgrading to $versionNumberAndDescriptionAsText"
    if ($isDmlOnly){
        $thisUrl = $dmlUrl
        Write-Output "  - $thisVersion should NOT contain DDL. Using a DML only login."
    }
    else {
        Write-Output "  - $thisVersion may contain contain DDL. Using default login."
    }
    Write-Output "- Executing: "
    Write-Output "    & flyway migrate"
    Write-Output "        -workingDirectory=""$gitRoot/$flywayRoot"""
    Write-Output "        -configFiles=""$gitRoot/$flywayRoot/flyway.conf"""
    Write-Output "        -url=""$thisUrl"""
    Write-Output "        -target=""$thisVersion"""
    Write-Output "        -licenseKey=***"
    & flyway migrate -workingDirectory="$gitRoot/$flywayRoot" -configFiles="$gitRoot/$flywayRoot/flyway.conf" -url="$thisUrl" -target="$thisVersion" -licenseKey="$licenceKey"
}
Write-Output ""

# Cleaning up the DML only login and user. We don't need them any more.
Write-Output "Removing dmlChecker user and login."
Remove-DbaDbUser -SqlInstance $serverInstance -User dmlChecker | out-null 
Remove-DbaLogin -SqlInstance $serverInstance -Login dmlChecker -Force | out-null 