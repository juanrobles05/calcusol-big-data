# Resultados de la Parte B — Streaming IoT Core → SQS → Lambda → DynamoDB

Todos los recursos se crearon **manualmente en la consola de AWS** (sin CloudFormation, Terraform ni Serverless Framework) en la región `us-east-1`, usando AWS Academy Learner Lab. Como el laboratorio no permite crear roles, tanto la regla de IoT Core como la función Lambda usan el rol preexistente `LabRole`.

## 1. Arquitectura

```
publicar.sh (CloudShell)
   │  aws iot-data publish --qos 1  (20 publicaciones en paralelo)
   ▼
AWS IoT Core  ── tema calcusol/telemetria
   │  regla calcusol_telemetria_a_sqs:
   │  SELECT *, timestamp() AS iot_ts FROM 'calcusol/telemetria'
   ▼
Amazon SQS  ── calcusol-eventos  (DLQ: calcusol-eventos-dlq, 3 intentos)
   │  trigger: batch de 10, Report batch item failures
   ▼
AWS Lambda  ── calcusol-procesador (Python, LabRole)
   ├── evento válido   ──► DynamoDB calcusol_eventos   (+ stored_at_ms, delay_ms)
   └── evento inválido ──► DynamoDB calcusol_descartes (+ motivo)
```

## 2. Recursos creados

| Recurso | Nombre | Configuración relevante |
|---|---|---|
| Tema MQTT | `calcusol/telemetria` | Tema al que publica `publicar.sh`. |
| Regla de IoT Core | `calcusol_telemetria_a_sqs` | SQL 2016-03-23, acción SQS hacia `calcusol-eventos`, rol `LabRole`. Estado *Active*. |
| Cola principal | `calcusol-eventos` | Estándar, visibility timeout de 3 min, DLQ con máximo 3 recepciones. |
| Cola de errores | `calcusol-eventos-dlq` | Estándar. |
| Función Lambda | `calcusol-procesador` | Python 3.12+, x86_64, 256 MB, timeout 30 s, rol `LabRole`. |
| Trigger | SQS `calcusol-eventos` | Batch size 10, *Report batch item failures* activado, estado *Enabled*. |
| Tabla de eventos | `calcusol_eventos` | Partición `device_id` (S), orden `event_id` (S), On-demand. |
| Tabla de descartes | `calcusol_descartes` | Partición `message_id` (S), sin sort key, On-demand. |

El SQL de la regla está en [`iot-core/regla_calcusol_telemetria_a_sqs.sql`](iot-core/regla_calcusol_telemetria_a_sqs.sql).

## 3. Justificación de las llaves de DynamoDB

- **`calcusol_eventos`: `device_id` + `event_id`.** `device_id` como llave de partición reparte la carga entre los 20 paneles y permite consultar todos los eventos de un panel. `event_id` como llave de orden hace único a cada evento dentro de su panel, lo que habilita una escritura condicional (`attribute_not_exists(event_id)`) para no guardar dos veces un evento que SQS estándar entregue repetido (entrega *al menos una vez*).
- **`calcusol_descartes`: `message_id`.** Se usa el identificador del mensaje de SQS porque un evento malformado puede no traer `event_id`. Si SQS reentrega el mismo mensaje, se sobrescribe la misma fila en lugar de duplicarla.

## 4. Adaptación de la función Lambda al esquema de los eventos

Código: [`lambda/lambda_function.py`](lambda/lambda_function.py).

Esquema del evento publicado:

| Campo | Tipo | Descripción |
|---|---|---|
| `event_id` | texto | Identificador único (`<corrida>-<número>`, p. ej. `r1-000042`). |
| `device_id` | texto | Panel, de `panel-01` a `panel-20`. |
| `sent_at_ms` | número | Hora de envío en milisegundos, tomada justo antes de publicar. |
| `irradiancia_wm2` | número | Irradiancia en W/m². |
| `temperatura_c` | número | Temperatura en °C. |
| `potencia_w` | número | Potencia en W. |
| `iot_ts` | número | Lo agrega la regla de IoT Core: hora en que IoT Core recibió el evento. |

Cómo se procesa:

- Los números se leen como `Decimal` (`parse_float=Decimal`) porque DynamoDB no acepta `float`.
- Cada evento válido se guarda completo más `stored_at_ms` (hora de guardado) y `delay_ms` (guardado menos envío).
- Un evento inválido se guarda en `calcusol_descartes` con su motivo y no pasa a la tabla de eventos.
- Un duplicado entregado por SQS se ignora sin contarlo como descarte, porque el original ya está guardado; así `publicados = guardados + descartados` se mantiene exacto.
- Si una escritura falla por otra causa, solo ese mensaje vuelve a la cola (`batchItemFailures`) y, tras 3 intentos, pasa a la cola de errores.

### Reglas de validación y motivos de descarte

| Regla | Motivo registrado |
|---|---|
| El cuerpo no es JSON válido | `JSON invalido` |
| El JSON no es un objeto | `el mensaje no es un objeto JSON` |
| `event_id` o `device_id` ausente o vacío | `campo <campo> ausente o vacio` |
| `device_id` no está en `panel-01..panel-20` | `device_id fuera de panel-01..panel-20` |
| `sent_at_ms` ausente o no numérico | `sent_at_ms ausente o no numerico` |
| `irradiancia_wm2`, `temperatura_c` o `potencia_w` ausente o no numérico | `<campo> ausente o no numerico` |
| `irradiancia_wm2` fuera de 0–1500, `temperatura_c` fuera de −50–60, `potencia_w` negativa | `<campo> fuera de rango` |

## 5. Publicación de eventos

Script: [`scripts/publicar.sh`](scripts/publicar.sh), ejecutado desde AWS CloudShell con `aws iot-data publish` (QoS 1) y 20 publicaciones en paralelo (`xargs -P 20`).

Uno de cada 25 eventos (4 %) se publica mal a propósito, siempre como JSON válido con el esquema roto, rotando entre cuatro defectos: falta `device_id`, irradiancia de 9999, temperatura no numérica (`"abc"`) y potencia negativa (−50).

```bash
./publicar.sh 50 prueba                              # prueba corta
nohup ./publicar.sh 10000 r1 > corrida.log 2>&1 &    # corrida real
```

**Corrida en dos tandas.** La corrida `r1` (10.000 eventos) se lanzó normalmente, pero se acabó el tiempo de la sesión del laboratorio y se interrumpió antes de terminar. Para completar los 10.000 eventos se lanzó una segunda corrida con los eventos restantes, con otro identificador de corrida (`r2`) para que los `event_id` no choquen con los ya guardados:

```bash
nohup ./publicar.sh 7851 r2 > corrida.log 2>&1 &
```

## 6. Resultados medidos

Salida de `scripts/resumen.py` ([evidencia](../evidencias/parte-b/resumen_conciliacion.jpg)):

| Medida | Valor |
|---|---:|
| Eventos guardados en `calcusol_eventos` | 9.686 |
| Eventos descartados en `calcusol_descartes` | 414 |
| Guardados + descartados | 10.100 |
| Publicados según `ok.log` de la última corrida (`r2`) | 7.851 |

Descartes por motivo:

| Motivo | Cantidad |
|---|---:|
| `irradiancia_wm2` fuera de rango | 105 |
| `temperatura_c` ausente o no numérico | 104 |
| `potencia_w` fuera de rango | 103 |
| campo `device_id` ausente o vacío | 102 |
| **Total** | **414** |

Retraso entre el envío y la llegada a DynamoDB (`delay_ms`):

| Promedio | Máximo | Mínimo |
|---:|---:|---:|
| 19.715 ms | 25.718 ms | 4.180 ms |

### Nota sobre la conciliación

La línea `Cuadra: 7851 = 9686 + 414 -> False` de la captura **no indica pérdida de eventos**: la corrida `r1` se interrumpió al agotarse el tiempo del laboratorio y `r2` se lanzó para completar los 10.000. Como `publicar.sh` borra `ok.log` al iniciar una corrida nueva, el contador de publicados del resumen solo refleja `r2` (7.851), mientras que DynamoDB acumula los eventos de ambas corridas.

La conciliación sobre el total real es:

```
publicados(r1) + publicados(r2) = guardados + descartados = 10.100
```

En total hay 10.100 eventos entre guardados y descartados, es decir, 100 más de los 10.000 planeados. Los `event_id` de `r1` y `r2` son distintos, así que no hay duplicados.

El retraso promedio (~19,7 s) es alto porque los 20 publicadores en paralelo generan eventos más rápido de lo que la Lambda los consume, y durante la corrida se llegó a ver 70 mensajes disponibles en `calcusol-eventos`. La medida incluye el tiempo de espera en la cola.

## 7. Evidencias

| Evidencia | Archivo |
|---|---|
| Colas SQS (`calcusol-eventos` y DLQ) | [sqs_colas.jpg](../evidencias/parte-b/sqs_colas.jpg) |
| Regla de IoT Core activa | [iot_core_regla.jpg](../evidencias/parte-b/iot_core_regla.jpg) |
| Tablas de DynamoDB y sus llaves | [dynamodb_tablas.jpg](../evidencias/parte-b/dynamodb_tablas.jpg) |
| Función Lambda desplegada | [lambda_funcion.jpg](../evidencias/parte-b/lambda_funcion.jpg) |
| Trigger SQS → Lambda habilitado | [lambda_trigger_sqs.jpg](../evidencias/parte-b/lambda_trigger_sqs.jpg) |
| Inicio de la corrida de 10.000 eventos | [inicio_publicacion.jpg](../evidencias/parte-b/inicio_publicacion.jpg) |
| Avance y fin de la publicación | [publicacion_finalizada.jpg](../evidencias/parte-b/publicacion_finalizada.jpg) |
| Resumen: conteos, motivos y retraso | [resumen_conciliacion.jpg](../evidencias/parte-b/resumen_conciliacion.jpg) |

## 8. Pregunta final: ¿a partir de qué volumen dejarían esta forma de streaming?

SQS, Lambda y DynamoDB sirven bien para volúmenes bajos y medios; la prueba fue de 10.000 eventos. Como regla práctica, se dejaría este flujo cuando el volumen sostenido llegue al orden de mil eventos por segundo, o antes si se necesita reproducir eventos, tener varios consumidores o analizar el histórico. Se usaría Kinesis Data Streams (o Kafka administrado) con Firehose escribiendo Parquet en S3 para consultarlo con Athena, y DynamoDB solo para el último estado de cada panel. En SQS el mensaje se borra al consumirse, no hay reproducción y el costo se paga por evento.
