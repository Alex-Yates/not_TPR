param (
    $server = "localhost",
    $instance = "",
    $database = "not_TPR_prod",
    $flywayRoot = "not_TPR_prod",
    $licenceKey = "FL01644E76D408329657EA27CB2085B6BCAFDDA682CB941A1EF96FCAD9BDF9AC62748D8393169657BA1B81F937AE62DF536B7F274DAE78ED21702307A5FD6A4E450A818CCE91889964A3F2B496882A5F279775BB9629209A89E6FDAAC782C1187DB1655AC2DD384FCF2860DDD9B03F018F4CB7F79522F973C0C7ECB7BD9727C01F49781344BB1CB14838D5295EEF0A7870E5FAD2C18467A987E2BA0F659087F844E27FC2C47DFC3609EC12D8F2FB5C4FC594CE7E4812AD338A1619FD27CD5921DA51231E976FA48C47D2D3638FC74D86E25268BF2986B14AC7483F44D3C4515F756F78C655CA5BE16001B20FBD0139DE76A94259B4D2EE62DCA17D720904C2AF3970" # this is only a trial key
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
Write-Output "  & flyway migrate -url=""$url"" -locations=""$locations"" -licenseKey=""$licenceKey"""
Write-Output ""
& flyway migrate -url=""$url"" -locations=""$locations"" -licenseKey=""$licenceKey"" -outputQueryResults=""true""

