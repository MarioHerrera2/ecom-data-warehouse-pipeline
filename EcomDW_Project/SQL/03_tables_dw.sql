USE [ECommDW]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
-----dw.DimDate Table--------
CREATE TABLE [dw].[DimDate](
	[DateKey] [int] NOT NULL,
	[Date] [date] NOT NULL,
	[Year] [smallint] NOT NULL,
	[Quarter] [tinyint] NOT NULL,
	[Month] [tinyint] NOT NULL,
	[MonthName] [varchar](10) NOT NULL,
	[Day] [tinyint] NOT NULL,
	[DayName] [varchar](10) NOT NULL,
	[IsWeekend] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[DateKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

-----dw.DimProduct------
CREATE TABLE [dw].[DimProduct](
	[ProductKey] [int] IDENTITY(1,1) NOT NULL,
	[ProductNaturalId] [varchar](50) NOT NULL,
	[ProductName] [varchar](200) NULL,
	[Category] [varchar](100) NULL,
	[Brand] [varchar](100) NULL,
	[StartDate] [date] NULL,
	[EndDate] [date] NULL,
PRIMARY KEY CLUSTERED 
(
	[ProductKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[ProductNaturalId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dw].[DimProduct] ADD  DEFAULT (getdate()) FOR [StartDate]
GO

-------dw.DimStore----
CREATE TABLE [dw].[DimStore](
	[StoreKey] [int] IDENTITY(1,1) NOT NULL,
	[StoreNaturalId] [varchar](50) NOT NULL,
	[StoreName] [varchar](200) NULL,
	[City] [varchar](100) NULL,
	[State] [varchar](50) NULL,
	[Region] [varchar](50) NULL,
PRIMARY KEY CLUSTERED 
(
	[StoreKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[StoreNaturalId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

----dw.FactSales-------
CREATE TABLE [dw].[FactSales](
	[FactSalesKey] [bigint] IDENTITY(1,1) NOT NULL,
	[DateKey] [int] NOT NULL,
	[ProductKey] [int] NOT NULL,
	[StoreKey] [int] NOT NULL,
	[Units] [int] NOT NULL,
	[Revenue] [decimal](12, 2) NOT NULL,
	[LoadDttm] [datetime2](0) NOT NULL,
	[SourceFile] [nvarchar](260) NULL,
PRIMARY KEY CLUSTERED 
(
	[FactSalesKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dw].[FactSales] ADD  DEFAULT (sysdatetime()) FOR [LoadDttm]
GO

ALTER TABLE [dw].[FactSales]  WITH NOCHECK ADD  CONSTRAINT [CK_FactSales_Revenue_NonNeg] CHECK  (([Revenue]>=(0)))
GO

ALTER TABLE [dw].[FactSales] CHECK CONSTRAINT [CK_FactSales_Revenue_NonNeg]
GO

ALTER TABLE [dw].[FactSales]  WITH NOCHECK ADD  CONSTRAINT [CK_FactSales_Units_Positive] CHECK  (([Units]>=(0)))
GO

ALTER TABLE [dw].[FactSales] CHECK CONSTRAINT [CK_FactSales_Units_Positive]
GO


