param (
    [Parameter(Mandatory=$true)][SecutreString]$licence,
    [Parameter(Mandatory=$true)]$prodSqlConnection
)

$branchName = (& git rev-parse --abbrev-ref HEAD)

if ($branchName -notlike "refs/heads/main"){
    $url = $prodSqlConnection
}

if ($branchName -notlike "refs/heads/main"){
    $url = $prodSqlConnection
}



