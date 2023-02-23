function Get-JdbcUrl {
    param (
        [Parameter(Mandatory=$true)]$server,
        [Parameter(Mandatory=$true)]$instance,
        [Parameter(Mandatory=$true)]$database
    )

    $instanceQualifier = ""
    if ($instance -notin @("", "MSSQLSERVER")){
        $instanceQualifier = ";instanceName=$instance"
    }

    $jdbc = "jdbc:sqlserver://$server;databaseName=$database$instanceQualifier;encrypt=true;integratedSecurity=true;trustServerCertificate=true"

    return $jdbc
}
