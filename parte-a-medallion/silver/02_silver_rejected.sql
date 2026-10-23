-- Creamos la tabla silver_rejected para almacenar los registros rechazados.
CREATE TABLE silver_rejected
WITH (
    table_type = 'ICEBERG',
    is_external = false,
    format = 'PARQUET',
    location = 's3://calcusol-bigdata-eafit-2026-jr-jj-jv/iceberg/silver_rejected_v2/'
)
AS
SELECT
    timestamp_utc,
    location,
    latitude,
    longitude,
    year,
    ALLSKY_SFC_SW_DWN,
    CLRSKY_SFC_SW_DWN,
    ALLSKY_KT,
    T2M,
    CONCAT_WS(
        '; ',
        IF(timestamp_utc IS NULL OR TRIM(timestamp_utc) = '',
           'timestamp vacío', NULL),
        IF(location IS NULL OR TRIM(location) = '',
           'ubicación vacía', NULL),
        IF(TRY_CAST(latitude AS DOUBLE) IS NULL
           OR TRY_CAST(latitude AS DOUBLE) NOT BETWEEN -90 AND 90,
           'latitud inválida', NULL),
        IF(TRY_CAST(longitude AS DOUBLE) IS NULL
           OR TRY_CAST(longitude AS DOUBLE) NOT BETWEEN -180 AND 180,
           'longitud inválida', NULL),
        IF(TRY_CAST(ALLSKY_SFC_SW_DWN AS DOUBLE) IS NULL
           OR TRY_CAST(ALLSKY_SFC_SW_DWN AS DOUBLE) < 0,
           'radiación ALLSKY inválida', NULL),
        IF(TRY_CAST(CLRSKY_SFC_SW_DWN AS DOUBLE) IS NULL
           OR TRY_CAST(CLRSKY_SFC_SW_DWN AS DOUBLE) < 0,
           'radiación CLRSKY inválida', NULL),
        IF(TRY_CAST(T2M AS DOUBLE) IS NULL
           OR TRY_CAST(T2M AS DOUBLE) NOT BETWEEN -50 AND 60,
           'temperatura inválida', NULL)
    ) AS rejection_reason
FROM bronze_nasa_power
WHERE
    timestamp_utc IS NULL
    OR TRIM(timestamp_utc) = ''
    OR location IS NULL
    OR TRIM(location) = ''
    OR TRY_CAST(latitude AS DOUBLE) IS NULL
    OR TRY_CAST(latitude AS DOUBLE) NOT BETWEEN -90 AND 90
    OR TRY_CAST(longitude AS DOUBLE) IS NULL
    OR TRY_CAST(longitude AS DOUBLE) NOT BETWEEN -180 AND 180
    OR TRY_CAST(ALLSKY_SFC_SW_DWN AS DOUBLE) IS NULL
    OR TRY_CAST(ALLSKY_SFC_SW_DWN AS DOUBLE) < 0
    OR TRY_CAST(CLRSKY_SFC_SW_DWN AS DOUBLE) IS NULL
    OR TRY_CAST(CLRSKY_SFC_SW_DWN AS DOUBLE) < 0
    OR TRY_CAST(T2M AS DOUBLE) IS NULL
    OR TRY_CAST(T2M AS DOUBLE) NOT BETWEEN -50 AND 60;

-- rejection_reason conserva el motivo del rechazo.
SELECT
    COUNT(*) AS total_rechazados
FROM silver_rejected;

-- Ver los motivos de rechazo, si existen.
SELECT
    rejection_reason,
    COUNT(*) AS cantidad
FROM silver_rejected
GROUP BY rejection_reason
ORDER BY cantidad DESC;

-- Inspeccionar ejemplos, si existen.
SELECT *
FROM silver_rejected
LIMIT 10;
