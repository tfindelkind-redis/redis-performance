#!/bin/bash

# Two-Step Redis Performance Test
# Step 1: Deterministically populate 1,200 unique keys (1MB each)
# Step 2: Run read performance test (GET only, no nulls)

set -e

# Load configuration
source config.sh




# Step 1: Ensure venv and redis-py are available
if [ ! -d ".venv" ]; then
  echo "Creating Python venv..."
  python3 -m venv .venv
fi
VENV_PY="$(pwd)/.venv/bin/python"

# Install redis-py and redis-py-cluster if needed
if [ "${REDIS_CLUSTER_MODE:-false}" = "true" ]; then
  if ! "$VENV_PY" -c "from redis.cluster import RedisCluster" 2>/dev/null; then
    echo "Installing redis-py-cluster in venv..."
    .venv/bin/pip install --quiet redis redis-py-cluster
  fi
else
  if ! "$VENV_PY" -c "import redis" 2>/dev/null; then
    echo "Installing redis-py in venv..."
    .venv/bin/pip install --quiet redis
  fi
fi

# Step 1: Populate all 1,200 keys with 1MB binary values using Python
echo "=========================================="
echo "STEP 1: Deterministic Populate (1,200 keys)"
echo "=========================================="
echo "Populating 1,200 unique keys with 1MB binary values using Python..."

"$VENV_PY" - <<EOF
import os
cluster_mode = os.environ.get("REDIS_CLUSTER_MODE", "false").lower() == "true"
if cluster_mode:
  from redis.cluster import RedisCluster
  import ssl
  ssl_context = ssl.create_default_context()
  ssl_context.check_hostname = False
  ssl_context.verify_mode = ssl.CERT_NONE
  r = RedisCluster(
    host=os.environ["REDIS_HOST"],
    port=int(os.environ["REDIS_PORT"]),
    password=os.environ["REDIS_PASSWORD"],
    decode_responses=True,
    ssl=os.environ.get("USE_SSL", "false").lower() == "true",
    ssl_cert_reqs=None,
    ssl_ca_certs=None,
    ssl_context=ssl_context,
    skip_full_coverage_check=True,
  )
else:
  import redis
  r = redis.StrictRedis(
    host=os.environ["REDIS_HOST"],
    port=int(os.environ["REDIS_PORT"]),
    password=os.environ["REDIS_PASSWORD"],
    ssl=os.environ.get("USE_SSL", "false").lower() == "true"
  )
for i in range(1, 1201):
  key = f"key:{i:012d}"
  r.set(key, os.urandom(1048576))
  if (i-1) % 100 == 0:
    print(f"  Populated {i} / 1200 keys...")
EOF

echo "✅ All 1,200 keys populated."
echo ""


# Verify key count
echo "Verifying key count..."
if [ "${REDIS_CLUSTER_MODE:-false}" = "true" ]; then
  # Sum DBSIZE across all master nodes in the cluster
  TOTAL=0
  # Get all master node host:port pairs
  NODES=$(redis-cli -c -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" --tls --insecure CLUSTER NODES | awk '$3 ~ /master/ {print $2}' | cut -d@ -f1)
  for NODE in $NODES; do
    HOST=$(echo $NODE | cut -d: -f1)
    PORT=$(echo $NODE | cut -d: -f2)
    COUNT=$(redis-cli -h "$HOST" -p "$PORT" -a "$REDIS_PASSWORD" --tls --insecure DBSIZE 2>/dev/null || echo 0)
    echo "  $HOST:$PORT has $COUNT keys"
    TOTAL=$((TOTAL + COUNT))
  done
  KEY_COUNT=$TOTAL
else
  KEY_COUNT=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" --tls --insecure DBSIZE)
fi
echo "Keys in database: $KEY_COUNT"
if [ "$KEY_COUNT" -lt 1200 ]; then
  echo "⚠️  Warning: Expected 1,200 keys but found $KEY_COUNT"
  echo "Continuing anyway..."
fi

echo "Waiting 5 seconds before starting read test..."
sleep 5

# Prepare results directory and filename
RESULTS_DIR="results"
mkdir -p "$RESULTS_DIR"
RESULT_FILE="$RESULTS_DIR/memtier-$(date +%Y%m%d-%H%M%S).out"

# Step 2: Read performance test
echo ""
echo "=========================================="
echo "STEP 2: Read Performance Test"
echo "=========================================="
echo "Running 24.6 million GET operations (no nulls expected)..."

# Remove -t get, -r <value>, and -d <value> from PROFILE_FLAGS for memtier_benchmark
MEMTIER_FLAGS=$(awk 'BEGIN{skip=0} !/^#/ && NF {if($1=="-t"||$1=="-r"||$1=="-d"||$1=="-n"){skip=1;next} if(skip){skip=0;next} printf "%s ", $0}' profiles/read-1mb-200clients.profile)
if [ "${REDIS_CLUSTER_MODE:-false}" = "true" ]; then
  # Cluster mode: use --cluster-mode and key range
  echo "Running: memtier_benchmark --cluster-mode --tls --tls-skip-verify --authenticate $REDIS_PASSWORD --server $REDIS_HOST --port $REDIS_PORT --key-minimum=1 --key-maximum=1200 --key-prefix=key: --ratio=0:1 --test-time=600 $MEMTIER_FLAGS | tee $RESULT_FILE"
  eval memtier_benchmark --cluster-mode --tls --tls-skip-verify --authenticate "$REDIS_PASSWORD" --server "$REDIS_HOST" --port "$REDIS_PORT" --key-minimum=1 --key-maximum=1200 --key-prefix=key: --ratio=0:1 --test-time=600 $MEMTIER_FLAGS | tee "$RESULT_FILE"
else
  # Standalone/Enterprise: no --cluster-mode, but use same key range and GET-only workload
  echo "Running: memtier_benchmark --tls --tls-skip-verify --authenticate $REDIS_PASSWORD --server $REDIS_HOST --port $REDIS_PORT --key-minimum=1 --key-maximum=1200 --key-prefix=key: --ratio=0:1 --test-time=600 $MEMTIER_FLAGS | tee $RESULT_FILE"
  eval memtier_benchmark --tls --tls-skip-verify --authenticate "$REDIS_PASSWORD" --server "$REDIS_HOST" --port "$REDIS_PORT" --key-minimum=1 --key-maximum=1200 --key-prefix=key: --ratio=0:1 --test-time=600 $MEMTIER_FLAGS | tee "$RESULT_FILE"
fi

echo ""
echo "=========================================="
echo "Test Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Review the requests/second metric above"
echo "  2. Check Azure Monitor for network throughput"
echo "  3. Run ./inspect-redis.sh to see database state"
echo ""
