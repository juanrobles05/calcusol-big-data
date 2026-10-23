-- Base de datos Athena: calcusol
CREATE EXTERNAL TABLE IF NOT EXISTS bronze_nasa_power (
    timestamp_utc        STRING,
    location             STRING,
    latitude             STRING,
    longitude            STRING,
    year                 STRING,
    ALLSKY_SFC_SW_DWN    STRING,
    CLRSKY_SFC_SW_DWN    STRING,
    ALLSKY_KT            STRING,
    T2M                  STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION 's3://calcusol-bigdata-eafit-2026-jr-jj-jv/bronze/'
TBLPROPERTIES (
    'skip.header.line.count' = '1'
);

-- Comprobamos el total de filas en la tabla
SELECT COUNT(*) AS total_filas
FROM bronze_nasa_power;

-- Inspeccionamos las primeras 10 filas de la tabla
SELECT *
FROM bronze_nasa_power
LIMIT 10;