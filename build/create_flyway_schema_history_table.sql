CREATE TABLE [dbo].[flyway_schema_history] (
    [installed_rank] INT NOT NULL,
    [version] NVARCHAR(50),
    [description] NVARCHAR(200),
    [type] NVARCHAR(20) NOT NULL,
    [script] NVARCHAR(1000) NOT NULL,
    [checksum] INT,
    [installed_by] NVARCHAR(100) NOT NULL,
    [installed_on] DATETIME NOT NULL DEFAULT GETDATE(),
    [execution_time] INT NOT NULL,
    [success] BIT NOT NULL
);
ALTER TABLE [dbo].[flyway_schema_history] ADD CONSTRAINT [flyway_schema_history_pk] PRIMARY KEY ([installed_rank]);
CREATE INDEX [flyway_schema_history_s_idx] ON [dbo].[flyway_schema_history] ([success]);