
-- Create the database if it does not exist
IF NOT EXISTS (
    SELECT 1
    FROM sys.databases
    WHERE name = 'Olist_DWH'
)
BEGIN
    CREATE DATABASE Olist_DWH;
END;
GO

-- Switch to the target database
USE Olist_DWH;
GO

-- Create Bronze schema if it does not exist
IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = 'bronze'
)
BEGIN
    EXEC('CREATE SCHEMA bronze');
END;
GO

-- Create Silver schema if it does not exist
IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = 'silver'
)
BEGIN
    EXEC('CREATE SCHEMA silver');
END;
GO

-- Create Gold schema if it does not exist
IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = 'gold'
)
BEGIN
    EXEC('CREATE SCHEMA gold');
END;
GO

