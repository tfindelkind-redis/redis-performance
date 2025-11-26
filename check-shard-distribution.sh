#!/bin/bash

# check-shard-distribution.sh
# Shows the number of keys on each master node in a Redis Cluster

# Load Redis config
echo "Loading config.sh..."
source ./config.sh

echo "Key distribution per master node:"

echo -e "\nCluster slot distribution (from CLUSTER SLOTS):"
redis-cli -c -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" --tls --insecure --raw CLUSTER SLOTS | \
awk '
  BEGIN { print "Master IP:PORT         Slot Start  Slot End    Num Slots" }
  /^[0-9]+$/ {
    slot_start = $1
    getline; slot_end = $1
    getline; master_ip = $1
    getline; master_port = $1
    printf "%-22s %-11s %-11s %-9s\n", master_ip ":" master_port, slot_start, slot_end, slot_end-slot_start+1
  }
'

echo "\nKey distribution per master node:"
NODES=$(redis-cli -c -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" --tls --insecure CLUSTER NODES | awk '$3 ~ /master/ {print $2}' | cut -d@ -f1)
for NODE in $NODES; do
  HOST=$(echo $NODE | cut -d: -f1)
  PORT=$(echo $NODE | cut -d: -f2)
  COUNT=$(redis-cli -h "$HOST" -p "$PORT" -a "$REDIS_PASSWORD" --tls --insecure DBSIZE 2>/dev/null || echo 0)
  echo "  $HOST:$PORT has $COUNT keys"
done
