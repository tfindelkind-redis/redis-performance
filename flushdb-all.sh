#!/bin/bash
# Flush all keys from all master nodes in OSS Redis Cluster or from Enterprise instance
source config.sh

if [ "${REDIS_CLUSTER_MODE:-false}" = "true" ]; then
  echo "Flushing all master nodes in OSS Redis Cluster..."
  NODES=$(redis-cli -c -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" --tls --insecure CLUSTER NODES | awk '$3 ~ /master/ {print $2}' | cut -d@ -f1)
  for NODE in $NODES; do
    HOST=$(echo $NODE | cut -d: -f1)
    PORT=$(echo $NODE | cut -d: -f2)
    echo "  FLUSHDB on $HOST:$PORT"
    redis-cli -h "$HOST" -p "$PORT" -a "$REDIS_PASSWORD" --tls --insecure FLUSHDB
  done
  echo "All master nodes flushed."
else
  echo "Flushing Enterprise Redis instance..."
  redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" --tls --insecure FLUSHDB
  echo "Enterprise instance flushed."
fi
