USE [not_tpr_prod]
GO

--MERGE generated by 'sp_generate_merge' stored procedure
--Originally by Vyas (http://vyaskn.tripod.com/code): sp_generate_inserts (build 22)
--Adapted for SQL Server 2008+ by Daniel Nolan (https://twitter.com/dnlnln)

SET NOCOUNT ON

DECLARE @mergeOutput TABLE ( [DMLAction] VARCHAR(6) );
MERGE INTO [flyway_schema_history] AS [Target]
USING (SELECT [installed_rank],[version],[description],[type],[script],[checksum],[installed_by],[installed_on],[execution_time],[success] FROM [flyway_schema_history] WHERE 1 = 0 -- Empty dataset (source table contained no rows at time of MERGE generation) 
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
