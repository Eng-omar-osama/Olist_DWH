
USE Olist_DWH;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

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

-- =============================================
-- APPROVED: SPELLING CORRECTIONS
-- =============================================

(N'balenario camboriu', N'balneario camboriu', 'APPROVED', N'Spelling correction'),
(N'belo horizont', N'belo horizonte', 'APPROVED', N'Spelling correction'),
(N'cascavael', N'cascavel', 'APPROVED', N'Spelling correction'),
(N'floranopolis', N'florianopolis', 'APPROVED', N'Spelling correction'),
(N'garulhos', N'guarulhos', 'APPROVED', N'Spelling correction'),
(N'ao bernardo do campo', N'sao bernardo do campo', 'APPROVED', N'Obvious spelling error'),
(N'sao bernardo do capo', N'sao bernardo do campo', 'APPROVED', N'Spelling correction'),
(N'mogi das cruses', N'mogi das cruzes', 'APPROVED', N'Spelling correction'),
(N'juzeiro do norte', N'juazeiro do norte', 'APPROVED', N'Spelling correction'),
(N'ribeirao pretp', N'ribeirao preto', 'APPROVED', N'Spelling correction'),
(N'riberao preto', N'ribeirao preto', 'APPROVED', N'Spelling correction'),
(N'robeirao preto', N'ribeirao preto', 'APPROVED', N'Spelling correction'),
(N'sando andre', N'santo andre', 'APPROVED', N'Spelling correction'),
(N'sao jose do rio pret', N'sao jose do rio preto', 'APPROVED', N'Spelling correction'),
(N'sao jose dos pinhas', N'sao jose dos pinhais', 'APPROVED', N'Spelling correction'),
(N'sao paluo', N'sao paulo', 'APPROVED', N'Spelling correction'),
(N'sao pauo', N'sao paulo', 'APPROVED', N'Spelling correction'),
(N'sao paulop', N'sao paulo', 'APPROVED', N'Spelling correction'),
(N'sao paulo sp', N'sao paulo', 'APPROVED', N'City followed by state abbreviation'),
(N'são paulo', N'sao paulo', 'APPROVED', N'Unicode accent variation'),
(N'scao jose do rio pardo', N'sao jose do rio pardo', 'APPROVED', N'Spelling correction'),
(N'tabao da serra', N'taboao da serra', 'APPROVED', N'Spelling correction'),
(N'portoferreira', N'porto ferreira', 'APPROVED', N'Spacing correction'),
(N'santa barbara d oeste', N'santa barbara d''oeste', 'APPROVED', N'Name formatting correction'),
(N'santa barbara d´oeste', N'santa barbara d''oeste', 'APPROVED', N'Apostrophe normalization'),
(N'sao miguel d''oeste', N'sao miguel do oeste', 'APPROVED', N'Name variation'),
(N'angra dos reis rj', N'angra dos reis', 'APPROVED', N'City followed by state abbreviation'),
(N'brasilia df', N'brasilia', 'APPROVED', N'City followed by federal district abbreviation'),
(N'rio de janeiro \rio de janeiro', N'rio de janeiro', 'APPROVED', N'Duplicate city name with separator'),

-- =============================================
-- REJECTED: STATE NAMES / NOT CITY VALUES
-- =============================================

(N'bahia', NULL, 'REJECTED', N'State name, not municipality'),
(N'minas gerais', NULL, 'REJECTED', N'State name, not municipality'),
(N'parana', NULL, 'REJECTED', N'State name, not municipality'),
(N'santa catarina', NULL, 'REJECTED', N'State name, not municipality'),
(N'sp', NULL, 'REJECTED', N'State abbreviation, not municipality'),

-- =============================================
-- REVIEW: DISTRICTS / AMBIGUOUS VALUES
-- =============================================

(N'centro', NULL, 'REVIEW', N'Generic neighborhood or district name'),
(N'aguas claras df', NULL, 'REVIEW', N'Administrative region; municipality identity needs verification'),
(N'gama', NULL, 'REVIEW', N'Administrative region; municipality identity needs verification'),
(N'pirituba', NULL, 'REVIEW', N'District within Sao Paulo municipality'),
(N'vicente de carvalho', NULL, 'REVIEW', N'Locality name; municipality identity needs verification'),
(N'sbc', NULL, 'REVIEW', N'Possible abbreviation for Sao Bernardo do Campo'),
(N'arrial d''ajuda (porto seguro)', NULL, 'REVIEW', N'District/locality associated with Porto Seguro'),
(N'california', NULL, 'REVIEW', N'Possible municipality; requires state/ZIP verification'),
(N'colorado', NULL, 'REVIEW', N'Ambiguous municipality name'),
(N'fronteira', NULL, 'REVIEW', N'Requires state/ZIP verification'),
(N'tocantins', NULL, 'REVIEW', N'Could refer to a municipality or state'),
(N'viana', NULL, 'REVIEW', N'Ambiguous municipality name'),
(N'sao bento', NULL, 'REVIEW', N'Ambiguous municipality name'),
(N'sao jose', NULL, 'REVIEW', N'Ambiguous municipality name'),
(N'castro pires', NULL, 'REVIEW', N'Unverified city name');


-- =============================================
-- VALIDATION
-- =============================================

IF EXISTS
(
    SELECT 1
    FROM @CityMapping
    WHERE MappingStatus = 'APPROVED'
      AND NULLIF(LTRIM(RTRIM(StandardCity)), '') IS NULL
)
    THROW 50020, 'APPROVED mapping requires StandardCity.', 1;

IF EXISTS
(
    SELECT 1
    FROM @CityMapping
    WHERE MappingStatus IN ('REJECTED', 'REVIEW')
      AND StandardCity IS NOT NULL
)
    THROW 50021, 'REJECTED and REVIEW mappings must have NULL StandardCity.', 1;

IF EXISTS
(
    SELECT SourceCity
    FROM @CityMapping
    GROUP BY SourceCity
    HAVING COUNT(*) > 1
)
    THROW 50022, 'Duplicate SourceCity values in mapping input.', 1;


-- =============================================
-- UPSERT
-- =============================================

BEGIN TRY

    BEGIN TRANSACTION;

    UPDATE Target
    SET
        Target.StandardCity = Source.StandardCity,
        Target.MappingStatus = Source.MappingStatus,
        Target.Notes = Source.Notes
    FROM silver.ref_seller_city_mapping AS Target
    INNER JOIN @CityMapping AS Source
        ON LOWER(LTRIM(RTRIM(Target.SourceCity))) =
           LOWER(LTRIM(RTRIM(Source.SourceCity)));

    PRINT 'Existing mappings updated.';

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
        WHERE LOWER(LTRIM(RTRIM(Target.SourceCity))) =
              LOWER(LTRIM(RTRIM(Source.SourceCity)))
    );

    PRINT 'New mappings inserted.';

    COMMIT TRANSACTION;

    PRINT 'Seller city mapping completed successfully.';

END TRY

BEGIN CATCH

    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;

END CATCH;


-- =============================================
-- REVIEW RESULTS
-- =============================================

SELECT
    MappingStatus,
    COUNT(*) AS MappingCount
FROM silver.ref_seller_city_mapping
GROUP BY MappingStatus
ORDER BY MappingStatus;

SELECT
    SourceCity,
    StandardCity,
    MappingStatus,
    Notes
FROM silver.ref_seller_city_mapping
ORDER BY MappingStatus, SourceCity;

GO

