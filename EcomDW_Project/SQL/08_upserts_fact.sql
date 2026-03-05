SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @RunIdTest nvarchar(40) = ?;
DECLARE @PackageStartDt datetime2(3) = SYSDATETIME();

BEGIN TRY
    BEGIN TRAN;

    -- UPDATE existing fact rows
    UPDATE f
    SET
        f.Units      = s.Units,
        f.Revenue    = s.Revenue,
        f.LoadDttm   = @PackageStartDt,
        f.SourceFile = s.SourceFile
    FROM dw.FactSales f
    JOIN stg.vSalesRaw_Dedup s ON 1=1
    JOIN dw.DimDate dd    ON dd.[Date] = CAST(s.SaleDate AS date)
    JOIN dw.DimStore ds   ON ds.StoreNaturalId = s.StoreId
    JOIN dw.DimProduct dp ON dp.ProductNaturalId = s.ProductId
    WHERE f.DateKey    = dd.DateKey
      AND f.StoreKey   = ds.StoreKey
      AND f.ProductKey = dp.ProductKey;

    DECLARE @UpdateCount int = @@ROWCOUNT;

    -- INSERT new fact rows
    INSERT dw.FactSales (DateKey, ProductKey, StoreKey, Units, Revenue, LoadDttm, SourceFile)
    SELECT
        dd.DateKey,
        dp.ProductKey,
        ds.StoreKey,
        s.Units,
        s.Revenue,
        @PackageStartDt,
        s.SourceFile
    FROM stg.vSalesRaw_Dedup s
    JOIN dw.DimDate dd    ON dd.[Date] = CAST(s.SaleDate AS date)
    JOIN dw.DimStore ds   ON ds.StoreNaturalId = s.StoreId
    JOIN dw.DimProduct dp ON dp.ProductNaturalId = s.ProductId
    WHERE NOT EXISTS (
        SELECT 1
        FROM dw.FactSales f
        WHERE f.DateKey    = dd.DateKey
          AND f.StoreKey   = ds.StoreKey
          AND f.ProductKey = dp.ProductKey
    );

    DECLARE @InsertCount int = @@ROWCOUNT;

    INSERT etl.RunLog (RunId, StepName, [RowCount], Status, LoggedAt)
    VALUES
      (@RunIdTest, 'FactSales UPDATE', @UpdateCount, 'Succeeded', SYSDATETIME()),
      (@RunIdTest, 'FactSales INSERT', @InsertCount, 'Succeeded', SYSDATETIME());

    COMMIT;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW;
END CATCH;
