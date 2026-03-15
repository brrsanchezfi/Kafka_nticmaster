#!/bin/bash

echo "Creando topics de kafka"

docker exec broker-1 kafka-topics --bootstrap-server localhost:9092 --create --topic sensor-telemetry --partitions 3 --replication-factor 1
docker exec broker-1 kafka-topics --bootstrap-server localhost:9092 --create --topic sales-transactions --partitions 3 --replication-factor 1
docker exec broker-1 kafka-topics --bootstrap-server localhost:9092 --create --topic sensor-alerts --partitions 3 --replication-factor 1
docker exec broker-1 kafka-topics --bootstrap-server localhost:9092 --create --topic sales-summary --partitions 3 --replication-factor 1

echo "OK"

echo "Topics list"

docker exec broker-1 kafka-topics --bootstrap-server localhost:9092 --list