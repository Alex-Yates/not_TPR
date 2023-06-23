param (
    $flywayRoot,
    $jobName = "unknown",
    $buildNumber = "unknown",
    $buildUrl = "unknown",
    $branch = "unknown"
)

# If any part of the script fails, stop
$ErrorActionPreference = "stop"

Write-Output ""
Write-Output ""
Write-Output "*****"
Write-Output ""
Write-Output "EXECUTING UPDATE_FSH_DATA"
Write-Output "Purpose:"
Write-Output "- Put existing state of fsh table data into source control"
Write-Output "    (This is necessary because sometimes fsh table may be deleted on target database by external processes and we need to preserve the data)"
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


Write-Output "Reading flyway_schema_history table."
$flywaySchemaHistoryData = Get-FlywaySchemaHistoryData -serverInstance $serverInstance -database $database

Write-Output "Updating flyway schema history data script at $flywayHistoryDataScript."
Update-FlywaySchemaHistoryDataScript -flywaySchemaHistoryData $flywaySchemaHistoryData -flywayRoot $fullyQualifiedFlywayRoot

Write-Output "Current git status is..."
git status

Write-Output "Staging all changes for commit"
git add $flywayHistoryDataScript

Write-Output "Current git status now is as follows. (All changes *should* be added):"
git status

Write-Output "Commiting all local changes to local repo."
git commit -m "Jenkins commit. Job name: $jobName. Build number: $buildNumber. Build URL: $buildUrl."

Write-Output "Current git status now is as follows. (All changes *should* be added):"
git status

Write-Output "Pushing all local commits to remote branch: $branch"
git push origin HEAD:$branch
