function Get-JdbcUrl {
    param (
        [Parameter(Mandatory=$true)]$flywayRoot
    )
    $confFile = Get-Content "./$flywayRoot/flyway.conf"
    $jdbcUrlRow = $confFile | Where-Object {$_ -like "*flyway.url=jdbc:sqlserver://*"}
    $jdbcUrl = (($jdbcUrlRow.Replace("flyway.url=","")).Trim()).Replace('"',"")

    return $jdbcUrl
}

function Get-ServerFromJdbcUrl {
    param (
        [Parameter(Mandatory=$true)]$url
    )
    $server = ($url.Split(';'))[0].Replace("jdbc:sqlserver://","")
    return $server
}

function Get-InstanceFromJdbcUrl {
    param (
        [Parameter(Mandatory=$true)]$url
    )
    $instance = "MSSQLSERVER"
    if ($url -like "*;instanceName=*"){
        $elements = $url.Split(';')
        $instanceElement = $elements | Where-Object {$_ -like "instanceName=*"}
        $instance = ($instanceElement.Split('='))[1]
    }
    return $instance
}

function Get-DatabaseFromJdbcUrl {
    param (
        [Parameter(Mandatory=$true)]$url
    )
    $elements = $url.Split(';')
    $databaseElement = $elements | Where-Object {$_ -like "databaseName=*"}
    $databaseName = ($databaseElement.Split('='))[1]
    return $databaseName
}


function Test-SpGenerateMergeExists {
    param (
        [Parameter(Mandatory=$true)]$serverInstance
    )
    $spGenerateMerge = Get-DbaDbStoredProcedure -SqlInstance $serverInstance -Database master -Name sp_generate_merge
    if ($spGenerateMerge){
        return $true
    }
    return $false
}

function New-SpGenerateMerge {
    param (
        [Parameter(Mandatory=$true)]$serverInstance,
        [Parameter(Mandatory=$true)]$buildDir
    )
    Invoke-DbaQuery -SqlInstance $serverInstance -File "$buildDir\sp_generate_merge.sql"
}

function Test-FlywaySchemaHistoryTableExists {
    param (
        [Parameter(Mandatory=$true)]$serverInstance,
        [Parameter(Mandatory=$true)]$database
    )
    $flywaySchemaHistoryTable = Get-DbaDbTable -SqlInstance $serverInstance -Database $database -Table flyway_schema_history
    if ($flywaySchemaHistoryTable){
        return $true
    }
    return $false
}

function New-FlywaySchemaHistoryTable {
    param (
        [Parameter(Mandatory=$true)]$serverInstance,
        [Parameter(Mandatory=$true)]$database,
        [Parameter(Mandatory=$true)]$buildDir
    )
    Invoke-DbaQuery -SqlInstance $serverInstance -database $database -File "$buildDir\create_flyway_schema_history_table.sql"
}

function Update-FlywaySchemaHistoryTable {
    param (
        [Parameter(Mandatory=$true)]$serverInstance,
        [Parameter(Mandatory=$true)]$database,
        [Parameter(Mandatory=$true)]$flywayRoot
    )
    $flywaySchemaHistoryDataScript = Get-FlywaySchemaHistoryDataScriptPath -flywayRoot $flywayRoot
    Invoke-DbaQuery -SqlInstance $serverInstance -database $database -File $flywaySchemaHistoryDataScript 
}

function  Get-FlywaySchemaHistoryDataScriptPath {
    param (
        [Parameter(Mandatory=$true)]$flywayRoot
    )
    $FlywaySchemaHistoryDataScriptPath = "$flywayRoot\flyway_schema_history_data.sql"
    return $FlywaySchemaHistoryDataScriptPath
}

function Test-FlywaySchemaHistoryDataScriptExists {
    param (
        [Parameter(Mandatory=$true)]$flywayRoot
    )
    $flywaySchemaHistoryDataScript = Get-FlywaySchemaHistoryDataScriptPath -flywayRoot $flywayRoot
    if (Test-Path $flywaySchemaHistoryDataScript){
        return $true
    }
    return $false
}

function New-FlywaySchemaHistoryDataScript {
    param (
        [Parameter(Mandatory=$true)]$flywayRoot
    )
    $flywaySchemaHistoryDataScript = Get-FlywaySchemaHistoryDataScriptPath -flywayRoot $flywayRoot
    New-Item -Type File -Path $flywaySchemaHistoryDataScript | out-null
}

function Update-FlywaySchemaHistoryDataScript {
    param (
        [Parameter(Mandatory=$true)]$flywaySchemaHistoryData,
        [Parameter(Mandatory=$true)]$flywayRoot
    )
    $flywaySchemaHistoryDataScript = Get-FlywaySchemaHistoryDataScriptPath -flywayRoot $flywayRoot
    $flywaySchemaHistoryData | Set-Content -Path $flywaySchemaHistoryDataScript
}

function Get-FlywaySchemaHistoryData {
    param (
        [Parameter(Mandatory=$true)]$serverInstance,
        [Parameter(Mandatory=$true)]$database
    )

    if (-not (Test-FlywaySchemaHistoryTableExists -serverInstance $serverInstance -database $database)){
        Write-Error "Flyway schema history table does not exist in database $database on server\instance $serverInstance"
    }
    $query = "EXEC $database" + ".dbo.sp_generate_merge 'flyway_schema_history'"
    $rawData = Invoke-DbaQuery -SqlInstance $serverInstance -Query $query

    # $rawData is in an annoying object format. Converting to a simple string.
    $rawDataAsString = $rawData.Column1.toString()

    # The first 7 chars are unnecessary and illegal T-SQL syntax ("<?x ---") 
    $partlyCleanData = $rawDataAsString.subString(7)

    # The last 2 chars are also unnecessary and illegal T-SQL syntax  ("?>")
    $cleanDataWithAnnoyingWhitespace = $partlyCleanData.Substring(0,$partlyCleanData.Length-2) 

    # The script is fine now, but there's still some annoying whitespace at either end. Let's remove it.
    $cleanData = $cleanDataWithAnnoyingWhitespace.Trim()

    return $cleanData
}
