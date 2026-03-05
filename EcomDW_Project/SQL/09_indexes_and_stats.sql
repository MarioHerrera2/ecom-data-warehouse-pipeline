------//////-----/stg.SalesRaw/-------///////-------////////------

----- speed up deup and etl checks at staging grain - efficiently picking latest loaded row with lineage fields covered ------


CREATE NONCLUSTERED INDEX [IX_SalesRaw_NK] ON [stg].[SalesRaw]
([SaleDate],[ProductId],[StoreId])
INCLUDE([LoadDttm],[SourceFile])

------//////-----/etl.runlog/-------///////-------////////------

----- Covering index descriptive columns included ------

CREATE NONCLUSTERED INDEX [IX_RunLog_RunId] 
ON [etl].[RunLog] ([RunId])
INCLUDE([StepName],[Status],[RowCount],[LoggedAt])

------//////-----/DimStore/-------///////-------////////------

----- Filtered index ------

CREATE NONCLUSTERED INDEX [IX_RunLog_SourceFile] 
ON [etl].[RunLog] ([SourceFile])
WHERE ([SourceFile] IS NOT NULL)

------//////-----/etl.RunLog/-------///////-------////////------

-----Identity Clustered Key ------

ALTER TABLE [etl].[RunLog] ADD PRIMARY KEY CLUSTERED 
([RunLogId])

------//////-----/DimStore/-------///////-------////////------

----- Helps Region/State Filters ------

CREATE NONCLUSTERED INDEX [IX_DimStore_Region_State] ON [dw].[DimStore]
([Region],[State])

------////////------/DimStore/-------///////------////////------

------- Clustured Surrogate key also like DimDate/DimProduct = fast joins from FactSales----

ALTER TABLE [dw].[DimStore] ADD PRIMARY KEY CLUSTERED 
([StoreKey])

-----////////------/DimStore/--------////////-------/////////--------

----enforce uniqueness to prevent dup stores / faster ETL look ups------

ALTER TABLE [dw].[DimStore] ADD UNIQUE NONCLUSTERED 
([StoreNaturalId])

-------///////-----/DimProduct/-------///////------///////--------

-----enforcing uniqueness to prevent dup products & quicken ETL look ups-----

ALTER TABLE [dw].[DimProduct] ADD UNIQUE NONCLUSTERED 
([ProductNaturalId])

-------/////------/DimProduct/-----//////------//////-------

------- Clustered surrogate key like dimDate = fast joins from FactSales------

ALTER TABLE [dw].[DimProduct] ADD PRIMARY KEY CLUSTERED 
([ProductKey])

-------//////------/DimProduct/-------///////-----//////-----

------- Helps filter cascading parameters & report queries when slicing product dimension by category------

CREATE NONCLUSTERED INDEX [IX_DimProduct_Category]
ON [dw].[DimProduct] ([Category],[Brand])
INCLUDE([ProductKey],ProductNaturalId,ProductName)


----////-----/DimDate/------/////------//////-------

-----Clustered PK on surrogate key for faster joins from fact and stable integer key-----

ALTER TABLE [dw].[DimDate] ADD PRIMARY KEY CLUSTERED 
(DateKey) ON PRIMARY

-----/////----/DimDate/----////-----//////---------

--- unique on date supports date look ups during ETL -----
CREATE UNIQUE NONCLUSTERED INDEX [UX_DimDate_Date]
ON dw.DimDate ([Date])

-------////////--------/FactSales/-------////////-------

----- Helps main report uses date range / filter by region/state/store ---///--- "ProductKey, Units, Revenue" added for aggregation lookup speed------

CREATE NONCLUSTERED INDEX IX_FactSales_Date_Store
ON dw.FactSales (DateKey, StoreKey)
INCLUDE (ProductKey, Units, Revenue);

-----//////-----//////------/FactSales/-----//////-----

----Helps Drillthrough report uses productid/productkey and date range ----////--- StoreKey, Units, Revenue added for aggregation look up speed ---------

CREATE NONCLUSTERED INDEX IX_FactSales_Product_Date
ON dw.FactSales (ProductKey, DateKey)
INCLUDE (StoreKey, Units, Revenue);

----/////------//////------/FactSales/-----/////------

-----Unique index on grain for data correctness + performance ---///--- DateKey, StoreKey, ProductKey to match main report/drillthrough index -------

CREATE UNIQUE NONCLUSTERED INDEX UX_FactSales_Grain
ON dw.FactSales (DateKey, StoreKey, ProductKey);

-------//////---- Might Needs ------/////----- 

---- Dw.DimDate Index drop-------


drop index IX_DimDate_FullDate on dw.dimdate

----- dw.DimProduct index drop ----

drop index [IX_DimProduct_Natural] on dw.dimproduct

----- dw.DimStore index drop ----

drop index [UX_DimStore_StoreNaturalId] on dw.dimstore

drop index [IX_DimStore_Natural] on dw.dimstore