/*
================================================================================
Project     : Olist Data Warehouse
Layer       : Bronze
Procedure   : bronze.load_bronze
Description : Load source CSV files into Bronze tables using a full load strategy.

Responsibilities:
    - Truncate existing Bronze table data.
    - Load source data from CSV files using BULK INSERT.
    - Track loaded row counts and execution duration.
    - Handle errors and rollback failed transactions.

Execution:
    EXEC bronze.load_bronze;

Important Notes:
    - This procedure performs a full load on every execution.
    - Source files must be accessible to the SQL Server service account.
    - All changes are rolled back if the transaction fails.
================================================================================
*/

USE Olist_DWH;
GO

CREATE OR ALTER PROCEDURE bronze.load_bronze
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @StartTime       DATETIME = GETDATE(),
        @EndTime         DATETIME,
        @RowsInserted    BIGINT = 0,
        @TableRows       BIGINT,
        @ProcessedTables INT = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        PRINT '============================================================';
        PRINT '                 STARTING BRONZE LAYER LOAD';
        PRINT '============================================================';


        PRINT '============================================================';
        PRINT '                         CRM SECTION';
        PRINT '============================================================';

        -- 1. CRM Customer Information

        PRINT '-------------------- CRM CUSTOMER INFO ---------------------';

        PRINT 'TRUNCATING TABLE: bronze.crm_cust_info';

        TRUNCATE TABLE bronze.crm_cust_info;

        PRINT 'LOADING TABLE: bronze.crm_cust_info';

        BULK INSERT bronze.crm_cust_info
        FROM 'C:\Users\Legion\Downloads\Olist_DWH\Data\crm_customers_dataset.csv'
        WITH
        (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0a',
            CODEPAGE = '65001',
            TABLOCK
        );

        SET @TableRows = @@ROWCOUNT;
        SET @RowsInserted += @TableRows;
        SET @ProcessedTables += 1;

        PRINT CONCAT(
            'LOAD COMPLETED: bronze.crm_cust_info | ROWS: ',
            @TableRows
        );


        -- 2. CRM Geolocation Information

        PRINT '---------------- CRM GEOLOCATION INFO ---------------------';

        PRINT 'TRUNCATING TABLE: bronze.crm_geolocation_info';

        TRUNCATE TABLE bronze.crm_geolocation_info;

        PRINT 'LOADING TABLE: bronze.crm_geolocation_info';

        BULK INSERT bronze.crm_geolocation_info
        FROM 'C:\Users\Legion\Downloads\Olist_DWH\Data\crm_geolocation_dataset.csv'
        WITH
        (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0a',
            CODEPAGE = '65001',
            TABLOCK
        );

        SET @TableRows = @@ROWCOUNT;
        SET @RowsInserted += @TableRows;
        SET @ProcessedTables += 1;

        PRINT CONCAT(
            'LOAD COMPLETED: bronze.crm_geolocation_info | ROWS: ',
            @TableRows
        );


        -- 3. CRM Seller Information

        PRINT '-------------------- CRM SELLER INFO ----------------------';

        PRINT 'TRUNCATING TABLE: bronze.crm_seller_info';

        TRUNCATE TABLE bronze.crm_seller_info;

        PRINT 'LOADING TABLE: bronze.crm_seller_info';

        BULK INSERT bronze.crm_seller_info
        FROM 'C:\Users\Legion\Downloads\Olist_DWH\Data\crm_sellers_dataset.csv'
        WITH
        (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0a',
            CODEPAGE = '65001',
            TABLOCK
        );

        SET @TableRows = @@ROWCOUNT;
        SET @RowsInserted += @TableRows;
        SET @ProcessedTables += 1;

        PRINT CONCAT(
            'LOAD COMPLETED: bronze.crm_seller_info | ROWS: ',
            @TableRows
        );


        PRINT '============================================================';
        PRINT '                        SALES SECTION';
        PRINT '============================================================';

        -- 4. Sales Order Items

        PRINT '-------------------- SALES ORDER ITEMS ---------------------';

        PRINT 'TRUNCATING TABLE: bronze.sales_order_items';

        TRUNCATE TABLE bronze.sales_order_items;

        PRINT 'LOADING TABLE: bronze.sales_order_items';

        BULK INSERT bronze.sales_order_items
        FROM 'C:\Users\Legion\Downloads\Olist_DWH\Data\sales_order_items_dataset.csv'
        WITH
        (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0a',
            CODEPAGE = '65001',
            TABLOCK
        );

        SET @TableRows = @@ROWCOUNT;
        SET @RowsInserted += @TableRows;
        SET @ProcessedTables += 1;

        PRINT CONCAT(
            'LOAD COMPLETED: bronze.sales_order_items | ROWS: ',
            @TableRows
        );


        -- 5. Order Reviews

        PRINT '-------------------- SALES ORDER REVIEWS ------------------';

        PRINT 'TRUNCATING TABLE: bronze.sales_order_reviews';

        TRUNCATE TABLE bronze.sales_order_reviews;

        PRINT 'LOADING TABLE: bronze.sales_order_reviews';

        BULK INSERT bronze.sales_order_reviews
        FROM 'C:\Users\Legion\Downloads\Olist_DWH\Data\sales_order_reviews_dataset.csv'
        WITH
        (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0a',
            CODEPAGE = '65001',
            TABLOCK
        );

        SET @TableRows = @@ROWCOUNT;
        SET @RowsInserted += @TableRows;
        SET @ProcessedTables += 1;

        PRINT CONCAT(
            'LOAD COMPLETED: bronze.sales_order_reviews | ROWS: ',
            @TableRows
        );


        -- 6. Sales Orders

        PRINT '-------------------- SALES ORDERS --------------------------';

        PRINT 'TRUNCATING TABLE: bronze.sales_orders';

        TRUNCATE TABLE bronze.sales_orders;

        PRINT 'LOADING TABLE: bronze.sales_orders';

        BULK INSERT bronze.sales_orders
        FROM 'C:\Users\Legion\Downloads\Olist_DWH\Data\sales_orders_dataset.csv'
        WITH
        (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0a',
            CODEPAGE = '65001',
            TABLOCK
        );

        SET @TableRows = @@ROWCOUNT;
        SET @RowsInserted += @TableRows;
        SET @ProcessedTables += 1;

        PRINT CONCAT(
            'LOAD COMPLETED: bronze.sales_orders | ROWS: ',
            @TableRows
        );


        PRINT '============================================================';
        PRINT '                      PAYMENTS SECTION';
        PRINT '============================================================';

        -- 7. Order Payments

        PRINT '-------------------- ORDER PAYMENTS ------------------------';

        PRINT 'TRUNCATING TABLE: bronze.payments_order_info';

        TRUNCATE TABLE bronze.payments_order_info;

        PRINT 'LOADING TABLE: bronze.payments_order_info';

        BULK INSERT bronze.payments_order_info
        FROM 'C:\Users\Legion\Downloads\Olist_DWH\Data\payment_order_dataset.csv'
        WITH
        (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0a',
            CODEPAGE = '65001',
            TABLOCK
        );

        SET @TableRows = @@ROWCOUNT;
        SET @RowsInserted += @TableRows;
        SET @ProcessedTables += 1;

        PRINT CONCAT(
            'LOAD COMPLETED: bronze.payments_order_info | ROWS: ',
            @TableRows
        );


        PRINT '============================================================';
        PRINT '                      CATALOG SECTION';
        PRINT '============================================================';

        -- 8. Catalog Products

        PRINT '-------------------- CATALOG PRODUCTS ----------------------';

        PRINT 'TRUNCATING TABLE: bronze.catalog_products';

        TRUNCATE TABLE bronze.catalog_products;

        PRINT 'LOADING TABLE: bronze.catalog_products';

        BULK INSERT bronze.catalog_products
        FROM 'C:\Users\Legion\Downloads\Olist_DWH\Data\catalog_products_dataset.csv'
        WITH
        (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0a',
            CODEPAGE = '65001',
            TABLOCK
        );

        SET @TableRows = @@ROWCOUNT;
        SET @RowsInserted += @TableRows;
        SET @ProcessedTables += 1;

        PRINT CONCAT(
            'LOAD COMPLETED: bronze.catalog_products | ROWS: ',
            @TableRows
        );


        -- 9. Product Category Translation

        PRINT '---------------- CATEGORY TRANSLATION ---------------------';

        PRINT 'TRUNCATING TABLE: bronze.catalog_category_translation';

        TRUNCATE TABLE bronze.catalog_category_translation;

        PRINT 'LOADING TABLE: bronze.catalog_category_translation';

        BULK INSERT bronze.catalog_category_translation
        FROM 'C:\Users\Legion\Downloads\Olist_DWH\Data\catalog_product_category_name_translation.csv'
        WITH
        (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0a',
            CODEPAGE = '65001',
            TABLOCK
        );

        SET @TableRows = @@ROWCOUNT;
        SET @RowsInserted += @TableRows;
        SET @ProcessedTables += 1;

        PRINT CONCAT(
            'LOAD COMPLETED: bronze.catalog_category_translation | ROWS: ',
            @TableRows
        );


        -- FINAL SUMMARY

        COMMIT TRANSACTION;

        SET @EndTime = GETDATE();

        PRINT '============================================================';
        PRINT '               BRONZE LOAD COMPLETED SUCCESSFULLY';
        PRINT '============================================================';

        PRINT CONCAT('Tables Processed: ', @ProcessedTables);
        PRINT CONCAT('Total Rows Loaded: ', @RowsInserted);

        PRINT CONCAT(
            'Execution Duration (Seconds): ',
            DATEDIFF(SECOND, @StartTime, @EndTime)
        );

        PRINT '============================================================';

    END TRY
    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        PRINT '============================================================';
        PRINT '                  BRONZE LOAD FAILED';
        PRINT '============================================================';

        PRINT CONCAT('Error Number: ', ERROR_NUMBER());
        PRINT CONCAT('Error Line: ', ERROR_LINE());
        PRINT CONCAT('Error Message: ', ERROR_MESSAGE());

        PRINT '============================================================';

        THROW;

    END CATCH;
END;
GO

EXEC bronze.load_bronze;
GO
