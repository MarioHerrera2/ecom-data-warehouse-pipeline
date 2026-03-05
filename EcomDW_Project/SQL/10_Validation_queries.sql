-------//////----//////-----//////----//////

            ----Checking load---------

-- Staging landed?
SELECT COUNT(*) AS StgSalesRawRows FROM stg.SalesRaw;

-- Dedup view rows?
SELECT COUNT(*) AS StgDedupRows FROM stg.vSalesRaw_Dedup;

-- Fact rows?
SELECT COUNT(*) AS FactRows FROM dw.FactSales;

-- Report view rows?
SELECT COUNT(*) AS RptRows FROM rpt.vw_Sales;

 ---/////-----/Grain & Dup Check/-------///////------

-----Staging Dedup should be unique at its grain ------

 SELECT TOP (50)
    s.SaleDate, s.ProductId, s.StoreId,
    COUNT(*) AS Cnt
FROM stg.vSalesRaw_Dedup s
GROUP BY s.SaleDate, s.ProductId, s.StoreId
HAVING COUNT(*) > 1
ORDER BY Cnt DESC;

----- Fact should be unique at its grain -------

SELECT TOP (50)
    f.DateKey, f.StoreKey, f.ProductKey,
    COUNT(*) AS Cnt
FROM dw.FactSales f
GROUP BY f.DateKey, f.StoreKey, f.ProductKey
HAVING COUNT(*) > 1
ORDER BY Cnt DESC;


------ Natural key uniqueness in dimesions ------ 

-- ProductNaturalId duplicates
SELECT ProductNaturalId, COUNT(*) Cnt
FROM dw.DimProduct
GROUP BY ProductNaturalId
HAVING COUNT(*) > 1;

-- StoreNaturalId duplicates
SELECT StoreNaturalId, COUNT(*) Cnt
FROM dw.DimStore
GROUP BY StoreNaturalId
HAVING COUNT(*) > 1;

-- Date duplicates (if you store Date column)
SELECT [Date], COUNT(*) Cnt
FROM dw.DimDate
GROUP BY [Date]
HAVING COUNT(*) > 1;


------//////------/Referential integrity/------///////-----

---- How many staged rows cannto resolve to dim keys? -----

SELECT
    COUNT(*) AS TotalStaged,
    SUM(CASE WHEN dp.ProductKey IS NULL THEN 1 ELSE 0 END) AS MissingProduct,
    SUM(CASE WHEN ds.StoreKey   IS NULL THEN 1 ELSE 0 END) AS MissingStore,
    SUM(CASE WHEN dd.DateKey    IS NULL THEN 1 ELSE 0 END) AS MissingDate
FROM stg.vSalesRaw_Dedup s
LEFT JOIN dw.DimProduct dp ON dp.ProductNaturalId = s.ProductId
LEFT JOIN dw.DimStore   ds ON ds.StoreNaturalId   = s.StoreId
LEFT JOIN dw.DimDate    dd ON dd.[Date]           = s.SaleDate;

---- Orphaned keys in FactSales ----  

SELECT
    SUM(CASE WHEN dp.ProductKey IS NULL THEN 1 ELSE 0 END) AS OrphanProductKeys,
    SUM(CASE WHEN ds.StoreKey   IS NULL THEN 1 ELSE 0 END) AS OrphanStoreKeys,
    SUM(CASE WHEN dd.DateKey    IS NULL THEN 1 ELSE 0 END) AS OrphanDateKeys,
    COUNT(*) AS FactRows
FROM dw.FactSales f
LEFT JOIN dw.DimProduct dp ON dp.ProductKey = f.ProductKey
LEFT JOIN dw.DimStore   ds ON ds.StoreKey   = f.StoreKey
LEFT JOIN dw.DimDate    dd ON dd.DateKey    = f.DateKey;


-----///Null / required field checks (Staging + dims)////----///-

-- required columns missing in staged dedup ----

SELECT
    SUM(CASE WHEN SaleDate  IS NULL THEN 1 ELSE 0 END) AS NullSaleDate,
    SUM(CASE WHEN ProductId IS NULL OR LTRIM(RTRIM(ProductId)) = '' THEN 1 ELSE 0 END) AS BlankProductId,
    SUM(CASE WHEN StoreId   IS NULL OR LTRIM(RTRIM(StoreId))   = '' THEN 1 ELSE 0 END) AS BlankStoreId,
    SUM(CASE WHEN Units     IS NULL THEN 1 ELSE 0 END) AS NullUnits,
    SUM(CASE WHEN Revenue   IS NULL THEN 1 ELSE 0 END) AS NullRevenue
FROM stg.vSalesRaw_Dedup;


---- Dimension "Must have" checks ---- 

SELECT COUNT(*) AS NullProductNaturalId
FROM dw.DimProduct
WHERE ProductNaturalId IS NULL OR LTRIM(RTRIM(ProductNaturalId))='';

SELECT COUNT(*) AS NullStoreNaturalId
FROM dw.DimStore
WHERE StoreNaturalId IS NULL OR LTRIM(RTRIM(StoreNaturalId))='';

 ------//////-----/Money / Quantity sanity checks/------//////--

 --- check for negative or zero values -----

 SELECT
    SUM(CASE WHEN Units   <= 0 THEN 1 ELSE 0 END) AS BadUnits,
    SUM(CASE WHEN Revenue <  0 THEN 1 ELSE 0 END) AS NegativeRevenue,
    SUM(CASE WHEN Revenue =  0 THEN 1 ELSE 0 END) AS ZeroRevenue
FROM stg.vSalesRaw_Dedup;

----//////-----/Unit Price outliers/----/////------//////----

---- catching weird unit-> price anomalies----

;WITH x AS (
    SELECT
        ProductId, ProductName, StoreId, StoreName, SaleDate,
        Units, Revenue,
        UnitPrice = CASE WHEN Units > 0 THEN Revenue / NULLIF(Units,0) END
    FROM stg.vSalesRaw_Dedup
    WHERE Units IS NOT NULL AND Revenue IS NOT NULL
)
SELECT TOP (50) *
FROM x
WHERE UnitPrice IS NULL
   OR UnitPrice > 500   -- tune threshold per your data
   OR UnitPrice < 0.50  -- tune threshold per your data
ORDER BY UnitPrice DESC;

---- checking price consistency per product -----

;WITH p AS (
    SELECT
        ProductId,
        UnitPrice = Revenue / NULLIF(Units,0)
    FROM stg.vSalesRaw_Dedup
    WHERE Units > 0 AND Revenue IS NOT NULL
)
SELECT TOP (50)
    ProductId,
    MIN(UnitPrice) AS MinPrice,
    MAX(UnitPrice) AS MaxPrice,
    (MAX(UnitPrice)-MIN(UnitPrice)) AS Spread
FROM p
GROUP BY ProductId
HAVING (MAX(UnitPrice)-MIN(UnitPrice)) > 50  -- tune
ORDER BY Spread DESC;

-------///////------/StoreMaster coverage/------///////-----

---- Stores with sales missing in storeMaster ----

SELECT TOP (50)
    s.StoreId, COUNT(*) AS RowsInSales
FROM stg.vSalesRaw_Dedup s
LEFT JOIN stg.StoreMaster sm ON sm.StoreId = s.StoreId
WHERE sm.StoreId IS NULL
GROUP BY s.StoreId
ORDER BY RowsInSales DESC;

---- Region/State completeness in StoreMaster ----

SELECT
    SUM(CASE WHEN Region IS NULL OR LTRIM(RTRIM(Region))='' THEN 1 ELSE 0 END) AS BlankRegion,
    SUM(CASE WHEN [State] IS NULL OR LTRIM(RTRIM([State]))='' THEN 1 ELSE 0 END) AS BlankState
FROM stg.StoreMaster;

-- Show any weird Region values
SELECT Region, COUNT(*) Cnt
FROM stg.StoreMaster
GROUP BY Region
ORDER BY Cnt DESC;

----//////-------/What Changed?/------///////-------///////------

---checking DimStore Update as expected ---  

SELECT TOP (50)
    ds.StoreNaturalId, ds.StoreName, ds.City, ds.[State], ds.Region
FROM dw.DimStore ds
ORDER BY ds.StoreNaturalId;

----- Fact Totals reconcilliation (Staging Vs Facts) ----

-- totals from staging (resolved only)
SELECT
    SUM(s.Units)   AS StgUnits,
    SUM(s.Revenue) AS StgRevenue
FROM stg.vSalesRaw_Dedup s
JOIN dw.DimProduct dp ON dp.ProductNaturalId = s.ProductId
JOIN dw.DimStore   ds ON ds.StoreNaturalId   = s.StoreId
JOIN dw.DimDate    dd ON dd.[Date]           = s.SaleDate;

-- totals from fact
SELECT
    SUM(f.Units)   AS FactUnits,
    SUM(f.Revenue) AS FactRevenue
FROM dw.FactSales f;

-------//////-----/Load Lineage/--------//////------/////---

---- rows by sourcefile verifying loop works ----

SELECT
    SourceFile,
    COUNT(*) AS Rows,
    MIN(LoadDttm) AS FirstLoad,
    MAX(LoadDttm) AS LastLoad
FROM stg.SalesRaw
GROUP BY SourceFile
ORDER BY LastLoad DESC;

----- looking for dup file loads ------  

SELECT
    SourceFile,
    COUNT(DISTINCT LoadDttm) AS LoadBatches,
    COUNT(*) AS Rows
FROM stg.SalesRaw
GROUP BY SourceFile
HAVING COUNT(DISTINCT LoadDttm) > 1
ORDER BY LoadBatches DESC;
