USE Olist_DWH;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

-- =====================================================
-- 1. PROFILE SUSPICIOUS SELLER CITY VALUES
-- =====================================================

PRINT 'Step 1: Profiling suspicious seller city values...';

SELECT
    seller_city,
    COUNT(*) AS Occurrences
FROM bronze.crm_seller_info
WHERE seller_city IS NOT NULL
  AND
  (
      seller_city LIKE '%[0-9]%'
      OR seller_city LIKE '%@%'
      OR seller_city LIKE '%,%'
      OR seller_city LIKE '%/%'
      OR seller_city LIKE '%-%'
  )
GROUP BY seller_city
ORDER BY Occurrences DESC, seller_city;


-- =====================================================
-- 2. INVESTIGATE SUSPICIOUS CITY DETAILS
-- =====================================================

PRINT 'Step 2: Investigating suspicious city details...';

SELECT
    seller_city,
    seller_state,
    seller_zip_code_prefix,
    COUNT(*) AS SellerCount
FROM bronze.crm_seller_info
WHERE seller_city IN
(
    'sao paulo - sp',
    'andira-pr',
    'auriflama/sp',
    'barbacena/ minas gerais',
    'carapicuiba / sao paulo',
    'cariacica / es',
    'jacarei / sao paulo',
    'lages - sc',
    'maua/sao paulo',
    'mogi das cruzes / sp',
    'novo hamburgo, rio grande do sul, brasil',
    'pinhais/pr',
    'ribeirao preto / sao paulo',
    'rio de janeiro / rio de janeiro',
    'rio de janeiro, rio de janeiro, brasil',
    'santo andre/sao paulo',
    'sao paulo / sao paulo',
    'sao sebastiao da grama/sp',
    'sbc/sp',
    'sp / sp',
    '04482255',
    'vendas@creditparts.com.br'
)
GROUP BY
    seller_city,
    seller_state,
    seller_zip_code_prefix
ORDER BY
    seller_city,
    seller_state,
    seller_zip_code_prefix;


-- =====================================================
-- 3. PREPARE CITY MAPPING DATA
-- =====================================================

PRINT 'Step 3: Preparing seller city mappings...';

DECLARE @CityMapping TABLE
(
    SourceCity NVARCHAR(100) NOT NULL,
    StandardCity NVARCHAR(100) NULL,
    MappingStatus VARCHAR(20) NOT NULL,
    Notes NVARCHAR(500) NULL
);

INSERT INTO @CityMapping
(
    SourceCity,
    StandardCity,
    MappingStatus,
    Notes
)
VALUES

-- -----------------------------------------------------
-- APPROVED: Confirmed city name normalization
-- -----------------------------------------------------

(N'andira-pr', N'andira', 'APPROVED',
 N'City name followed by matching state abbreviation'),

(N'auriflama/sp', N'auriflama', 'APPROVED',
 N'City name followed by matching state abbreviation'),

(N'barbacena/ minas gerais', N'barbacena', 'APPROVED',
 N'City name followed by matching state name'),

(N'cariacica / es', N'cariacica', 'APPROVED',
 N'City name followed by matching state abbreviation'),

(N'lages - sc', N'lages', 'APPROVED',
 N'City name followed by matching state abbreviation'),

(N'mogi das cruzes / sp', N'mogi das cruzes', 'APPROVED',
 N'City name followed by matching state abbreviation'),

(N'novo hamburgo, rio grande do sul, brasil', N'novo hamburgo', 'APPROVED',
 N'City, state and country format'),

(N'pinhais/pr', N'pinhais', 'APPROVED',
 N'City name followed by matching state abbreviation'),

(N'rio de janeiro / rio de janeiro', N'rio de janeiro', 'APPROVED',
 N'Repeated city name'),

(N'rio de janeiro, rio de janeiro, brasil', N'rio de janeiro', 'APPROVED',
 N'City, state and country format'),

(N'sao paulo - sp', N'sao paulo', 'APPROVED',
 N'City name followed by matching state abbreviation'),

(N'sao paulo / sao paulo', N'sao paulo', 'APPROVED',
 N'Repeated city name'),

(N'sao sebastiao da grama/sp', N'sao sebastiao da grama', 'APPROVED',
 N'City name followed by matching state abbreviation'),


-- -----------------------------------------------------
-- REVIEW: City interpretation requires verification
-- -----------------------------------------------------

(N'carapicuiba / sao paulo', NULL, 'REVIEW',
 N'Verify city and state interpretation'),

(N'jacarei / sao paulo', NULL, 'REVIEW',
 N'Verify city and state interpretation'),

(N'maua/sao paulo', NULL, 'REVIEW',
 N'Verify city and state interpretation'),

(N'ribeirao preto / sao paulo', NULL, 'REVIEW',
 N'Verify city and state interpretation'),

(N'santo andre/sao paulo', NULL, 'REVIEW',
 N'Verify city and state interpretation'),

(N'sbc/sp', NULL, 'REVIEW',
 N'Possible abbreviation; requires confirmation'),

(N'sp / sp', NULL, 'REVIEW',
 N'Cannot identify a reliable city name'),


-- -----------------------------------------------------
-- REJECTED: Invalid city values
-- -----------------------------------------------------

(N'04482255', NULL, 'REJECTED',
 N'Numeric value, not a city name'),

(N'vendas@creditparts.com.br', NULL, 'REJECTED',
 N'Email address, not a city name');


-- =====================================================
-- 4. INSERT / UPDATE CITY MAPPING TABLE
-- =====================================================

PRINT 'Step 4: Updating city mapping reference table...';

BEGIN TRY

    BEGIN TRANSACTION;

    -- Update existing mappings
    UPDATE Target
    SET
        Target.StandardCity = Source.StandardCity,
        Target.MappingStatus = Source.MappingStatus,
        Target.Notes = Source.Notes
    FROM silver.ref_seller_city_mapping AS Target
    INNER JOIN @CityMapping AS Source
        ON LOWER(TRIM(Target.SourceCity)) =
           LOWER(TRIM(Source.SourceCity));

    PRINT 'Existing mappings updated.';

    -- Insert mappings that do not exist
    INSERT INTO silver.ref_seller_city_mapping
    (
        SourceCity,
        StandardCity,
        MappingStatus,
        Notes
    )
    SELECT
        Source.SourceCity,
        Source.StandardCity,
        Source.MappingStatus,
        Source.Notes
    FROM @CityMapping AS Source
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM silver.ref_seller_city_mapping AS Target
        WHERE LOWER(TRIM(Target.SourceCity)) =
              LOWER(TRIM(Source.SourceCity))
    );

    PRINT 'New mappings inserted.';

    COMMIT TRANSACTION;

END TRY
BEGIN CATCH

    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    PRINT 'Error updating city mapping table.';
    PRINT ERROR_MESSAGE();

    THROW;

END CATCH;


-- =====================================================
-- 5. REVIEW FINAL CITY MAPPING
-- =====================================================

PRINT 'Step 5: Reviewing final city mapping results...';

SELECT
    SourceCity,
    StandardCity,
    MappingStatus,
    Notes,
    CreatedAt
FROM silver.ref_seller_city_mapping
WHERE SourceCity IN
(
    SELECT SourceCity
    FROM @CityMapping
)
ORDER BY
    MappingStatus,
    SourceCity;

GO
