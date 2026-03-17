# Kafka y Procesamiento en Tiempo Real

**Alumno:** _Roberto Sanchez Figueroa_
**Fecha:** _19/03/2026_
**Asignatura:** Kafka y Procesamiento en Tiempo Real
---
**Repositorio:**  
https://github.com/brrsanchezfi/Kafka_nticmaster  
---
---

## Preparación del entorno

Se copiaron las carpetas `0.tarea` y `1.environment` como base para desarrollar esta tarea.

Adicionalmente se crearon los siguientes scripts para preparar los requisitos de los 5 puntos:

1. `create_topics.sh` — crea los 4 topics necesarios en Kafka
2. `start_connectors.sh` — registra todos los conectores via Kafka Connect REST API
3. Cada tarea tiene su propia carpeta (`task1`, `task2`, etc.) con los ficheros fuente
4. Toda la evidencia y referencias están documentadas en este README.md

---

## Arquitectura General

![til](0.tarea/assets/escenario.png)

### Topics Kafka creados

| Topic | Descripción | Particiones |
|---|---|---|
| `sensor-telemetry` | Lecturas en tiempo real de sensores IoT | 3 |
| `sales-transactions` | Transacciones de ventas desde MySQL | 3 |
| `sensor-alerts` | Alertas de condiciones anómalas detectadas | 3 |
| `sales-summary` | Resumen de ventas agregadas por minuto | 3 |

---

## Paso 1: Levantar la infraestructura

Se ejecuta el script `setup.sh` que levanta toda la arquitectura a partir de un Docker Compose:

```bash
./setup.sh
```

Servicios levantados:

| Servicio | Puerto | Descripción |
|---|---|---|
| Zookeeper | 2181 | Coordinación interna de Kafka |
| Kafka Broker | 9092 | Núcleo del sistema de mensajería |
| Schema Registry | 8081 | Almacena schemas Avro |
| Kafka Connect | 8083 | Framework de conectores source/sink |
| ksqlDB Server | 8088 | Motor de procesamiento streaming con SQL |
| ksqlDB CLI | — | Terminal interactiva para ksqlDB |
| MySQL 8.0 | 3306 | Base de datos relacional de ventas |
| MongoDB 6.0 | 27017 | Base de datos destino para alertas |

---

## Paso 2: Crear los Topics

Se ejecuta el script `create_topics.sh`:

```bash
./create_topics.sh
```

Contenido del script:

```bash
echo "Creando topics de Kafka"

docker exec broker-1 kafka-topics --bootstrap-server localhost:9092 \
  --create --topic sensor-telemetry --partitions 3 --replication-factor 1

docker exec broker-1 kafka-topics --bootstrap-server localhost:9092 \
  --create --topic sales-transactions --partitions 3 --replication-factor 1

docker exec broker-1 kafka-topics --bootstrap-server localhost:9092 \
  --create --topic sensor-alerts --partitions 3 --replication-factor 1

docker exec broker-1 kafka-topics --bootstrap-server localhost:9092 \
  --create --topic sales-summary --partitions 3 --replication-factor 1

echo "OK"
echo "Topics list"

docker exec broker-1 kafka-topics --bootstrap-server localhost:9092 --list
```
---

## Paso 3: Registrar los Conectores

Se ejecuta el script `start_connectors.sh` que registra todos los conectores via la REST API de Kafka Connect:

```bash
./start_connectors.sh
```

Contenido del script:

```bash
#/bin/bash

echo "Lanzando conectores"

curl -d @"./connectors/source-datagen-_transactions.json" -H "Content-Type: application/json" -X POST http://localhost:8083/connectors | jq

curl -d @"./connectors/sink-mysql-_transactions.json" -H "Content-Type: application/json" -X POST http://localhost:8083/connectors | jq

curl -d @"./connectors/source-datagen-sensor-telemetry.json" -H "Content-Type: application/json" -X POST http://localhost:8083/connectors | jq

curl -d @"./connectors/source-mysql-sales_transactions.json" -H "Content-Type: application/json" -X POST http://localhost:8083/connectors | jq

curl -d @"./connectors/sink-mongodb-sensor_alerts.json" -H "Content-Type: application/json" -X POST http://localhost:8083/connectors | jq

echo "OK"
```


## Tarea 1: Generación de Datos Sintéticos con Kafka Connect

**Objetivo:** configurar un source connector Datagen que simule lecturas de sensores IoT y las publique en el topic `sensor-telemetry`.

### Schema Avro

El schema define la estructura de cada mensaje. Se usa Avro (formato binario) en lugar de JSON porque es más eficiente y el Schema Registry garantiza que productores y consumidores usen la misma estructura.

Fichero: `task1/sensor_telemetry_schema.avsc`

```json
{
  "namespace": "com.farmia.iot",
  "name": "SensorTelemetry",
  "type": "record",
  "fields": [
    {
      "name": "sensor_id",
      "type": {
        "type": "string",
        "arg.properties": { "regex": "sensor_[0-9]{3}" }
      }
    },
    {
      "name": "timestamp",
      "type": {
        "type": "long",
        "arg.properties": {
          "range": { "min": 1673548200000, "max": 1704997800000 }
        }
      }
    },
    {
      "name": "temperature",
      "type": {
        "type": "double",
        "arg.properties": { "range": { "min": 10.0, "max": 45.0 } }
      }
    },
    {
      "name": "humidity",
      "type": {
        "type": "double",
        "arg.properties": { "range": { "min": 10.0, "max": 90.0 } }
      }
    },
    {
      "name": "soil_fertility",
      "type": {
        "type": "double",
        "arg.properties": { "range": { "min": 0.0, "max": 100.0 } }
      }
    }
  ]
}
```

### Configuración del Conector

Fichero: `task1/source-datagen-sensor-telemetry.json`

```json
{
  "name": "datagen-sensor-telemetry",
  "config": {
    "connector.class": "io.confluent.kafka.connect.datagen.DatagenConnector",
    "kafka.topic": "sensor-telemetry",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter.schema.registry.url": "http://schema-registry:8081",
    "schema.filename": "/home/appuser/sensor-telemetry.avsc",
    "schema.keyfield": "sensor_id",
    "iterations": 10000000,
    "max.interval": 500,
    "tasks.max": "1"
  }
}
```

### Registro y verificación

```bash
# Registrar el conector
curl -d @"./connectors/source-datagen-sensor-telemetry.json" \
  -H "Content-Type: application/json" \
  -X POST http://localhost:8083/connectors | jq

# Verificar estado (debe aparecer "state": "RUNNING")
curl -s http://localhost:8083/connectors/datagen-sensor-telemetry/status \
  | python3 -m json.tool

# Verificar mensajes en el topic
docker exec -it ksqldb-cli ksql http://ksqldb-server:8088
```

```sql
PRINT 'sensor-telemetry' FROM BEGINNING LIMIT 5;
```
![til](task1/imgs/ksqldb-1-sensor_telemetry.png)

---

## Tarea 2: Integración de MySQL con Kafka Connect

**Objetivo:** leer las transacciones de ventas desde una tabla MySQL y publicarlas en el topic `sales-transactions` usando un source connector JDBC.


### Configuración del Conector

Fichero: `task2/source-mysql-sales_transactions.json`

```json
{
    "name": "mysql-sales-transactions-source",
    "config": {
      "connector.class": "io.confluent.connect.jdbc.JdbcSourceConnector",
      "connection.url": "jdbc:mysql://mysql:3306/db?useSSL=false&allowPublicKeyRetrieval=true",
      "connection.user": "user",
      "connection.password": "password",
      "table.whitelist": "sales_transactions",
      "mode": "timestamp+incrementing",
      "timestamp.column.name": "timestamp",
      "incrementing.column.name": "transaction_id",
      "topic.prefix": "sales-",
      "poll.interval.ms": "5000",
      "tasks.max": "1",
      "key.converter": "org.apache.kafka.connect.storage.StringConverter",
      "value.converter": "io.confluent.connect.avro.AvroConverter",
      "value.converter.schema.registry.url": "http://schema-registry:8081"
    }
}
```

El modo `timestamp+incrementing` permite detectar filas nuevas en MySQL sin necesidad de binlog: cada 5 segundos el conector consulta filas con timestamp o ID mayor al último procesado. Cualquier INSERT nuevo en la tabla aparece en Kafka en menos de 5 segundos.

### Verificación

```bash
# Verificar estado
curl -s http://localhost:8083/connectors/mysql-sales-transactions-source/status \
  | python3 -m json.tool

# Verificar mensajes en el topic
docker exec -it ksqldb-cli ksql http://ksqldb-server:8088
```

```sql
PRINT 'sales-transactions' FROM BEGINNING LIMIT 5;
```
![til](task2/ksqldb-1-sales-transactions.png)
---

## Tarea 3: Procesamiento en Tiempo Real de Sensores

**Objetivo:** detectar condiciones anómalas (temperatura > 35°C o humedad < 20%) en los datos de sensores y publicar alertas en `sensor-alerts`.

Se usa ksqlDB, que permite procesar streams de datos con SQL. A diferencia de una consulta normal, un `CREATE STREAM ... AS SELECT` crea un proceso continuo que no para nunca.

### Paso 1: Stream de entrada

```bash
docker exec -it ksqldb-cli ksql http://ksqldb-server:8088
```

```sql
CREATE STREAM sensor_telemetry_stream (
  sensor_id      VARCHAR KEY,
  timestamp      BIGINT,
  temperature    DOUBLE,
  humidity       DOUBLE,
  soil_fertility DOUBLE
) WITH (
  KAFKA_TOPIC  = 'sensor-telemetry',
  VALUE_FORMAT = 'AVRO'
);
```

Esto no mueve datos — le dice a ksqlDB cómo interpretar los mensajes del topic.

### Paso 2: Stream de alertas

```sql
SET 'auto.offset.reset' = 'earliest';

CREATE STREAM sensor_alerts_stream
  WITH (
    KAFKA_TOPIC  = 'sensor-alerts',
    VALUE_FORMAT = 'JSON'
  )
AS SELECT
  sensor_id,
  CASE
    WHEN temperature > 35 AND humidity < 20 THEN 'HIGH_TEMPERATURE_AND_LOW_HUMIDITY'
    WHEN temperature > 35                   THEN 'HIGH_TEMPERATURE'
    ELSE                                         'LOW_HUMIDITY'
  END AS alert_type,
  timestamp,
  CONCAT(
    CASE WHEN temperature > 35
         THEN CONCAT('Temperature exceeded 35C (actual: ', CAST(temperature AS VARCHAR), 'C). ')
         ELSE '' END,
    CASE WHEN humidity < 20
         THEN CONCAT('Humidity below 20% (actual: ', CAST(humidity AS VARCHAR), '%). ')
         ELSE '' END
  ) AS details
FROM sensor_telemetry_stream
WHERE temperature > 35
   OR humidity < 20
EMIT CHANGES;
```

### Paso 3: Verificación

```sql
-- Ver alertas en tiempo real
SELECT * FROM sensor_alerts_stream EMIT CHANGES LIMIT 10;

-- Ver mensajes en el topic
PRINT 'sensor-alerts' FROM BEGINNING LIMIT 5;
```

![til](task3/ksqldb-1-sensor-alerts.png)
---

## Tarea 4: Procesamiento en Tiempo Real de Transacciones de Ventas

**Objetivo:** agregar las transacciones por categoría de producto en ventanas de 1 minuto y publicar el resumen en `sales-summary`.

### Paso 1: Stream de entrada

```bash
docker exec -it ksqldb-cli ksql http://ksqldb-server:8088
```

```sql
CREATE STREAM sales_transactions_stream (
  transaction_id  VARCHAR KEY,
  timestamp       BIGINT,
  product_id      VARCHAR,
  category        VARCHAR,
  quantity        INT,
  price           DOUBLE
) WITH (
  KAFKA_TOPIC  = 'sales-transactions',
  VALUE_FORMAT = 'AVRO'
);
```

### Paso 2: Tabla de resumen con ventana tumbling

```sql
SET 'auto.offset.reset' = 'earliest';

CREATE TABLE sales_summary_table
  WITH (
    KAFKA_TOPIC  = 'sales-summary',
    VALUE_FORMAT = 'JSON'
  )
AS SELECT
  category,
  SUM(quantity)         AS total_quantity,
  SUM(quantity * price) AS total_revenue,
  WINDOWSTART           AS window_start,
  WINDOWEND             AS window_end
FROM sales_transactions_stream
WINDOW TUMBLING (SIZE 1 MINUTE)
GROUP BY category
EMIT CHANGES;
```

**STREAM vs TABLE:** un Stream es una secuencia infinita de eventos independientes. Una Table representa el estado acumulado agrupado — como un GROUP BY que se actualiza solo en tiempo real.

**WINDOW TUMBLING (SIZE 1 MINUTE):** divide el tiempo en ventanas fijas de 1 minuto sin solapamiento. Todos los eventos entre 10:00:00 y 10:00:59 van a la misma ventana; a las 10:01:00 comienza una nueva desde cero.

```
|--- ventana 1 ---|--- ventana 2 ---|--- ventana 3 ---|
10:00            10:01            10:02            10:03
```

### Paso 3: Verificación

```sql
-- Ver resumen en tiempo real
SELECT * FROM sales_summary_table EMIT CHANGES LIMIT 10;

-- Ver mensajes en el topic
PRINT 'sales-summary' FROM BEGINNING LIMIT 5;
```

Formato del mensaje producido:

```json
{
  "category":       "fertilizers",
  "total_quantity": 9,
  "total_revenue":  470.0,
  "window_start":   1673548200000,
  "window_end":     1673548260000
}
```
![til](task4/4.png)
---

## Tarea 5: Integración de MongoDB con Kafka Connect

**Objetivo:** configurar un sink connector que escriba cada alerta del topic `sensor-alerts` como documento en la colección `sensor_alerts` de MongoDB.

Este es un **sink connector**: a diferencia de los anteriores (source), va en dirección contraria — lleva datos desde Kafka hacia un sistema externo.

### Configuración del Conector

Fichero: `task5/sink-mongodb-sensor_alerts.json`

```json
{
  "name": "mongodb-sensor-alerts-sink",
  "config": {
    "connector.class": "com.mongodb.kafka.connect.MongoSinkConnector",
    "connection.uri": "mongodb://admin:adminpassword@mongodb:27017",
    "database": "farmia_db",
    "collection": "sensor_alerts",
    "topics": "sensor-alerts",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "false",
    "tasks.max": "1"
  }
}
```
`
### Verificación en MongoDB

```bash
docker exec -it mongodb mongosh -u admin -p adminpassword --authenticationDatabase admin
```

```js
use farmia_db

// Contar documentos insertados
db.sensor_alerts.countDocuments()

// Ver los primeros 5 documentos
db.sensor_alerts.find().limit(5).pretty()
```

Resultado obtenido:

```
farmia_db> db.sensor_alerts.countDocuments()
2288

farmia_db> db.sensor_alerts.find().limit(5).pretty()
[
  {
    _id: ObjectId('...'),
    DETAILS: 'Humidity below 20% (actual: 13.95%). ',
    TIMESTAMP: Long('1686815542759'),
    ALERT_TYPE: 'LOW_HUMIDITY'
  },
  ...
]
```

