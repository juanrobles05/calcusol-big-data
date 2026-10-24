# Resultados de la Parte A — Calcusol

## 1. Descripción del dataset

El conjunto de datos utilizado en el proyecto Calcusol proviene de **NASA POWER** y contiene información meteorológica y de radiación solar para 16 ubicaciones aproximadas de Colombia durante el período 2017–2024. Estos datos permiten realizar comparaciones iniciales del recurso solar entre ubicaciones y años como parte del análisis de viabilidad de instalaciones fotovoltaicas residenciales.

**Características del dataset:**

- **Fuente:** NASA POWER.
- **Período:** 1 de enero de 2017 al 31 de diciembre de 2024.
- **Frecuencia:** horaria.
- **Ubicaciones:** 16.
- **Registros:** 1.122.048 filas.
- **Número de columnas:** 9.
- **Tamaño del archivo CSV:** 80.2MB.
- **Zona horaria:** UTC.

Las variables del conjunto de datos son:

| Variable | Descripción |
|---|---|
| `timestamp_utc` | Fecha y hora de la observación en UTC. |
| `location` | Identificador de la ubicación geográfica. |
| `latitude` | Latitud de la ubicación. |
| `longitude` | Longitud de la ubicación. |
| `year` | Año de la observación. |
| `ALLSKY_SFC_SW_DWN` | Radiación solar incidente en superficie bajo todas las condiciones de cielo. |
| `CLRSKY_SFC_SW_DWN` | Radiación solar incidente en superficie en condiciones de cielo despejado. |
| `ALLSKY_KT` | Índice de claridad atmosférica. |
| `T2M` | Temperatura del aire a 2 metros, en °C. |

## 2. Capa Bronze

El archivo CSV original se almacenó en Amazon S3 en la ruta:

`s3://calcusol-bigdata-eafit-2026-jr-jj-jv/bronze/`

Posteriormente, se creó en Amazon Athena la tabla externa `bronze_nasa_power`, con las nueve columnas definidas como `STRING`. Esta decisión permite conservar los valores originales y realizar las conversiones de tipos de datos durante las verificaciones y transformaciones posteriores.

La tabla Bronze contiene **1.122.048 registros**, correspondientes a las 16 ubicaciones y los ocho años del período analizado.

## 3. Hallazgos de calidad de los datos

Se ejecutaron consultas SQL en Athena para identificar campos vacíos, coordenadas fuera de rango, valores negativos de radiación, temperaturas fuera del rango definido, valores centinela y posibles duplicados.

Los resultados fueron los siguientes:

| Hallazgo | Cantidad | Interpretación |
|---|---:|---|
| Registros totales en Bronze | 1.122.048 | Total de observaciones analizadas. |
| Valores `-999` en `ALLSKY_KT` | 550.751 | Valor centinela que debe tratarse como dato no disponible. |
| Duplicados por ubicación y timestamp UTC | 0 | No se encontraron claves repetidas en la combinación evaluada. |
| Campos vacíos en las verificaciones realizadas | 0 | No se encontraron valores vacíos en los campos revisados. |
| Coordenadas fuera de rango | 0 | No se identificaron latitudes ni longitudes fuera de sus rangos válidos. |
| Radiaciones negativas | 0 | No se encontraron valores negativos en las variables de radiación revisadas. |
| Temperaturas fuera del rango definido | 0 | No se encontraron valores de `T2M` fuera del intervalo de -50 a 60 °C. |

El principal hallazgo fue la presencia de **550.751 valores `-999` en `ALLSKY_KT`**, equivalentes aproximadamente al 49,08 % de las filas. Este valor se identificó como un **valor centinela**, es decir, un valor especial utilizado para representar información no disponible, y no como una medición real del índice de claridad atmosférica. Por esta razón, interpretarlo como un valor numérico válido habría afectado los cálculos estadísticos, especialmente el promedio de `ALLSKY_KT`.

La revisión de los datos mostró que los valores `-999` se presentaban principalmente durante horas con radiación solar igual a cero. Por tanto, se decidió conservar las observaciones y transformar únicamente el valor centinela de `ALLSKY_KT` a `NULL` durante la transformación a Silver.

La decisión se tomó por las siguientes razones:

1. **Evitar distorsiones estadísticas:** si los valores `-999` se trataran como mediciones reales, reducirían artificialmente el promedio del índice de claridad y producirían resultados engañosos.
2. **Conservar información útil:** no se rechazó la fila completa porque las demás variables, como la fecha, la ubicación, la radiación y la temperatura, podían seguir siendo válidas para otros análisis.
3. **Representar correctamente la ausencia de información:** `NULL` indica que el valor del índice no está disponible y permite que las funciones de agregación, como `AVG`, excluyan estos valores del cálculo del promedio.
4. **Mantener la trazabilidad de la transformación:** el dato original se conserva en Bronze, mientras que Silver contiene la versión depurada para el análisis.

En consecuencia, los 550.751 valores centinela no se contabilizaron como filas rechazadas. Se normalizaron a `NULL` en `silver_valid`, por lo que el número de registros válidos se mantuvo en 1.122.048 y el número de registros rechazados fue cero.

Esta decisión permite conservar la mayor cantidad posible de información útil y evita que valores que representan datos no disponibles afecten los indicadores calculados en la capa Gold.


## 4. Capa Silver: reglas de calidad

Se aplicaron reglas de calidad mediante SQL para validar la información y transformar las columnas a sus tipos de datos correspondientes.

### Regla 1. Timestamp y ubicación obligatorios

**Criterio:** `timestamp_utc` y `location` deben existir y no estar vacíos.

**Justificación:** ambas columnas permiten identificar cuándo y dónde se registró cada observación. Si falta alguno de estos datos, se dificulta la interpretación y el uso de la medición.

**Resultado:** no se encontraron registros que incumplieran esta condición en las verificaciones realizadas.

### Regla 2. Coordenadas geográficas válidas

**Criterio:** la latitud debe estar entre -90 y 90 grados y la longitud entre -180 y 180 grados.

**Justificación:** estos intervalos corresponden a los rangos válidos de las coordenadas geográficas. Los valores fuera de ellos indicarían información geográfica inválida.

**Resultado:** no se identificaron registros con coordenadas fuera de rango.

### Regla 3. Radiación solar no negativa

**Criterio:** `ALLSKY_SFC_SW_DWN` y `CLRSKY_SFC_SW_DWN` deben ser valores numéricos mayores o iguales a cero.

**Justificación:** bajo las definiciones de las variables utilizadas, los valores negativos no son admisibles para la radiación solar incidente y podrían indicar problemas de calidad.

**Resultado:** no se encontraron valores negativos en las variables de radiación revisadas.

### Regla 4. Temperatura dentro de un rango de plausibilidad

**Criterio:** `T2M` debe estar entre -50 y 60 °C.

**Justificación:** se adopta este intervalo amplio como control de plausibilidad para identificar valores extremos potencialmente erróneos, sin imponer un rango estrecho que descarte condiciones meteorológicas posibles.

**Resultado:** no se encontraron temperaturas fuera del intervalo definido.

### Tratamiento especial de `ALLSKY_KT`

Los valores de `ALLSKY_KT` iguales a `-999` se transformaron a `NULL` en la tabla Silver válida. Se eligió esta estrategia porque el valor representa información no disponible y no una medición válida del índice de claridad.

Este tratamiento conserva las demás variables de la observación y evita interpretar el centinela como un valor numérico real.

## 5. Tablas Silver y conciliación de registros

Se crearon dos tablas Iceberg en formato Parquet:

- **`silver_valid`:** contiene las observaciones que cumplen las reglas de calidad, con conversiones a tipos numéricos y normalización de los valores centinela.
- **`silver_rejected`:** contiene las observaciones que incumplen las reglas, junto con una columna que indica el motivo del rechazo.

Los conteos obtenidos fueron:

| Capa | Registros |
|---|---:|
| Bronze | 1.122.048 |
| Silver válidos | 1.122.048 |
| Silver rechazados | 0 |
| Diferencia de conciliación | 0 |

La conciliación se cumple:

**Bronze = Silver válidos + Silver rechazados**

**1.122.048 = 1.122.048 + 0**

No se encontraron filas que incumplieran las reglas aplicadas. Por tanto, la tabla de rechazados está vacía, pero se conserva para registrar los motivos si aparecen observaciones inválidas en futuras cargas.

## 6. Capa Gold: agregación para el negocio

Se creó la tabla Iceberg `gold_radiacion_anual`, agregando la información por ubicación y año.

La pregunta de negocio que responde es:

**¿Cuál es la radiación solar promedio anual en cada ubicación y cómo varía entre años?**

La tabla contiene **128 filas**, correspondientes a 16 ubicaciones durante ocho años (2017–2024). Incluye las siguientes columnas:

- `location`: ubicación analizada.
- `year`: año de la observación.
- `total_registros`: cantidad total de registros del grupo.
- `registros_radiacion`: cantidad de registros contabilizados para radiación.
- `radiacion_promedio_allsky`: radiación promedio bajo todas las condiciones de cielo.
- `radiacion_promedio_cielo_claro`: radiación promedio bajo condiciones de cielo despejado.
- `indice_claridad_promedio`: índice de claridad promedio.
- `temperatura_promedio`: temperatura promedio.

Esta agregación facilita la comparación inicial del recurso solar entre ubicaciones y años. Puede servir como insumo para identificar zonas que merecen un análisis más detallado de viabilidad fotovoltaica.

Sin embargo, la radiación solar por sí sola no determina la rentabilidad de una instalación. Para evaluar la viabilidad económica también se necesitarían datos de consumo eléctrico, tarifas, costos del sistema, características de los paneles y otros factores relevantes.

## 7. Benchmark de consultas en Athena

Se ejecutaron consultas equivalentes de agregación por ubicación y año sobre Bronze, Silver y Gold. Se registraron el tiempo en cola, el tiempo de ejecución y los datos escaneados en Athena.

| Capa | Tiempo en cola | Tiempo de ejecución | Datos escaneados |
|---|---:|---:|---:|
| Bronze | 100 ms | 0,969 s | 80,20 MB |
| Silver | 97 ms | 0,875 s | 1,26 MB |
| Gold | 68 ms | 1,618 s | 1,45 KB |

### Interpretación de los resultados

**Bronze:** la consulta procesa los datos originales en CSV, con columnas definidas como texto y conversiones numéricas durante la consulta. En esta ejecución, Athena escaneó 80,20 MB y registró un tiempo de ejecución de 0,969 segundos.

**Silver:** el formato Iceberg/Parquet y los tipos de datos preparados reducen los datos escaneados a 1,26 MB. Además, esta consulta tuvo el menor tiempo de ejecución de las tres mediciones, con 0,875 segundos.

**Gold:** al consultar datos previamente agregados por ubicación y año, Athena escaneó solo 1,45 KB. Sin embargo, el tiempo de ejecución fue de 1,618 segundos, superior al de Bronze y Silver en esta ejecución.

Gold escaneó aproximadamente un **99,998 % menos de datos que Bronze**. Esta reducción evidencia el beneficio de la preagregación para disminuir la cantidad de información leída en la consulta de negocio evaluada.

Los tiempos corresponden a mediciones puntuales y pueden variar entre ejecuciones debido a factores como la carga del servicio, la planificación de consultas y la sobrecarga de procesamiento. Por ello, los resultados se interpretan como una comparación observada en estas ejecuciones, no como una garantía de que una capa siempre tendrá menor latencia.

## 8. Conclusiones

La implementación de la arquitectura Medallion permitió organizar los datos de radiación solar y temperatura en tres capas con responsabilidades diferentes.

Bronze conserva los datos originales en formato CSV y facilita las verificaciones iniciales. Silver aplica las reglas de calidad, convierte los tipos de datos y normaliza los valores centinela. Gold presenta una agregación anual por ubicación que facilita las comparaciones necesarias para el análisis preliminar del recurso solar en Colombia.

El proceso analizó 1.122.048 registros. Las reglas aplicadas no produjeron filas rechazadas, por lo que se conservaron 1.122.048 filas válidas y la conciliación de conteos fue exacta.

Finalmente, el benchmark mostró una reducción importante de los datos escaneados al pasar de Bronze a Silver y, especialmente, a Gold. Aunque Gold leyó muchos menos datos, Silver presentó el menor tiempo de ejecución en las mediciones realizadas. Esto demuestra que la cantidad de datos escaneados y la latencia de una consulta son métricas relacionadas, pero no equivalentes.