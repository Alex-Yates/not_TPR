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

Write-Output "Importing module dbatools."
import-module dbatools

$jdbcUrl = Get-JdbcUrl -flywayRoot $flywayRoot

$server = Get-ServerFromJdbcUrl $jdbcUrl
$instance = Get-InstanceFromJdbcUrl $jdbcUrl
$database = Get-DatabaseFromJdbcUrl $jdbcUrl

Write-Output "Given parameters:"
Write-Output "- flywayRoot: $flywayRoot"

$locations = "filesystem:$gitRoot\$flywayRoot\migrations"
$serverInstance = $server
if ($instance -notlike ""){
    $serverInstance = "$server\$instance"
}
$flywayHistoryDataScript = Get-FlywaySchemaHistoryDataScriptPath -FlywayRoot $fullyQualifiedFlywayRoot

Write-Output "Derived parameters:"
Write-Output "- jdbcUrl:        $jdbcUrl"
Write-Output "- server:         $server"
Write-Output "- instance:       $instance"
Write-Output "- database:       $database"
Write-Output "- thisScript:     $thisScript"
Write-Output "- gitRoot:        $gitRoot"
Write-Output "- buildDir:       $buildDir"
Write-Output "- locations:      $locations"
Write-Output "- serverInstance: $serverInstance"
Write-Output "- fullyQualifiedFlywayRoot: $fullyQualifiedFlywayRoot"
Write-Output "- flywayHistoryDataScript:  $flywayHistoryDataScript"
Write-Output ""

Write-output "Security set up for DML verification:"
[Reflection.Assembly]::LoadWithPartialName("System.Web") | out-null
do {
    $randomString = [System.Web.Security.Membership]::GeneratePassword(15,2) # Generates a 15 char password with 2 special chars
} until ($randomString -match '\d') # GeneratePassword does not guarantee a number character. If no numbers, try again.
$dmlLoginPassword = ConvertTo-SecureString $randomString -AsPlainText -Force
Write-Output "- Creating login dmlChecker login on $serverInstance to verify DML Scripts."
New-DbaLogin -SqlInstance $serverInstance -Login dmlChecker -SecurePassword $dmlLoginPassword -Force | out-null # Drops and recreates if already exists
Write-Output "- Creating user dmlChecker user on $serverInstance.$database to verify DML Scripts."
New-DbaDbUser -SqlInstance $serverInstance -Database $database -Login dmlChecker -Force | out-null # Drops and recreates if already exists
Write-Output "- Adding db_datareader and db_datawriter roles to user dmlChecker."
Add-DbaDbRoleMember -SqlInstance $serverInstance -Database $database -Role db_datareader -User dmlChecker -Confirm:$false
Add-DbaDbRoleMember -SqlInstance $serverInstance -Database $database -Role db_datawriter -User dmlChecker -Confirm:$false
Remove-DbaDbRoleMember -SqlInstance $serverInstance -Database $database -Role db_ddladmin -User dmlChecker -Confirm:$false
Write-output ""

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

Write-Output "Running each pending script against the scratch database, with DML scripts executed as a user with only DML permissions."
$dmlUrl = $jdbcUrl.replace(";integratedSecurity=true",";integratedSecurity=true;user=dmlChecker;password=$dmlLoginPassword")
$pendingMigrations | ForEach-Object {
    $thisVersion = $_.version
    $isDmlOnly = $true
    if ($_.filepath -like "*\$flywayRoot\migrations\DDL\*"){
        $isDmlOnly = $false
    }
    $thisUrl = $jdbcUrl
    if ($isDmlOnly){
        $thisUrl = $dmlUrl
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

Write-Output "Removing dmlChecker user and login."
Remove-DbaDbUser -SqlInstance $serverInstance -User dmlChecker | out-null 
Remove-DbaLogin -SqlInstance $serverInstance -Login dmlChecker -Force | out-null 