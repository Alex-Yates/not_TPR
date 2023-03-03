param (
    $server = "localhost",
    $instance = "",
    $database = "not_TPR_prod",
    $flywayRoot = "not_TPR_prod",
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

<#
# By default, Jenkins does some weird stuff with local branches which breaks commits and pushes back to git.
# We want to ensure we have a traditional git checkout of the required branch to make sure the .\update_fsh_data.ps1 script will work.
Write-Output "Initial git status is:"
git status
Write-Output "Checkout out git branch: $branch"
git checkout $branch
Write-Output "Git pull to ensure we are up to date"
git pull
Write-Output "New git status is:"
git status
#>

Write-Output "Verifying sp_generate_merge exists in master database on $serverInstance."
if (Test-SpGenerateMergeExists -serverInstance $serverInstance){
    Write-Output "  sp_generate_merge DOES exists in master database on $serverInstance."
}
else {
    Write-Output "  sp_generate_merge DOES NOT exist in master database on $serverInstance. Adding it now."
    New-SpGenerateMerge -serverInstance $serverInstance -buildDir $buildDir
    if (Test-SpGenerateMergeExists -serverInstance $serverInstance){
        Write-Output "  sp_generate_merge successfully created in master database on $serverInstance."
    }
    else {
        Write-Error "Failed to create sp_generate_merge in master database on $serverInstance!"
    }
}

Write-Output "Verifying flyway schema history data script exists at $flywayHistoryDataScript."
if (Test-FlywaySchemaHistoryDataScriptExists -flywayRoot $fullyQualifiedFlywayRoot){
    Write-Output "  flyway schema history data script DOES exists at $flywayHistoryDataScript."
}
else {
    Write-Output "  flyway schema history data script DOES NOT exist on $database on $serverInstance. Adding it now."
    New-FlywaySchemaHistoryDataScript -flywayRoot $fullyQualifiedFlywayRoot
    if (Test-FlywaySchemaHistoryDataScriptExists -flywayRoot $fullyQualifiedFlywayRoot){
        Write-Output "  flyway schema history data script successfully added  at $flywayHistoryDataScript."
    }
    else {
        Write-Error "Failed to create flyway schema history data script at $flywayHistoryDataScript."
    }
} 

Write-Output "Verifying flyway_schema_history table exists on $database on $serverInstance."
if (Test-FlywaySchemaHistoryTableExists -serverInstance $serverInstance -database $database){
    Write-Output "  flyway_schema_history DOES exists on $serverInstance."
}
else {
    Write-Output "  flyway_schema_history table DOES NOT exist on $database on $serverInstance. Adding it now."
    New-FlywaySchemaHistoryTable -serverInstance $serverInstance -database $database -buildDir $buildDir
    Write-Output "  Populating flyway_schema_history table with data from $flywayHistoryDataScript."
    Update-FlywaySchemaHistoryTable -serverInstance $serverInstance -database $database -flywayRoot $fullyQualifiedFlywayRoot
    if (Test-FlywaySchemaHistoryTableExists -serverInstance $serverInstance -database $database){
        Write-Output "  flyway_schema_history table successfully added to $database on $serverInstance."
    }
    else {
        Write-Error "Failed to create flyway_schema_history table to $database on $serverInstance!"
    }
}