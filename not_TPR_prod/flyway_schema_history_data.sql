USE [not_tpr_prod]
GO

--MERGE generated by 'sp_generate_merge' stored procedure
--Originally by Vyas (http://vyaskn.tripod.com/code): sp_generate_inserts (build 22)
--Adapted for SQL Server 2008+ by Daniel Nolan (https://twitter.com/dnlnln)

SET NOCOUNT ON

DECLARE @mergeOutput TABLE ( [DMLAction] VARCHAR(6) );
MERGE INTO [flyway_schema_history] AS [Target]
USING (VALUES
  (1,N'001.0.20230213105117',N'initial create of DB objects',N'SQL_BASELINE',N'B001_0_20230213105117__initial create of DB objects.sql',1872819769,N'MercuryPoC\student','2023-02-23T17:15:36.160',23,1)
 ,(2,N'002.0.20230214133913',N'MAIN - Create new table on main',N'SQL',N'V002_0_20230214133913__MAIN - Create new table on main.sql',1582727627,N'MercuryPoC\student','2023-02-23T17:15:36.250',18,1)
 ,(3,N'002.1.20230214133913',N'QA4 - Create new table on qa4',N'SQL',N'V002_1_20230214133913__QA4 - Create new table on qa4.sql',-256190183,N'MercuryPoC\student','2023-02-23T17:15:36.323',7,1)
 ,(4,N'003.0.20230214211800',N'MAIN - Create new table on main',N'SQL',N'V003_0_20230214211800__MAIN - Create new table on main.sql',1115767703,N'MercuryPoC\student','2023-02-23T17:15:36.417',8,1)
 ,(5,N'004.0.20230214211800',N'MAIN - THATS NUMBERWANG',N'SQL',N'V004_0_20230214211800__MAIN - THATS NUMBERWANG.sql',1017732337,N'MercuryPoC\student','2023-03-02T13:04:41.167',18,1)
) AS [Source] ([installed_rank],[version],[description],[type],[script],[checksum],[installed_by],[installed_on],[execution_time],[success])
ON ([Target].[installed_rank] = [Source].[installed_rank])
WHEN MATCHED AND (
	NULLIF([Source].[version], [Target].[version]) IS NOT NULL OR NULLIF([Target].[version], [Source].[version]) IS NOT NULL OR 
	NULLIF([Source].[description], [Target].[description]) IS NOT NULL OR NULLIF([Target].[description], [Source].[description]) IS NOT NULL OR 
	NULLIF([Source].[type], [Target].[type]) IS NOT NULL OR NULLIF([Target].[type], [Source].[type]) IS NOT NULL OR 
	NULLIF([Source].[script], [Target].[script]) IS NOT NULL OR NULLIF([Target].[script], [Source].[script]) IS NOT NULL OR 
	NULLIF([Source].[checksum], [Target].[checksum]) IS NOT NULL OR NULLIF([Target].[checksum], [Source].[checksum]) IS NOT NULL OR 
	NULLIF([Source].[installed_by], [Target].[installed_by]) IS NOT NULL OR NULLIF([Target].[installed_by], [Source].[installed_by]) IS NOT NULL OR 
	NULLIF([Source].[installed_on], [Target].[installed_on]) IS NOT NULL OR NULLIF([Target].[installed_on], [Source].[installed_on]) IS NOT NULL OR 
	NULLIF([Source].[execution_time], [Target].[execution_time]) IS NOT NULL OR NULLIF([Target].[execution_time], [Source].[execution_time]) IS NOT NULL OR 
	NULLIF([Source].[success], [Target].[success]) IS NOT NULL OR NULLIF([Target].[success], [Source].[success]) IS NOT NULL) THEN
 UPDATE SET
  [Target].[version] = [Source].[version], 
  [Target].[description] = [Source].[description], 
  [Target].[type] = [Source].[type], 
  [Target].[script] = [Source].[script], 
  [Target].[checksum] = [Source].[checksum], 
  [Target].[installed_by] = [Source].[installed_by], 
  [Target].[installed_on] = [Source].[installed_on], 
  [Target].[execution_time] = [Source].[execution_time], 
  [Target].[success] = [Source].[success]
WHEN NOT MATCHED BY TARGET THEN
 INSERT([installed_rank],[version],[description],[type],[script],[checksum],[installed_by],[installed_on],[execution_time],[success])
 VALUES([Source].[installed_rank],[Source].[version],[Source].[description],[Source].[type],[Source].[script],[Source].[checksum],[Source].[installed_by],[Source].[installed_on],[Source].[execution_time],[Source].[success])
WHEN NOT MATCHED BY SOURCE THEN 
 DELETE
OUTPUT $action INTO @mergeOutput;

DECLARE @mergeError int
 , @mergeCount int, @mergeCountIns int, @mergeCountUpd int, @mergeCountDel int
SELECT @mergeError = @@ERROR
SELECT @mergeCount = COUNT(1), @mergeCountIns = SUM(IIF([DMLAction] = 'INSERT', 1, 0)), @mergeCountUpd = SUM(IIF([DMLAction] = 'UPDATE', 1, 0)), @mergeCountDel = SUM (IIF([DMLAction] = 'DELETE', 1, 0)) FROM @mergeOutput
IF @mergeError != 0
 BEGIN
 PRINT 'ERROR OCCURRED IN MERGE FOR [flyway_schema_history]. Rows affected: ' + CAST(@mergeCount AS VARCHAR(100)); -- SQL should always return zero rows affected
 END
ELSE
 BEGIN
 PRINT '[flyway_schema_history] rows affected by MERGE: ' + CAST(COALESCE(@mergeCount,0) AS VARCHAR(100)) + ' (Inserted: ' + CAST(COALESCE(@mergeCountIns,0) AS VARCHAR(100)) + '; Updated: ' + CAST(COALESCE(@mergeCountUpd,0) AS VARCHAR(100)) + '; Deleted: ' + CAST(COALESCE(@mergeCountDel,0) AS VARCHAR(100)) + ')' ;
 END
GO


SET NOCOUNT OFF
GO