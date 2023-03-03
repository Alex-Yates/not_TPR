param (
    $server = "localhost",
    $instance = "",
    $database = "not_TPR_prod",
    $flywayRoot = "not_TPR_prod",
    $jobName = "unknown",
    $buildNumber = "unknown",
    $buildUrl = "unknown",
    $branch = "unknown"
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
Write-Output "Importing dbatools (dbatools.io). (Required)."
import-module dbatools

$serverInstance = $server
if ($instance -notlike ""){
    $serverInstance = "$server\$instance"
}
$flywayHistoryDataScript = Get-FlywaySchemaHistoryDataScriptPath -FlywayRoot $fullyQualifiedFlywayRoot

Write-Output "Derived parameters:"
Write-Output "  thisScript:     $thisScript"
Write-Output "  gitRoot:        $gitRoot"
Write-Output "  buildDir:       $buildDir"
Write-Output "  serverInstance: $serverInstance"
Write-Output "  fullyQualifiedFlywayRoot: $fullyQualifiedFlywayRoot"
Write-Output "  flywayHistoryDataScript:  $flywayHistoryDataScript"

Write-Output "Reading flyway_schema_history table."
$flywaySchemaHistoryData = Get-FlywaySchemaHistoryData -serverInstance $serverInstance -database $database

Write-Output "Updating flyway schema history data script at $flywayHistoryDataScript."
Update-FlywaySchemaHistoryDataScript -flywaySchemaHistoryData $flywaySchemaHistoryData -flywayRoot $fullyQualifiedFlywayRoot

Write-Output "Current git status is..."
git status

Write-Output "Staging all changes for commit"
git add .

Write-Output "Current git status now is as follows. (All changes *should* be added):"
git status

Write-Output "Commiting all local changes to local repo."
git commit -m "Jenkins commit. Job name: $jobName. Build number: $buildNumber. Build URL: $buildUrl."

Write-Output "Pushing all local commits to remote branch: $branch"
git push origin HEAD:$branch