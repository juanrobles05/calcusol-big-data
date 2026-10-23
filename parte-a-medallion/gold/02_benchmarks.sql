-- 1. BRONZE: datos originales en CSV y conversiones de texto
SELECT
    location,
    TRY_CAST(year AS INTEGER) AS year,
    AVG(
        TRY_CAST(ALLSKY_SFC_SW_DWN AS DOUBLE)
    ) AS radiacion_promedio
FROM bronze_nasa_power
GROUP BY
    location,
    TRY_CAST(year AS INTEGER);

-- 2. SILVER: datos tipados en Parquet
SELECT
    location,
    year,
    AVG(allsky_sfc_sw_dwn) AS radiacion_promedio
FROM silver_valid
GROUP BY location, year;

-- 3. GOLD: datos agregados previamente
SELECT
    location,
    year,
    AVG(radiacion_promedio_allsky) AS radiacion_promedio
FROM gold_radiacion_anual
GROUP BY location, year;
