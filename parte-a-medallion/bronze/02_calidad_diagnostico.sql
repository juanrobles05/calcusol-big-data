-- Identifica campos vacíos, conversiones inválidas y valores fuera de rango.
-- ALLSKY_KT = -999 se trata como valor centinela y se normaliza en Silver.

SELECT
    COUNT(*) AS total_filas,

    COUNT_IF(
        timestamp_utc IS NULL OR TRIM(timestamp_utc) = ''
    ) AS timestamp_vacio,

    COUNT_IF(
        location IS NULL OR TRIM(location) = ''
    ) AS location_vacio,

    COUNT_IF(
        TRY_CAST(latitude AS DOUBLE) IS NULL
        OR TRY_CAST(latitude AS DOUBLE) NOT BETWEEN -90 AND 90
    ) AS latitud_invalida,

    COUNT_IF(
        TRY_CAST(longitude AS DOUBLE) IS NULL
        OR TRY_CAST(longitude AS DOUBLE) NOT BETWEEN -180 AND 180
    ) AS longitud_invalida,

    COUNT_IF(
        TRY_CAST(ALLSKY_SFC_SW_DWN AS DOUBLE) IS NULL
        OR TRY_CAST(ALLSKY_SFC_SW_DWN AS DOUBLE) < 0
    ) AS radiacion_allsky_invalida,

    COUNT_IF(
        TRY_CAST(CLRSKY_SFC_SW_DWN AS DOUBLE) IS NULL
        OR TRY_CAST(CLRSKY_SFC_SW_DWN AS DOUBLE) < 0
    ) AS radiacion_clrsky_invalida,

    COUNT_IF(
        TRY_CAST(T2M AS DOUBLE) IS NULL
        OR TRY_CAST(T2M AS DOUBLE) NOT BETWEEN -50 AND 60
    ) AS temperatura_invalida,

    COUNT_IF(
        TRY_CAST(ALLSKY_KT AS DOUBLE) = -999
    ) AS kt_sentinel_menos_999

FROM bronze_nasa_power;
