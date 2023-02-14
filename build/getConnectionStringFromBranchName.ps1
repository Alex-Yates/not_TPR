param (
    [Parameter(Mandatory=$true)]$branchName
)

if ($branchName -like "refs/heads/main"){
    Write-Error "This is the main branch. Use the Jenkins secret instead!"
}
elseif ($branchName -like "qa/*.*"){
    $serverAndDb = $branchName.Split('/')[1]
    $server = $serverAndDb.Split('.')[0]
    $database = $serverAndDb.Split('.')[1]
}
else {

    Write-Output "This script expects a branch in one of the following formats:"
    Write-Output "- refs/heads/main"
    Write-Output "- qa/server.database"
    Write-Error "branchName $branchName is not in the correct format!"
}

$jdbc = "jdbc:sqlserver://$server;databaseName=$database;encrypt=true;integratedSecurity=true;trustServerCertificate=true"

return $jdbc