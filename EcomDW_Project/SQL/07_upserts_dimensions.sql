------Upsert DimDate----

;WITH d AS (
    SELECT DISTINCT CAST(SaleDate AS date) AS [Date]
    FROM stg.vSalesRaw_Dedup
    WHERE SaleDate IS NOT NULL
)
INSERT dw.DimDate
(
    DateKey, [Date], [Year], [Quarter], [Month], MonthName, [Day], DayName, IsWeekend
)
SELECT
    (YEAR(d.[Date]) * 10000) + (MONTH(d.[Date]) * 100) + DAY(d.[Date]) AS DateKey,
    d.[Date],
    DATEPART(year, d.[Date])     AS [Year],
    DATEPART(quarter, d.[Date])  AS [Quarter],
    DATEPART(month, d.[Date])    AS [Month],
    DATENAME(month, d.[Date])    AS MonthName,
    DATEPART(day, d.[Date])      AS [Day],
    DATENAME(weekday, d.[Date])  AS DayName,
    CASE WHEN DATENAME(weekday, d.[Date]) IN ('Saturday','Sunday') THEN 1 ELSE 0 END AS IsWeekend
FROM d
LEFT JOIN dw.DimDate dd
    ON dd.[Date] = d.[Date]
WHERE dd.[Date] IS NULL;

-----Upsert DimProduct----

MERGE dw.DimProduct AS tgt
USING (
    SELECT DISTINCT
        ProductId   = CAST(ProductId AS varchar(50)),
        ProductName = NULLIF(ProductName,''),
        Category    = NULLIF(Category,''),
        Brand       = NULLIF(Brand,'')
    FROM stg.vSalesRaw_Dedup
    WHERE ProductId IS NOT NULL
) AS src
ON tgt.ProductNaturalId = src.ProductId
WHEN MATCHED AND (
       ISNULL(tgt.ProductName,'') <> ISNULL(src.ProductName,'')
    OR ISNULL(tgt.Category,'')    <> ISNULL(src.Category,'')
    OR ISNULL(tgt.Brand,'')       <> ISNULL(src.Brand,'')
)
THEN UPDATE SET
    tgt.ProductName = src.ProductName,
    tgt.Category    = src.Category,
    tgt.Brand       = src.Brand
WHEN NOT MATCHED THEN
    INSERT (ProductNaturalId, ProductName, Category, Brand, StartDate, EndDate)
    VALUES (src.ProductId, src.ProductName, src.Category, src.Brand, CAST(GETDATE() AS date), NULL);

-----Upsert DimStore-----

SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#StoreUpsert') IS NOT NULL
    DROP TABLE #StoreUpsert;

;WITH src AS
(
    SELECT
        StoreId   = CAST(sm.StoreId AS varchar(50)),
        StoreName = NULLIF(sm.StoreName,''),
        City      = NULLIF(sm.City,''),
        [State]   = NULLIF(sm.[State],''),
        Region    = NULLIF(sm.Region,''),
        rn = ROW_NUMBER() OVER
        (
            PARTITION BY CAST(sm.StoreId AS varchar(50))
            ORDER BY sm.LoadDttm DESC
        )
    FROM stg.StoreMaster sm
    WHERE sm.StoreId IS NOT NULL
),
s AS
(
    SELECT StoreId, StoreName, City, [State], Region
    FROM src
    WHERE rn = 1
)
SELECT
    tgt.StoreKey,
    tgt.StoreNaturalId,
    tgt.StoreName AS tgtStoreName,
    tgt.City      AS tgtCity,
    tgt.[State]   AS tgtState,
    tgt.Region    AS tgtRegion,
    s.StoreId,
    s.StoreName,
    s.City,
    s.[State],
    s.Region
INTO #StoreUpsert
FROM s
LEFT JOIN dw.DimStore tgt
    ON tgt.StoreNaturalId = s.StoreId;

UPDATE tgt
SET
    tgt.StoreName = u.StoreName,
    tgt.City      = u.City,
    tgt.[State]   = u.[State],
    tgt.Region    = u.Region
FROM dw.DimStore tgt
JOIN #StoreUpsert u
    ON u.StoreKey = tgt.StoreKey
WHERE u.StoreKey IS NOT NULL
  AND (
         ISNULL(u.tgtStoreName,'') <> ISNULL(u.StoreName,'')
      OR ISNULL(u.tgtCity,'')      <> ISNULL(u.City,'')
      OR ISNULL(u.tgtState,'')     <> ISNULL(u.[State],'')
      OR ISNULL(u.tgtRegion,'')    <> ISNULL(u.Region,'')
  );

INSERT dw.DimStore (StoreNaturalId, StoreName, City, [State], Region)
SELECT u.StoreId, u.StoreName, u.City, u.[State], u.Region
FROM #StoreUpsert u
WHERE u.StoreKey IS NULL;

DROP TABLE #StoreUpsert;

