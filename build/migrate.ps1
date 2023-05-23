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

$jdbcUrl = Get-JdbcUrl -flywayRoot $flywayRoot

$server = Get-ServerFromJdbcUrl $jdbcUrl
$instance = Get-InstanceFromJdbcUrl $jdbcUrl
$database = Get-DatabaseFromJdbcUrl $jdbcUrl

Write-Output "Given parameters:"
Write-Output "  flywayRoot: $flywayRoot"

$locations = "filesystem:$gitRoot\$flywayRoot\migrations"
$serverInstance = $server
if ($instance -notlike ""){
    $serverInstance = "$server\$instance"
}
$flywayHistoryDataScript = Get-FlywaySchemaHistoryDataScriptPath -FlywayRoot $fullyQualifiedFlywayRoot

Write-Output "Derived parameters:"
Write-Output "  jdbcUrl:        $jdbcUrl"
Write-Output "  server:         $server"
Write-Output "  instance:       $instance"
Write-Output "  database:       $database"
Write-Output "  thisScript:     $thisScript"
Write-Output "  gitRoot:        $gitRoot"
Write-Output "  buildDir:       $buildDir"
Write-Output "  locations:      $locations"
Write-Output "  serverInstance: $serverInstance"
Write-Output "  fullyQualifiedFlywayRoot: $fullyQualifiedFlywayRoot"
Write-Output "  flywayHistoryDataScript:  $flywayHistoryDataScript"

Write-Output "Running Flyway migrate with the following command:"
Write-Output "  & flyway migrate -url=""$jdbcUrl"" -locations=""$locations"" -licenseKey=""$licenceKey"" -errorOverrides=""S0001:0:I-""" 
Write-Output ""
& flyway migrate -url=""$jdbcUrl"" -locations=""$locations"" -licenseKey=""$licenceKey"" -errorOverrides=""S0001:0:I-""

