param (
    $server,
    $instance = "",
    $database,
    $flywayRoot,
    $licenceKey = ""
)

$ErrorActionPreference = "stop"

Write-Output "Given parameters:"
Write-Output "  server:     $server"
Write-Output "  instance:   $instance"
Write-Output "  database:   $database"
Write-Output "  flywayRoot: $flywayRoot"

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
$flywayHistoryDataScript = Get-FlywaySchemaHistoryDataScriptPath -FlywayRoot $fullyQualifiedFlywayRoot

Write-Output "Derived parameters:"
Write-Output "  thisScript:     $thisScript"
Write-Output "  gitRoot:        $gitRoot"
Write-Output "  buildDir:       $buildDir"
Write-Output "  locations:      $locations"
Write-Output "  serverInstance: $serverInstance"
Write-Output "  fullyQualifiedFlywayRoot: $fullyQualifiedFlywayRoot"
Write-Output "  flywayHistoryDataScript:  $flywayHistoryDataScript"

$url = Get-JdbcUrl -server $server -instance $instance -database $database
Write-Output "Running Flyway migrate with the following command:"
Write-Output "  & flyway migrate -url=""$url"" -locations=""$locations"" -licenseKey=""$licenceKey"" -errorOverrides=""S0001:0:I-""" 
Write-Output ""
& flyway migrate -url=""$url"" -locations=""$locations"" -licenseKey=""$licenceKey"" -errorOverrides=""S0001:0:I-""

