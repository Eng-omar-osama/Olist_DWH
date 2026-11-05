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


INSERT INTO silver.ref_seller_city_mapping
(
    SourceCity,
    StandardCity,
    MappingStatus,
    Notes
)
VALUES
('andira-pr', 'andira', 'APPROVED', 'City name followed by matching state abbreviation'),
('auriflama/sp', 'auriflama', 'APPROVED', 'City name followed by matching state abbreviation'),
('barbacena/ minas gerais', 'barbacena', 'APPROVED', 'City name followed by matching state name'),
('cariacica / es', 'cariacica', 'APPROVED', 'City name followed by matching state abbreviation'),
('lages - sc', 'lages', 'APPROVED', 'City name followed by matching state abbreviation'),
('mogi das cruzes / sp', 'mogi das cruzes', 'APPROVED', 'City name followed by matching state abbreviation'),
('novo hamburgo, rio grande do sul, brasil', 'novo hamburgo', 'APPROVED', 'City, state and country format'),
('pinhais/pr', 'pinhais', 'APPROVED', 'City name followed by matching state abbreviation'),
('rio de janeiro / rio de janeiro', 'rio de janeiro', 'APPROVED', 'Repeated city name'),
('rio de janeiro, rio de janeiro, brasil', 'rio de janeiro', 'APPROVED', 'City, state and country format'),
('sao paulo - sp', 'sao paulo', 'APPROVED', 'City name followed by matching state abbreviation'),
('sao paulo / sao paulo', 'sao paulo', 'APPROVED', 'Repeated city name'),
('sao sebastiao da grama/sp', 'sao sebastiao da grama', 'APPROVED', 'City name followed by matching state abbreviation'),

('carapicuiba / sao paulo', NULL, 'REVIEW', 'Verify city and state interpretation'),
('jacarei / sao paulo', NULL, 'REVIEW', 'Verify city and state interpretation'),
('maua/sao paulo', NULL, 'REVIEW', 'Verify city and state interpretation'),
('ribeirao preto / sao paulo', NULL, 'REVIEW', 'Verify city and state interpretation'),
('santo andre/sao paulo', NULL, 'REVIEW', 'Verify city and state interpretation'),
('sbc/sp', NULL, 'REVIEW', 'Possible abbreviation; requires confirmation'),
('sp / sp', NULL, 'REVIEW', 'Cannot identify a reliable city name'),

('04482255', NULL, 'REJECTED', 'Numeric value, not a city name'),
('vendas@creditparts.com.br', NULL, 'REJECTED', 'Email address, not a city name');
