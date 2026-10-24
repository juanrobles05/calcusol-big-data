-- Regla de AWS IoT Core: calcusol_telemetria_a_sqs
-- SQL version: 2016-03-23
-- Acción: Simple Queue Service (SQS) -> cola calcusol-eventos (sin base64), rol LabRole
-- iot_ts guarda la hora (ms) en que IoT Core recibió el evento.
SELECT *, timestamp() AS iot_ts FROM 'calcusol/telemetria'
