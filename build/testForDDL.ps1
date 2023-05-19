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
$url = Get-JdbcUrl -server $server -instance $instance -database $database

Write-Output "Derived parameters:"
Write-Output "  thisScript:     $thisScript"
Write-Output "  gitRoot:        $gitRoot"
Write-Output "  buildDir:       $buildDir"
Write-Output "  locations:      $locations"
Write-Output "  serverInstance: $serverInstance"
Write-Output "  url:  $url"
Write-Output "  fullyQualifiedFlywayRoot: $fullyQualifiedFlywayRoot"
Write-Output "  flywayHistoryDataScript:  $flywayHistoryDataScript"

Write-Output "Running Flyway info to read current state with the following command:"
Write-Output "  & flyway info -url=""$url"" -locations=""$locations"" -licenseKey=""$licenceKey"" -errorOverrides=""S0001:0:I-""" 

$info = & flyway info -url=""$url"" -locations=""$locations"" -licenseKey=""$licenceKey"" -errorOverrides=""S0001:0:I-""
Write-Output ""

Write-Output "Raw output from flyway info is:"
Write-Output $info
Write-Output ""

$infoRows = $info.split([Environment]::NewLine) # Splitting that wall of text into separate rows

Write-Output "Current version is" 
$currentVersionsRow = $infoRows | Where-Object {$_ -like "Schema version: *"} 
$currentVersion = ($currentVersionsRow.Split(':')[1]).trim()
Write-Output $currentVersion

# Readign the column headers and the pending scripts
$pendingScripts = @()
$pendingScripts = $infoRows | Where-Object {$_ -like "*Pending*"}
$columnHeaders = "|Category|Version|Description|Type|Installed On|State|Undoable|"
$headerArray = $columnHeaders -split '\|' -replace '\s+', '' | Where-Object { $_ -ne '' }

# Creating an array of objects for all the scripts in the table
$pendingScriptMetadataAsObjects = $pendingScripts | ForEach-Object {
    $scriptAttributes = $_ -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
    $scriptObject = [PSCustomObject]@{}
    for ($i = 0; $i -lt $headerArray.Count; $i++) {
        $scriptObject | Add-Member -NotePropertyName $headerArray[$i] -NotePropertyValue $scriptAttributes[$i]
    }
    $scriptObject
}

# Adding an attribute to each script to determine whether it's listed as plain DML or not
$pendingScriptMetadataAsObjects = $pendingScriptMetadataAsObjects | ForEach-Object {
    $description = $_.Description
    $isDMLOnly = $description -like '*PLAINDML*'
    $_ | Add-Member -NotePropertyName 'IsDMLOnly' -NotePropertyValue $isDMLOnly -Force
    $_
}

# Outputting the relevent info about which scripts are pending and whether they are listed as plain DLM
Write-Output "Pending script versions:"
$pendingScriptMetadataAsObjects | Select-Object Version, Description, IsDMLOnly | Format-Table -AutoSize

