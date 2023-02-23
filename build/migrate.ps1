param (
    $server = "localhost",
    $instance = "",
    $database = "not_TPR_prod",
    $flywayRoot = "..\not_TPR",
    $licenceKey = "FL01644E76D408329657EA27CB2085B6BCAFDDA682CB941A1EF96FCAD9BDF9AC62748D8393169657BA1B81F937AE62DF536B7F274DAE78ED21702307A5FD6A4E450A818CCE91889964A3F2B496882A5F279775BB9629209A89E6FDAAC782C1187DB1655AC2DD384FCF2860DDD9B03F018F4CB7F79522F973C0C7ECB7BD9727C01F49781344BB1CB14838D5295EEF0A7870E5FAD2C18467A987E2BA0F659087F844E27FC2C47DFC3609EC12D8F2FB5C4FC594CE7E4812AD338A1619FD27CD5921DA51231E976FA48C47D2D3638FC74D86E25268BF2986B14AC7483F44D3C4515F756F78C655CA5BE16001B20FBD0139DE76A94259B4D2EE62DCA17D720904C2AF3970" # this is only a trial key
)

$ErrorActionPreference = "stop"



Write-Output "Importing required modules/functions."
import-module .\functions.psm1
import-module dbatools

$locations = "filesystem:$flywayRoot\migrations"
$serverInstance = $server
if ($instance -notlike ""){
    $serverInstance = "$server\$instance"
}
$flywayHistoryDataScript = Get-FlywaySchemaHistoryDataScriptPath -FlywayRoot $flywayRoot

Write-Output "Verifying sp_generate_merge exists in master database on $serverInstance."
if (Test-SpGenerateMergeExists -serverInstance $serverInstance){
    Write-Output "  sp_generate_merge DOES exists in master database on $serverInstance."
}
else {
    Write-Output "  sp_generate_merge DOES NOT exist in master database on $serverInstance. Adding it now."
    New-SpGenerateMerge -serverInstance $serverInstance
    if (Test-SpGenerateMergeExists -serverInstance $serverInstance){
        Write-Output "  sp_generate_merge successfully created in master database on $serverInstance."
    }
    else {
        Write-Error "Failed to create sp_generate_merge in master database on $serverInstance!"
    }
}

Write-Output "Verifying flyway schema history data script exists at $flywayHistoryDataScript."
if (Test-FlywaySchemaHistoryDataScriptExists -flywayRoot $flywayRoot){
    Write-Output "  flyway schema history data script DOES exists at $flywayHistoryDataScript."
}
else {
    Write-Output "  flyway schema history data script DOES NOT exist on $database on $serverInstance. Adding it now."
    New-FlywaySchemaHistoryDataScript -flywayRoot $flywayRoot
    if (Test-FlywaySchemaHistoryDataScriptExists -flywayRoot $flywayRoot){
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
    New-FlywaySchemaHistoryTable -serverInstance $serverInstance -database $database -flywayRoot $flywayRoot
    if (Test-FlywaySchemaHistoryTableExists -serverInstance $serverInstance -database $database){
        Write-Output "  flyway_schema_history table successfully added to $database on $serverInstance."
    }
    else {
        Write-Error "Failed to create flyway_schema_history table to $database on $serverInstance!"
    }
} 

$url = Get-JdbcUrl -server $server -instance $instance -database $database
Write-Output "Running Flyway migrate with the following command:"
Write-Output "  & flyway migrate -url=""$url"" -locations=""$locations"" -licenseKey=""$licenceKey"""
Write-Output ""
& flyway migrate -url=""$url"" -locations=""$locations"" -licenseKey=""$licenceKey""

Write-Output "Reading flyway_schema_history table."
$flywaySchemaHistoryData = Get-FlywaySchemaHistoryData -serverInstance $serverInstance -database $database

Write-Output "Updating flyway schema history data script at $flywayHistoryDataScript."
Update-FlywaySchemaHistoryDataScript -flywaySchemaHistoryData $flywaySchemaHistoryData -flywayRoot $flywayRoot