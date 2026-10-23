-- Creamos la tabla gold_radiacion_anual a partir de la tabla silver_valid, agregando los datos por ubicación y año.
CREATE TABLE gold_radiacion_anual
WITH (
    table_type = 'ICEBERG',
    is_external = false,
    format = 'PARQUET',
    location = 's3://calcusol-bigdata-eafit-2026-jr-jj-jv/iceberg/gold_radiacion_anual/'
)
AS
SELECT
    location,
    year,
    COUNT(*) AS total_registros,
    COUNT(allsky_sfc_sw_dwn) AS registros_radiacion,
    AVG(allsky_sfc_sw_dwn) AS radiacion_promedio_allsky,
    AVG(clrsky_sfc_sw_dwn) AS radiacion_promedio_cielo_claro,
    AVG(allsky_kt) AS indice_claridad_promedio,
    AVG(t2m) AS temperatura_promedio
FROM silver_valid
GROUP BY location, year;

-- Verificar cantidad de registros agregados
SELECT COUNT(*) AS total_filas_gold
FROM gold_radiacion_anual;

-- Verificar ubicaciones cubiertas
SELECT COUNT(DISTINCT location) AS total_ubicaciones
FROM gold_radiacion_anual;

-- Consultar radiación promedio por ubicación y año
SELECT
    location,
    year,
    total_registros,
    registros_radiacion,
    radiacion_promedio_allsky,
    radiacion_promedio_cielo_claro,
    indice_claridad_promedio,
    temperatura_promedio
FROM gold_radiacion_anual
ORDER BY location, year;

-- Comparar las ubicaciones por radiación promedio
-- durante todo el período disponible.
SELECT
    location,
    AVG(radiacion_promedio_allsky) AS radiacion_media_periodo
FROM gold_radiacion_anual
GROUP BY location
ORDER BY radiacion_media_periodo DESC;
