function Get-JdbcUrl {
    $confFile = Get-Content "./flyway.conf"
    $jdbcUrlRow = $confFile | Where-Object {$_ -like "*flyway.url=jdbc:sqlserver://*"}
    $jdbcUrl = (($jdbcUrlRow.Replace("flyway.url=","")).Trim()).Replace('"',"")

    return $jdbcUrl
}

function Get-SideCarJdbcUrl {
    $jdbcUrl = ""
    $confFile = Get-Content "./flyway.conf"
    $jdbcUrlRow = $confFile | Where-Object {$_ -like "flywaySideCarUrl=jdbc:sqlserver://*"}
    if ($jdbcUrlRow) {
        $jdbcUrl = (($jdbcUrlRow.Replace("flywaySideCarUrl=","")).Trim()).Replace('"',"")
    }
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

function Test-SideCarFlywaySchemaHistoryTableExists {
    param (
        [Parameter(Mandatory=$true)]$serverInstance,
        [Parameter(Mandatory=$true)]$sideCarDatabase,
        [Parameter(Mandatory=$true)]$deploymentDatabase
    )
    $flywaySchemaHistoryTable = Get-DbaDbTable -SqlInstance $serverInstance -Database $sideCarDatabase -Table flyway_schema_history_$deploymentDatabase
    if ($flywaySchemaHistoryTable){
        return $true
    }
    return $false
}

function New-SideCarFlywaySchemaHistoryTable {
    param (
        [Parameter(Mandatory=$true)]$serverInstance,
        [Parameter(Mandatory=$true)]$sideCarDatabase,
        [Parameter(Mandatory=$true)]$deploymentDatabase
    )

    $createSideCarFshTableSql = @"
    /****** Object:  Table [dbo].[flyway_schema_history_$deploymentDatabase]    Script Date: 2/23/2023 12:25:13 PM ******/
    SET ANSI_NULLS ON
    GO
    
    SET QUOTED_IDENTIFIER ON
    GO
    
    CREATE TABLE [dbo].[flyway_schema_history_$deploymentDatabase](
        [installed_rank] [int] NOT NULL,
        [version] [nvarchar](50) NULL,
        [description] [nvarchar](200) NULL,
        [type] [nvarchar](20) NOT NULL,
        [script] [nvarchar](1000) NOT NULL,
        [checksum] [int] NULL,
        [installed_by] [nvarchar](100) NOT NULL,
        [installed_on] [datetime] NOT NULL,
        [execution_time] [int] NOT NULL,
        [success] [bit] NOT NULL,
     CONSTRAINT [flyway_schema_history_${deploymentDatabase}_pk] PRIMARY KEY CLUSTERED 
    (
        [installed_rank] ASC
    )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
    ) ON [PRIMARY]
    GO
    
    ALTER TABLE [dbo].[flyway_schema_history_$deploymentDatabase] ADD  DEFAULT (getdate()) FOR [installed_on]
    GO
"@
    Invoke-DbaQuery -SqlInstance $serverInstance -database $sideCarDatabase -Query $createSideCarFshTableSql
}

function Test-FlywaySchemaHistoryViewExists {
    param (
        [Parameter(Mandatory=$true)]$serverInstance,
        [Parameter(Mandatory=$true)]$database
    )
    $flywaySchemaHistoryView = Get-DbaDbView -SqlInstance $serverInstance -Database $database -View flyway_schema_history
    if ($flywaySchemaHistoryView){
        return $true
    }
    return $false
}

function New-FlywaySchemaHistoryView {
    param (
        [Parameter(Mandatory=$true)]$serverInstance,
        [Parameter(Mandatory=$true)]$sideCarDatabase,
        [Parameter(Mandatory=$true)]$deploymentDatabase
    )
    $createViewSql = @"
	CREATE VIEW [dbo].[flyway_schema_history]
	AS 
	SELECT * FROM $sideCarDatabase.dbo.flyway_schema_history_$deploymentDatabase
"@
    Invoke-DbaQuery -SqlInstance $serverInstance -database $deploymentDatabase -Query $createViewSql
}
