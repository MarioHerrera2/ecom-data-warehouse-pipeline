USE [ECommDW]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
--Landing Table for monthly sales--
CREATE TABLE [stg].[SalesRaw](
	[SaleDate] [date] NULL,
	[ProductId] [varchar](50) NULL,
	[ProductName] [varchar](200) NULL,
	[Category] [varchar](100) NULL,
	[Brand] [varchar](100) NULL,
	[StoreId] [varchar](50) NULL,
	[StoreName] [varchar](200) NULL,
	[City] [varchar](100) NULL,
	[State] [varchar](50) NULL,
	[Units] [int] NULL,
	[Revenue] [decimal](12, 2) NULL,
	[SourceFile] [nvarchar](260) NULL,
	[LoadDttm] [datetime2](3) NOT NULL
) ON [PRIMARY]
GO

ALTER TABLE [stg].[SalesRaw] ADD  CONSTRAINT [DF_SalesRaw_LoadDttm]  DEFAULT (sysdatetime()) FOR [LoadDttm]
GO


----Store Master loaded from Store_master.csv----

CREATE TABLE [stg].[StoreMaster](
	[StoreId] [varchar](50) NOT NULL,
	[StoreName] [varchar](200) NULL,
	[City] [varchar](100) NULL,
	[State] [varchar](50) NULL,
	[Region] [varchar](50) NULL,
	[LoadDttm] [datetime2](3) NOT NULL
) ON [PRIMARY]
GO

ALTER TABLE [stg].[StoreMaster] ADD  DEFAULT (sysutcdatetime()) FOR [LoadDttm]
GO

------- etl.RunLog -----

CREATE TABLE [etl].[RunLog](
	[RunLogId] [bigint] IDENTITY(1,1) NOT NULL,
	[RunId] [uniqueidentifier] NOT NULL,
	[StepName] [nvarchar](100) NOT NULL,
	[RowCount] [int] NULL,
	[Status] [nvarchar](20) NOT NULL,
	[SourceFile] [nvarchar](260) NULL,
	[LoggedAt] [datetime2](0) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[RunLogId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [etl].[RunLog] ADD  DEFAULT (sysdatetime()) FOR [LoggedAt]
GO

ALTER TABLE [etl].[RunLog]  WITH CHECK ADD  CONSTRAINT [CK_RunLog_Status] CHECK  (([Status]='Failed' OR [Status]='Succeeded' OR [Status]='Started'))
GO

ALTER TABLE [etl].[RunLog] CHECK CONSTRAINT [CK_RunLog_Status]
GO

