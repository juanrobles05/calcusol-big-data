-- Creamos la tabla silver_valid para almacenar los registros válidos.
CREATE TABLE silver_valid
WITH (
    table_type = 'ICEBERG',
    is_external = false,
    format = 'PARQUET',
    location = 's3://calcusol-bigdata-eafit-2026-jr-jj-jv/iceberg/silver_valid_v2/'
)
AS
SELECT
    TRIM(timestamp_utc) AS timestamp_utc,
    TRIM(location) AS location,
    TRY_CAST(latitude AS DOUBLE) AS latitude,
    TRY_CAST(longitude AS DOUBLE) AS longitude,
    TRY_CAST(year AS INTEGER) AS year,
    TRY_CAST(ALLSKY_SFC_SW_DWN AS DOUBLE) AS allsky_sfc_sw_dwn,
    TRY_CAST(CLRSKY_SFC_SW_DWN AS DOUBLE) AS clrsky_sfc_sw_dwn,
    CASE
        WHEN TRY_CAST(ALLSKY_KT AS DOUBLE) = -999 THEN NULL
        ELSE TRY_CAST(ALLSKY_KT AS DOUBLE)
    END AS allsky_kt,
    TRY_CAST(T2M AS DOUBLE) AS t2m
FROM bronze_nasa_power
WHERE
    timestamp_utc IS NOT NULL
    AND TRIM(timestamp_utc) <> ''
    AND location IS NOT NULL
    AND TRIM(location) <> ''
    AND TRY_CAST(latitude AS DOUBLE) BETWEEN -90 AND 90
    AND TRY_CAST(longitude AS DOUBLE) BETWEEN -180 AND 180
    AND TRY_CAST(ALLSKY_SFC_SW_DWN AS DOUBLE) >= 0
    AND TRY_CAST(CLRSKY_SFC_SW_DWN AS DOUBLE) >= 0
    AND TRY_CAST(T2M AS DOUBLE) BETWEEN -50 AND 60;

SELECT
    COUNT(*) AS total_validos,
    COUNT_IF(allsky_kt IS NULL) AS kt_nulos,
    COUNT_IF(allsky_sfc_sw_dwn < 0) AS radiacion_negativa,
    COUNT_IF(t2m NOT BETWEEN -50 AND 60) AS temperatura_fuera_rango
FROM silver_valid;

-- Inspección de registros tipados
SELECT *
FROM silver_valid
LIMIT 10;
