/*
================================================================================
Project      : Olist Data Warehouse
Layer        : Bronze
Procedure    : bronze.create_bronze_tables
Description  : Initializes the Bronze layer by recreating the source-aligned
               tables required for raw data ingestion.

Responsibilities:
    - Drops existing Bronze tables if they exist.
    - Recreates all nine tables using predefined source column definitions.
    - Provides real-time execution logs for each table creation operation.
    - Uses TRY...CATCH for error handling and detailed diagnostic logging.
    - Wraps table operations in a transaction to support rollback on failure.
    - Commits changes only after all table creation operations succeed.

Execution:
    EXEC bronze.create_bronze_tables;

Important Notes:
    - This procedure is intended for initial setup or full Bronze layer
      reinitialization.
    - Existing data in the affected tables will be lost when the procedure
      executes successfully.
    - Ensure that required data is backed up or can be reloaded before execution.
    - The procedure does not load source data; it only creates the table
      structures required for subsequent ingestion processes.

Maintenance:
    Update this procedure whenever Bronze table definitions change.
    Coordinate schema changes with the team to avoid breaking downstream
    Silver and Gold layer dependencies.

================================================================================
*/


USE Olist_DWH;
GO

CREATE OR ALTER PROCEDURE bronze.create_bronze_tables
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- =============================================
    -- Execution Variables
    -- =============================================
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @EndTime DATETIME;
    DECLARE @Duration INT;
    DECLARE @TotalTables INT = 9;
    DECLARE @CreatedTables INT = 0;
    DECLARE @LogTime VARCHAR(19);

    -- Error Handling Variables
    DECLARE @ErrorNumber INT;
    DECLARE @ErrorMessage NVARCHAR(4000);
    DECLARE @ErrorLine INT;
    DECLARE @ErrorProcedure NVARCHAR(128);

    SET @LogTime = CONVERT(VARCHAR(19), @StartTime, 120);

    BEGIN TRY

        -- =============================================
        -- INITIALIZATION LOG
        -- =============================================
        RAISERROR('', 0, 1) WITH NOWAIT;
        RAISERROR('============================================================', 0, 1) WITH NOWAIT;
        RAISERROR('              OLIST DATA WAREHOUSE - BRONZE LAYER           ', 0, 1) WITH NOWAIT;
        RAISERROR('                    TABLE CREATION PROCESS                 ', 0, 1) WITH NOWAIT;
        RAISERROR('============================================================', 0, 1) WITH NOWAIT;

        RAISERROR('Database       : Olist_DWH', 0, 1) WITH NOWAIT;
        RAISERROR('Schema         : bronze', 0, 1) WITH NOWAIT;
        RAISERROR('Start Time     : %s', 0, 1, @LogTime) WITH NOWAIT;
        RAISERROR('Total Tables   : %d', 0, 1, @TotalTables) WITH NOWAIT;

        RAISERROR('------------------------------------------------------------', 0, 1) WITH NOWAIT;
        RAISERROR('STATUS         : INITIALIZING', 0, 1) WITH NOWAIT;
        RAISERROR('------------------------------------------------------------', 0, 1) WITH NOWAIT;

        BEGIN TRANSACTION;

        -- =============================================
        -- TABLE 1: CRM CUSTOMERS
        -- =============================================
        RAISERROR('', 0, 1) WITH NOWAIT;
        RAISERROR('[1/9] TABLE: bronze.crm_cust_info', 0, 1) WITH NOWAIT;
        RAISERROR('      Action : Drop existing table if present, then create.', 0, 1) WITH NOWAIT;

        IF OBJECT_ID('bronze.crm_cust_info', 'U') IS NOT NULL
            DROP TABLE bronze.crm_cust_info;

        CREATE TABLE bronze.crm_cust_info (
            customer_id              VARCHAR(50),
            customer_unique_id       VARCHAR(50),
            customer_zip_code_prefix VARCHAR(10),
            customer_city            VARCHAR(100),
            customer_state           CHAR(2)
        );

        SET @CreatedTables += 1;

        RAISERROR('      Status : SUCCESS', 0, 1) WITH NOWAIT;
        RAISERROR('      Result : Customer table created successfully.', 0, 1) WITH NOWAIT;

        -- =============================================
        -- TABLE 2: CRM GEOLOCATION
        -- =============================================
        RAISERROR('', 0, 1) WITH NOWAIT;
        RAISERROR('[2/9] TABLE: bronze.crm_geolocation_info', 0, 1) WITH NOWAIT;
        RAISERROR('      Action : Drop existing table if present, then create.', 0, 1) WITH NOWAIT;

        IF OBJECT_ID('bronze.crm_geolocation_info', 'U') IS NOT NULL
            DROP TABLE bronze.crm_geolocation_info;

        CREATE TABLE bronze.crm_geolocation_info (
            geolocation_zip_code_prefix VARCHAR(10),
            geolocation_lat             DECIMAL(10, 6),
            geolocation_lng             DECIMAL(10, 6),
            geolocation_city            VARCHAR(100),
            geolocation_state           CHAR(2)
        );

        SET @CreatedTables += 1;

        RAISERROR('      Status : SUCCESS', 0, 1) WITH NOWAIT;
        RAISERROR('      Result : Geolocation table created successfully.', 0, 1) WITH NOWAIT;

        -- =============================================
        -- TABLE 3: CRM SELLERS
        -- =============================================
        RAISERROR('', 0, 1) WITH NOWAIT;
        RAISERROR('[3/9] TABLE: bronze.crm_seller_info', 0, 1) WITH NOWAIT;
        RAISERROR('      Action : Drop existing table if present, then create.', 0, 1) WITH NOWAIT;

        IF OBJECT_ID('bronze.crm_seller_info', 'U') IS NOT NULL
            DROP TABLE bronze.crm_seller_info;

        CREATE TABLE bronze.crm_seller_info (
            seller_id              VARCHAR(50),
            seller_zip_code_prefix VARCHAR(10),
            seller_city            VARCHAR(100),
            seller_state           CHAR(2)
        );

        SET @CreatedTables += 1;

        RAISERROR('      Status : SUCCESS', 0, 1) WITH NOWAIT;
        RAISERROR('      Result : Seller table created successfully.', 0, 1) WITH NOWAIT;

        -- =============================================
        -- TABLE 4: SALES ORDER ITEMS
        -- =============================================
        RAISERROR('', 0, 1) WITH NOWAIT;
        RAISERROR('[4/9] TABLE: bronze.sales_order_items', 0, 1) WITH NOWAIT;
        RAISERROR('      Action : Drop existing table if present, then create.', 0, 1) WITH NOWAIT;

        IF OBJECT_ID('bronze.sales_order_items', 'U') IS NOT NULL
            DROP TABLE bronze.sales_order_items;

        CREATE TABLE bronze.sales_order_items (
            order_id            VARCHAR(50),
            order_item_id       INT,
            product_id          VARCHAR(50),
            seller_id           VARCHAR(50),
            shipping_limit_date DATETIME,
            price               DECIMAL(10, 2),
            freight_value       DECIMAL(10, 2)
        );

        SET @CreatedTables += 1;

        RAISERROR('      Status : SUCCESS', 0, 1) WITH NOWAIT;
        RAISERROR('      Result : Order items table created successfully.', 0, 1) WITH NOWAIT;

        -- =============================================
        -- TABLE 5: ORDER PAYMENTS
        -- =============================================
        RAISERROR('', 0, 1) WITH NOWAIT;
        RAISERROR('[5/9] TABLE: bronze.payments_order_info', 0, 1) WITH NOWAIT;
        RAISERROR('      Action : Drop existing table if present, then create.', 0, 1) WITH NOWAIT;

        IF OBJECT_ID('bronze.payments_order_info', 'U') IS NOT NULL
            DROP TABLE bronze.payments_order_info;

        CREATE TABLE bronze.payments_order_info (
            order_id             VARCHAR(50),
            payment_sequential   INT,
            payment_type         VARCHAR(50),
            payment_installments INT,
            payment_value        DECIMAL(10, 2)
        );

        SET @CreatedTables += 1;

        RAISERROR('      Status : SUCCESS', 0, 1) WITH NOWAIT;
        RAISERROR('      Result : Order payments table created successfully.', 0, 1) WITH NOWAIT;

        -- =============================================
        -- TABLE 6: ORDER REVIEWS
        -- =============================================
        RAISERROR('', 0, 1) WITH NOWAIT;
        RAISERROR('[6/9] TABLE: bronze.sales_order_reviews', 0, 1) WITH NOWAIT;
        RAISERROR('      Action : Drop existing table if present, then create.', 0, 1) WITH NOWAIT;

        IF OBJECT_ID('bronze.sales_order_reviews', 'U') IS NOT NULL
            DROP TABLE bronze.sales_order_reviews;

        CREATE TABLE bronze.sales_order_reviews (
            review_id               VARCHAR(MAX),
            order_id                VARCHAR(MAX),
            review_score            VARCHAR(MAX),
            review_comment_title    VARCHAR(MAX),
            review_comment_message  VARCHAR(MAX),
            review_creation_date    VARCHAR(MAX),
            review_answer_timestamp VARCHAR(MAX)
        );

        SET @CreatedTables += 1;

        RAISERROR('      Status : SUCCESS', 0, 1) WITH NOWAIT;
        RAISERROR('      Result : Order reviews table created successfully.', 0, 1) WITH NOWAIT;

        -- =============================================
        -- TABLE 7: SALES ORDERS
        -- =============================================
        RAISERROR('', 0, 1) WITH NOWAIT;
        RAISERROR('[7/9] TABLE: bronze.sales_orders', 0, 1) WITH NOWAIT;
        RAISERROR('      Action : Drop existing table if present, then create.', 0, 1) WITH NOWAIT;

        IF OBJECT_ID('bronze.sales_orders', 'U') IS NOT NULL
            DROP TABLE bronze.sales_orders;

        CREATE TABLE bronze.sales_orders (
            order_id                      VARCHAR(50),
            customer_id                   VARCHAR(50),
            order_status                  VARCHAR(30),
            order_purchase_timestamp      DATETIME,
            order_approved_at             DATETIME,
            order_delivered_carrier_date  DATETIME,
            order_delivered_customer_date DATETIME,
            order_estimated_delivery_date DATETIME
        );

        SET @CreatedTables += 1;

        RAISERROR('      Status : SUCCESS', 0, 1) WITH NOWAIT;
        RAISERROR('      Result : Orders table created successfully.', 0, 1) WITH NOWAIT;

        -- =============================================
        -- TABLE 8: CATALOG PRODUCTS
        -- =============================================
        RAISERROR('', 0, 1) WITH NOWAIT;
        RAISERROR('[8/9] TABLE: bronze.catalog_products', 0, 1) WITH NOWAIT;
        RAISERROR('      Action : Drop existing table if present, then create.', 0, 1) WITH NOWAIT;

        IF OBJECT_ID('bronze.catalog_products', 'U') IS NOT NULL
            DROP TABLE bronze.catalog_products;

        CREATE TABLE bronze.catalog_products (
            product_id                 VARCHAR(50),
            product_category_name      VARCHAR(100),
            product_name_lenght        INT,
            product_description_lenght INT,
            product_photos_qty         INT,
            product_weight_g           INT,
            product_length_cm          INT,
            product_height_cm          INT,
            product_width_cm           INT
        );

        SET @CreatedTables += 1;

        RAISERROR('      Status : SUCCESS', 0, 1) WITH NOWAIT;
        RAISERROR('      Result : Products table created successfully.', 0, 1) WITH NOWAIT;

        -- =============================================
        -- TABLE 9: CATEGORY TRANSLATION
        -- =============================================
        RAISERROR('', 0, 1) WITH NOWAIT;
        RAISERROR('[9/9] TABLE: bronze.catalog_category_translation', 0, 1) WITH NOWAIT;
        RAISERROR('      Action : Drop existing table if present, then create.', 0, 1) WITH NOWAIT;

        IF OBJECT_ID('bronze.catalog_category_translation', 'U') IS NOT NULL
            DROP TABLE bronze.catalog_category_translation;

        CREATE TABLE bronze.catalog_category_translation (
            product_category_name         VARCHAR(100),
            product_category_name_english VARCHAR(100)
        );

        SET @CreatedTables += 1;

        RAISERROR('      Status : SUCCESS', 0, 1) WITH NOWAIT;
        RAISERROR('      Result : Category translation table created successfully.', 0, 1) WITH NOWAIT;

        -- =============================================
        -- COMMIT TRANSACTION
        -- =============================================
        COMMIT TRANSACTION;

        SET @EndTime = GETDATE();
        SET @Duration = DATEDIFF(SECOND, @StartTime, @EndTime);
        SET @LogTime = CONVERT(VARCHAR(19), @EndTime, 120);

        -- =============================================
        -- SUCCESS SUMMARY
        -- =============================================
        RAISERROR('', 0, 1) WITH NOWAIT;
        RAISERROR('============================================================', 0, 1) WITH NOWAIT;
        RAISERROR('                  EXECUTION SUMMARY                        ', 0, 1) WITH NOWAIT;
        RAISERROR('============================================================', 0, 1) WITH NOWAIT;

        RAISERROR('Execution Status : SUCCESS', 0, 1) WITH NOWAIT;
        RAISERROR('Database         : Olist_DWH', 0, 1) WITH NOWAIT;
        RAISERROR('Schema           : bronze', 0, 1) WITH NOWAIT;
        RAISERROR('Tables Created   : %d / %d', 0, 1, @CreatedTables, @TotalTables) WITH NOWAIT;
        RAISERROR('Duration         : %d seconds', 0, 1, @Duration) WITH NOWAIT;
        RAISERROR('End Time         : %s', 0, 1, @LogTime) WITH NOWAIT;
        RAISERROR('Transaction      : COMMITTED', 0, 1) WITH NOWAIT;

        RAISERROR('============================================================', 0, 1) WITH NOWAIT;
        RAISERROR('       BRONZE TABLE CREATION COMPLETED SUCCESSFULLY         ', 0, 1) WITH NOWAIT;
        RAISERROR('============================================================', 0, 1) WITH NOWAIT;

    END TRY

    BEGIN CATCH

        -- Capture error details before executing other statements
        SET @ErrorNumber = ERROR_NUMBER();
        SET @ErrorMessage = ERROR_MESSAGE();
        SET @ErrorLine = ERROR_LINE();
        SET @ErrorProcedure = COALESCE(ERROR_PROCEDURE(), 'Unknown');

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @EndTime = GETDATE();
        SET @Duration = DATEDIFF(SECOND, @StartTime, @EndTime);
        SET @LogTime = CONVERT(VARCHAR(19), @EndTime, 120);

        -- =============================================
        -- ERROR SUMMARY
        -- =============================================
        RAISERROR('', 0, 1) WITH NOWAIT;
        RAISERROR('============================================================', 0, 1) WITH NOWAIT;
        RAISERROR('                  EXECUTION FAILED                         ', 0, 1) WITH NOWAIT;
        RAISERROR('============================================================', 0, 1) WITH NOWAIT;

        RAISERROR('Execution Status : FAILED', 0, 1) WITH NOWAIT;
        RAISERROR('Database         : Olist_DWH', 0, 1) WITH NOWAIT;
        RAISERROR('Tables Created   : %d / %d before failure', 0, 1, @CreatedTables, @TotalTables) WITH NOWAIT;

        RAISERROR('------------------------------------------------------------', 0, 1) WITH NOWAIT;
        RAISERROR('ERROR DETAILS', 0, 1) WITH NOWAIT;
        RAISERROR('------------------------------------------------------------', 0, 1) WITH NOWAIT;

        RAISERROR('Error Number     : %d', 0, 1, @ErrorNumber) WITH NOWAIT;
        RAISERROR('Error Message    : %s', 0, 1, @ErrorMessage) WITH NOWAIT;
        RAISERROR('Error Line       : %d', 0, 1, @ErrorLine) WITH NOWAIT;
        RAISERROR('Error Procedure  : %s', 0, 1, @ErrorProcedure) WITH NOWAIT;

        RAISERROR('------------------------------------------------------------', 0, 1) WITH NOWAIT;
        RAISERROR('Duration         : %d seconds', 0, 1, @Duration) WITH NOWAIT;
        RAISERROR('End Time         : %s', 0, 1, @LogTime) WITH NOWAIT;
        RAISERROR('Transaction      : ROLLED BACK', 0, 1) WITH NOWAIT;

        RAISERROR('============================================================', 0, 1) WITH NOWAIT;
        RAISERROR('            PLEASE REVIEW THE ERROR DETAILS                ', 0, 1) WITH NOWAIT;
        RAISERROR('============================================================', 0, 1) WITH NOWAIT;

        THROW;

    END CATCH;
END;
GO

-- =============================================
-- Execute the Stored Procedure
-- =============================================
EXEC bronze.create_bronze_tables;
GO



