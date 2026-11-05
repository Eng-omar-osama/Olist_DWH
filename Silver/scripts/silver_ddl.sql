/*
================================================================================
Project      : Olist Data Warehouse
Layer        : Silver
Procedure    : silver.create_silver_tables
Description  : Initializes the Silver layer by recreating source-aligned
               tables with full Unicode support and a DW creation timestamp.

Responsibilities:
    - Drops existing Silver tables if they exist.
    - Recreates all nine tables using source column definitions.
    - Uses NVARCHAR for all textual columns to preserve Unicode characters.
    - Preserves numeric and date data types.
    - Adds dwh_create_date DATETIME to every Silver table.
    - Provides real-time execution logs.
    - Handles errors and rolls back failed transactions.

Execution:
    EXEC silver.create_silver_tables;

Important Notes:
    - This procedure performs a full table recreation.
    - Existing Silver data will be lost.
================================================================================
*/

USE Olist_DWH;
GO

CREATE OR ALTER PROCEDURE silver.create_silver_tables
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @StartTime DATETIME = GETDATE(),
        @EndTime DATETIME,
        @Duration INT,
        @TotalTables INT = 9,
        @CreatedTables INT = 0,
        @LogTime VARCHAR(19);

    DECLARE
        @ErrorNumber INT,
        @ErrorMessage NVARCHAR(4000),
        @ErrorLine INT,
        @ErrorProcedure NVARCHAR(128);

    SET @LogTime = CONVERT(VARCHAR(19), @StartTime, 120);

    BEGIN TRY
        BEGIN TRANSACTION;

        RAISERROR('', 0, 1) WITH NOWAIT;
        RAISERROR('============================================================', 0, 1) WITH NOWAIT;
        RAISERROR('              OLIST DATA WAREHOUSE - SILVER LAYER           ', 0, 1) WITH NOWAIT;
        RAISERROR('                    TABLE CREATION PROCESS                 ', 0, 1) WITH NOWAIT;
        RAISERROR('============================================================', 0, 1) WITH NOWAIT;

        RAISERROR('Database       : Olist_DWH', 0, 1) WITH NOWAIT;
        RAISERROR('Schema         : silver', 0, 1) WITH NOWAIT;
        RAISERROR('Start Time     : %s', 0, 1, @LogTime) WITH NOWAIT;
        RAISERROR('Total Tables   : %d', 0, 1, @TotalTables) WITH NOWAIT;

        RAISERROR('------------------------------------------------------------', 0, 1) WITH NOWAIT;
        RAISERROR('STATUS         : INITIALIZING', 0, 1) WITH NOWAIT;
        RAISERROR('------------------------------------------------------------', 0, 1) WITH NOWAIT;

        -- 1. CRM CUSTOMERS
        RAISERROR('[1/9] TABLE: silver.crm_cust_info', 0, 1) WITH NOWAIT;

        IF OBJECT_ID('silver.crm_cust_info', 'U') IS NOT NULL
            DROP TABLE silver.crm_cust_info;

        CREATE TABLE silver.crm_cust_info
        (
            customer_id              NVARCHAR(50),
            customer_unique_id       NVARCHAR(50),
            customer_zip_code_prefix NVARCHAR(10),
            customer_city            NVARCHAR(100),
            customer_state           NVARCHAR(5),
            dwh_create_date          DATETIME
        );

        SET @CreatedTables += 1;
        RAISERROR('      Status : SUCCESS', 0, 1) WITH NOWAIT;

        -- 2. CRM GEOLOCATION
        RAISERROR('[2/9] TABLE: silver.crm_geolocation_info', 0, 1) WITH NOWAIT;

        IF OBJECT_ID('silver.crm_geolocation_info', 'U') IS NOT NULL
            DROP TABLE silver.crm_geolocation_info;

        CREATE TABLE silver.crm_geolocation_info
        (
            geolocation_zip_code_prefix NVARCHAR(10),
            geolocation_lat             DECIMAL(10, 6),
            geolocation_lng             DECIMAL(10, 6),
            geolocation_city            NVARCHAR(100),
            geolocation_state           NVARCHAR(5),
            dwh_create_date             DATETIME
        );

        SET @CreatedTables += 1;
        RAISERROR('      Status : SUCCESS', 0, 1) WITH NOWAIT;

        -- 3. CRM SELLERS
        RAISERROR('[3/9] TABLE: silver.crm_seller_info', 0, 1) WITH NOWAIT;

        IF OBJECT_ID('silver.crm_seller_info', 'U') IS NOT NULL
            DROP TABLE silver.crm_seller_info;

        CREATE TABLE silver.crm_seller_info
        (
            seller_id              NVARCHAR(50),
            seller_zip_code_prefix NVARCHAR(10),
            seller_city            NVARCHAR(100),
            seller_state           NVARCHAR(5),
            dwh_create_date        DATETIME
        );

        SET @CreatedTables += 1;
        RAISERROR('      Status : SUCCESS', 0, 1) WITH NOWAIT;

        -- 4. SALES ORDER ITEMS
        RAISERROR('[4/9] TABLE: silver.sales_order_items', 0, 1) WITH NOWAIT;

        IF OBJECT_ID('silver.sales_order_items', 'U') IS NOT NULL
            DROP TABLE silver.sales_order_items;

        CREATE TABLE silver.sales_order_items
        (
            order_id            NVARCHAR(50),
            order_item_id       INT,
            product_id          NVARCHAR(50),
            seller_id           NVARCHAR(50),
            shipping_limit_date DATETIME,
            price               DECIMAL(10, 2),
            freight_value       DECIMAL(10, 2),
            dwh_create_date     DATETIME
        );

        SET @CreatedTables += 1;
        RAISERROR('      Status : SUCCESS', 0, 1) WITH NOWAIT;

        -- 5. ORDER PAYMENTS
        RAISERROR('[5/9] TABLE: silver.payments_order_info', 0, 1) WITH NOWAIT;

        IF OBJECT_ID('silver.payments_order_info', 'U') IS NOT NULL
            DROP TABLE silver.payments_order_info;

        CREATE TABLE silver.payments_order_info
        (
            order_id             NVARCHAR(50),
            payment_sequential   INT,
            payment_type         NVARCHAR(50),
            payment_installments INT,
            payment_value        DECIMAL(10, 2),
            dwh_create_date      DATETIME
        );

        SET @CreatedTables += 1;
        RAISERROR('      Status : SUCCESS', 0, 1) WITH NOWAIT;

        -- 6. ORDER REVIEWS
        RAISERROR('[6/9] TABLE: silver.sales_order_reviews', 0, 1) WITH NOWAIT;

        IF OBJECT_ID('silver.sales_order_reviews', 'U') IS NOT NULL
            DROP TABLE silver.sales_order_reviews;

        CREATE TABLE silver.sales_order_reviews
        (
            review_id               NVARCHAR(MAX),
            order_id                NVARCHAR(MAX),
            review_score            NVARCHAR(MAX),
            review_comment_title    NVARCHAR(MAX),
            review_comment_message  NVARCHAR(MAX),
            review_creation_date    NVARCHAR(MAX),
            review_answer_timestamp NVARCHAR(MAX),
            dwh_create_date         DATETIME
        );

        SET @CreatedTables += 1;
        RAISERROR('      Status : SUCCESS', 0, 1) WITH NOWAIT;

        -- 7. SALES ORDERS
        RAISERROR('[7/9] TABLE: silver.sales_orders', 0, 1) WITH NOWAIT;

        IF OBJECT_ID('silver.sales_orders', 'U') IS NOT NULL
            DROP TABLE silver.sales_orders;

        CREATE TABLE silver.sales_orders
        (
            order_id                      NVARCHAR(50),
            customer_id                   NVARCHAR(50),
            order_status                  NVARCHAR(30),
            order_purchase_timestamp      DATETIME,
            order_approved_at             DATETIME,
            order_delivered_carrier_date  DATETIME,
            order_delivered_customer_date DATETIME,
            order_estimated_delivery_date DATETIME,
            dwh_create_date               DATETIME
        );

        SET @CreatedTables += 1;
        RAISERROR('      Status : SUCCESS', 0, 1) WITH NOWAIT;

        -- 8. CATALOG PRODUCTS
        RAISERROR('[8/9] TABLE: silver.catalog_products', 0, 1) WITH NOWAIT;

        IF OBJECT_ID('silver.catalog_products', 'U') IS NOT NULL
            DROP TABLE silver.catalog_products;

        CREATE TABLE silver.catalog_products
        (
            product_id                 NVARCHAR(50),
            product_category_name      NVARCHAR(100),
            product_name_lenght        INT,
            product_description_lenght INT,
            product_photos_qty         INT,
            product_weight_g           INT,
            product_length_cm          INT,
            product_height_cm          INT,
            product_width_cm           INT,
            dwh_create_date            DATETIME
        );

        SET @CreatedTables += 1;
        RAISERROR('      Status : SUCCESS', 0, 1) WITH NOWAIT;

        -- 9. CATEGORY TRANSLATION
        RAISERROR('[9/9] TABLE: silver.catalog_category_translation', 0, 1) WITH NOWAIT;

        IF OBJECT_ID('silver.catalog_category_translation', 'U') IS NOT NULL
            DROP TABLE silver.catalog_category_translation;

        CREATE TABLE silver.catalog_category_translation
        (
            product_category_name         NVARCHAR(100),
            product_category_name_english NVARCHAR(100),
            dwh_create_date               DATETIME
        );

        SET @CreatedTables += 1;
        RAISERROR('      Status : SUCCESS', 0, 1) WITH NOWAIT;

        COMMIT TRANSACTION;

        SET @EndTime = GETDATE();
        SET @Duration = DATEDIFF(SECOND, @StartTime, @EndTime);
        SET @LogTime = CONVERT(VARCHAR(19), @EndTime, 120);

        RAISERROR('', 0, 1) WITH NOWAIT;
        RAISERROR('============================================================', 0, 1) WITH NOWAIT;
        RAISERROR('                  EXECUTION SUMMARY                        ', 0, 1) WITH NOWAIT;
        RAISERROR('============================================================', 0, 1) WITH NOWAIT;

        RAISERROR('Execution Status : SUCCESS', 0, 1) WITH NOWAIT;
        RAISERROR('Database         : Olist_DWH', 0, 1) WITH NOWAIT;
        RAISERROR('Schema           : silver', 0, 1) WITH NOWAIT;
        RAISERROR('Tables Created   : %d / %d', 0, 1, @CreatedTables, @TotalTables) WITH NOWAIT;
        RAISERROR('Duration         : %d seconds', 0, 1, @Duration) WITH NOWAIT;
        RAISERROR('End Time         : %s', 0, 1, @LogTime) WITH NOWAIT;

        RAISERROR('============================================================', 0, 1) WITH NOWAIT;
        RAISERROR('       SILVER TABLE CREATION COMPLETED SUCCESSFULLY         ', 0, 1) WITH NOWAIT;
        RAISERROR('============================================================', 0, 1) WITH NOWAIT;

    END TRY
    BEGIN CATCH
        SET @ErrorNumber = ERROR_NUMBER();
        SET @ErrorMessage = ERROR_MESSAGE();
        SET @ErrorLine = ERROR_LINE();
        SET @ErrorProcedure = COALESCE(ERROR_PROCEDURE(), 'Unknown');

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @EndTime = GETDATE();
        SET @Duration = DATEDIFF(SECOND, @StartTime, @EndTime);
        SET @LogTime = CONVERT(VARCHAR(19), @EndTime, 120);

        RAISERROR('============================================================', 0, 1) WITH NOWAIT;
        RAISERROR('                  EXECUTION FAILED                         ', 0, 1) WITH NOWAIT;
        RAISERROR('============================================================', 0, 1) WITH NOWAIT;

        RAISERROR('Execution Status : FAILED', 0, 1) WITH NOWAIT;
        RAISERROR('Tables Created   : %d / %d before failure', 0, 1, @CreatedTables, @TotalTables) WITH NOWAIT;
        RAISERROR('Error Number     : %d', 0, 1, @ErrorNumber) WITH NOWAIT;
        RAISERROR('Error Message    : %s', 0, 1, @ErrorMessage) WITH NOWAIT;
        RAISERROR('Error Line       : %d', 0, 1, @ErrorLine) WITH NOWAIT;
        RAISERROR('Error Procedure  : %s', 0, 1, @ErrorProcedure) WITH NOWAIT;
        RAISERROR('Duration         : %d seconds', 0, 1, @Duration) WITH NOWAIT;
        RAISERROR('End Time         : %s', 0, 1, @LogTime) WITH NOWAIT;
        RAISERROR('Transaction      : ROLLED BACK', 0, 1) WITH NOWAIT;

        RAISERROR('============================================================', 0, 1) WITH NOWAIT;
        THROW;
    END CATCH;
END;
GO

EXEC silver.create_silver_tables;
GO
