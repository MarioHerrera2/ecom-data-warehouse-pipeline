USE [ECommDW]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [stg].[vSalesRaw_Dedup]
AS
WITH ranked AS
(
  SELECT
      s.SaleDate,
      s.ProductId,
      s.ProductName,
      s.Category,
      s.Brand,
      s.StoreId,
      s.StoreName,
      s.City,
      s.[State],
      sm.Region,              --  comes from store master
      s.Units,
      s.Revenue,
      s.SourceFile,
      s.LoadDttm,
      rn = ROW_NUMBER() OVER
      (
        PARTITION BY s.SaleDate, s.ProductId, s.StoreId
        ORDER BY
          CASE WHEN s.LoadDttm IS NULL THEN 1 ELSE 0 END,
          s.LoadDttm DESC,
          s.SourceFile DESC
      )
  FROM stg.SalesRaw s
  LEFT JOIN stg.StoreMaster sm
    ON LTRIM(RTRIM(sm.StoreId)) = LTRIM(RTRIM(s.StoreId))
)
SELECT *
FROM ranked
WHERE rn = 1;
GO


