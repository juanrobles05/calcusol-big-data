-- Debe cumplirse: Bronze = Silver válidos + Silver rechazados.

SELECT
    (SELECT COUNT(*) FROM bronze_nasa_power) AS bronze_total,
    (SELECT COUNT(*) FROM silver_valid) AS silver_valid_total,
    (SELECT COUNT(*) FROM silver_rejected) AS silver_rejected_total,
    (SELECT COUNT(*) FROM silver_valid)
      + (SELECT COUNT(*) FROM silver_rejected) AS silver_suma,
    (SELECT COUNT(*) FROM bronze_nasa_power)
      - (SELECT COUNT(*) FROM silver_valid)
      - (SELECT COUNT(*) FROM silver_rejected) AS diferencia;
