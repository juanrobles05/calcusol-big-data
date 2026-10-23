# Calcusol — Trabajo 1: Capas Medallion y Streaming

## Contexto

Calcusol es una plataforma de apoyo a la decisión que busca evaluar la viabilidad de instalar sistemas solares fotovoltaicos residenciales en Colombia. Para ello, utiliza información de radiación solar, variables meteorológicas y datos relacionados con el consumo y las tarifas eléctricas.

## Objetivo del trabajo

Aplicar una arquitectura de datos Medallion para almacenar, depurar y transformar información relacionada con la radiación solar, utilizando Amazon S3, Amazon Athena y tablas Apache Iceberg. Complementariamente, implementar un flujo de procesamiento de eventos mediante AWS IoT Core, Amazon SQS, AWS Lambda y Amazon DynamoDB.

## Parte A — Arquitectura Medallion

- **Bronce:** conservar los datos de entrada en S3 y consultarlos mediante una tabla externa de Athena con columnas de tipo texto.
- **Plata:** identificar problemas de calidad y separar los registros válidos de los rechazados, registrando los motivos de rechazo en tablas Iceberg.
- **Oro:** generar una agregación que responda una pregunta de negocio relevante para Calcusol.
- **Evaluación:** comparar bytes escaneados y tiempos de respuesta al ejecutar una consulta equivalente en las tres capas.

## Parte B — Streaming

Implementar el flujo IoT Core → SQS → Lambda → DynamoDB para procesar eventos relacionados con variables solares y meteorológicas. Publicar al menos 10.000 eventos y verificar la conciliación entre eventos publicados, guardados y descartados, además de medir el retraso promedio y máximo.

## Criterios de calidad

- Mantener trazabilidad de los registros transformados y rechazados.
- Documentar las reglas de validación y sus motivos.
- Comprobar que los conteos de registros y eventos cuadren.
- Registrar las mediciones obtenidas durante las pruebas.
- No incluir credenciales ni información sensible en el repositorio.

## Integrantes

- Juan Diego Robles De La Osa
- Juan Pablo Jimenez Quiroz
- James Valencia Cano
