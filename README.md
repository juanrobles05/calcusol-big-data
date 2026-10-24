# Calcusol — Trabajo 1: Capas Medallion y Streaming

## Contexto

Calcusol es una plataforma de apoyo a la decisión que busca evaluar la viabilidad de instalar sistemas solares fotovoltaicos residenciales en Colombia. Para ello, utiliza información de radiación solar, variables meteorológicas y datos relacionados con el consumo y las tarifas eléctricas.

## Objetivo del trabajo

Aplicar una arquitectura de datos Medallion para almacenar, depurar y transformar información relacionada con la radiación solar, utilizando Amazon S3, Amazon Athena y tablas Apache Iceberg. Complementariamente, implementar un flujo de procesamiento de eventos mediante AWS IoT Core, Amazon SQS, AWS Lambda y Amazon DynamoDB.

Todos los recursos de AWS se crearon **manualmente en la consola** (sin CloudFormation, Terraform ni Serverless Framework), en la región `us-east-1`, con AWS Academy Learner Lab.

## Estructura del repositorio

```
data/raw/                    Dataset NASA POWER (CSV)
parte-a-medallion/           Consultas SQL de las capas bronce, plata y oro, y resultados
parte-b-streaming/
  iot-core/                  Regla de IoT Core (SQL)
  lambda/                    Función Lambda calcusol-procesador
  scripts/                   publicar.sh (publicación de eventos) y resumen.py (conciliación)
  evidence-step-by-step/     Capturas de la construcción de la Parte B
  resultados.md              Resultados completos de la Parte B
evidencias/                  Capturas de la Parte A
```

## Parte A — Arquitectura Medallion

- **Bronce:** conservar los datos de entrada en S3 y consultarlos mediante una tabla externa de Athena con columnas de tipo texto.
- **Plata:** identificar problemas de calidad y separar los registros válidos de los rechazados, registrando los motivos de rechazo en tablas Iceberg.
- **Oro:** generar una agregación que responda una pregunta de negocio relevante para Calcusol.
- **Evaluación:** comparar bytes escaneados y tiempos de respuesta al ejecutar una consulta equivalente en las tres capas.

Detalle y resultados: [`parte-a-medallion/resultados.md`](parte-a-medallion/resultados.md).

## Parte B — Streaming

Flujo implementado para procesar eventos de telemetría de 20 paneles solares (irradiancia, temperatura y potencia):

```
publicar.sh (CloudShell) → AWS IoT Core → Amazon SQS → AWS Lambda → Amazon DynamoDB
                           tema calcusol/telemetria   calcusol-eventos   calcusol-procesador   calcusol_eventos
                                                      (+ DLQ)                                  calcusol_descartes
```

### Recursos

| Recurso | Nombre | Detalle |
|---|---|---|
| Regla de IoT Core | `calcusol_telemetria_a_sqs` | Toma los mensajes del tema `calcusol/telemetria` y los envía a SQS, agregando `iot_ts`. |
| Cola principal | `calcusol-eventos` | SQS estándar con cola de errores `calcusol-eventos-dlq` (3 intentos). |
| Función Lambda | `calcusol-procesador` | Python, consume la cola en lotes de 10, valida y guarda cada evento. |
| Tabla de eventos | `calcusol_eventos` | Llave: `device_id` (partición) + `event_id` (orden). |
| Tabla de descartes | `calcusol_descartes` | Llave: `message_id`. Guarda el motivo del descarte. |

### Esquema de los eventos

`event_id`, `device_id` (`panel-01` a `panel-20`), `sent_at_ms`, `irradiancia_wm2`, `temperatura_c`, `potencia_w`. La regla de IoT Core añade `iot_ts`. La Lambda añade `stored_at_ms` y `delay_ms` a los eventos guardados.

### Validación y descartes

Un evento se descarta (y se registra con su motivo) si no es JSON válido, si le falta `event_id` o `device_id`, si `device_id` no está entre `panel-01` y `panel-20`, si algún campo numérico falta o no es numérico, o si está fuera de rango (irradiancia 0–1500, temperatura −50–60, potencia no negativa). Para probar el flujo, `publicar.sh` genera a propósito un 4 % de eventos defectuosos.

### Resultados

| Medida | Valor |
|---|---:|
| Eventos guardados en `calcusol_eventos` | 9.686 |
| Eventos descartados en `calcusol_descartes` | 414 |
| **Total procesado (guardados + descartados)** | **10.100** |
| Retraso promedio (envío → DynamoDB) | 19.715 ms |
| Retraso máximo | 25.718 ms |
| Retraso mínimo | 4.180 ms |

Descartes por motivo: irradiancia fuera de rango (105), temperatura ausente o no numérica (104), potencia fuera de rango (103) y `device_id` ausente o vacío (102).

**Nota sobre la conciliación.** La publicación se hizo en dos corridas (`r1` y `r2`) porque la sesión del laboratorio se acabó durante `r1`. Como `publicar.sh` reinicia `ok.log` en cada corrida, el contador de `resumen.py` solo cuenta la última (7.851), mientras que DynamoDB acumula ambas. La conciliación del total es 10.100 = 9.686 + 414. La explicación completa está en [`parte-b-streaming/resultados.md`](parte-b-streaming/resultados.md).

### Cómo reproducir

Desde AWS CloudShell, con los recursos ya creados:

```bash
./publicar.sh 10000 r1     # publica 10.000 eventos (corrida r1)
python3 resumen.py         # conteos, motivos de descarte y retraso
```

## Preguntas finales

**Parte A: si los datos fueran mil veces mayores, ¿qué cambiarían?**

Con mil veces más datos (unos 1.100 millones de filas), no dejaríamos la capa Bronce en CSV porque la convertiríamos a Parquet y la  particionaríamos por año y ubicación, para que Athena escanee solo lo necesario. Las capas plata y oro se calcularían de forma incremental, procesando solo los datos nuevos, con AWS Glue o Spark en lugar de recrear las tablas completas con una consulta. En las tablas Iceberg programaríamos la compactación de archivos pequeños y vigilaríamos el costo por bytes escaneados.

**Parte B: ¿a partir de qué volumen dejarían esta forma de streaming y cuál usarían en su lugar?**

SQS, Lambda y DynamoDB sirven bien para volúmenes bajos y medios; la prueba fue de 10.000 eventos. Dejaríamos este flujo cuando el volumen sostenido llegue al orden de mil eventos por segundo, o antes si se necesita reproducir eventos, tener varios consumidores o analizar el histórico. Usaríamos Kinesis Data Streams o Kafka administrado con Firehose escribiendo Parquet en S3 para consultarlo con Athena, y DynamoDB solo para el último estado de cada panel. En SQS el mensaje se borra al consumirse, no hay reproducción y el costo se paga por evento.

## Criterios de calidad

- Mantener trazabilidad de los registros transformados y rechazados.
- Documentar las reglas de validación y sus motivos.
- Comprobar que los conteos de registros y eventos cuadren.
- Registrar las mediciones obtenidas durante las pruebas.
- No incluir credenciales ni información sensible en el repositorio.

## Video del trabajo
Url: https://youtu.be/KhR9w-bkVtk 

## Integrantes

- Juan Diego Robles De La Osa
- Juan Pablo Jimenez Quiroz
- James Valencia Cano
