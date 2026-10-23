-- Clave lógica: ubicación + timestamp UTC.

SELECT
    COUNT(*) AS total_filas,
    COUNT(
        DISTINCT CONCAT(
            TRIM(location),
            '|',
            TRIM(timestamp_utc)
        )
    ) AS claves_unicas,
    COUNT(*) - COUNT(
        DISTINCT CONCAT(
            TRIM(location),
            '|',
            TRIM(timestamp_utc)
        )
    ) AS posibles_duplicados
FROM bronze_nasa_power;

-- Detalle de claves repetidas, si existen.
SELECT
    TRIM(location) AS location,
    TRIM(timestamp_utc) AS timestamp_utc,
    COUNT(*) AS repeticiones
FROM bronze_nasa_power
GROUP BY
    TRIM(location),
    TRIM(timestamp_utc)
HAVING COUNT(*) > 1
ORDER BY repeticiones DESC;
