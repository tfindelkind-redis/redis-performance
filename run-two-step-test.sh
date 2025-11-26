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
  key = f"key:{i}"
  r.set(key, os.urandom(1048576))
  if (i-1) % 100 == 0:
    print(f"  Populated {i} / 1200 keys...")
EOF

echo "✅ All 1,200 keys populated."
echo ""



echo "Waiting 5 seconds before starting read test..."
sleep 5

# Prepare results directory and filename

RESULTS_DIR="results"
mkdir -p "$RESULTS_DIR"
RESULT_FILE="$RESULTS_DIR/memtier-$(date +%Y%m%d-%H%M%S).out"

# Write workload and environment info to results file
{
  echo "# Redis Performance Test Run Info"
  echo "Date: $(date -u)"
  echo "Redis Host: $REDIS_HOST"
  echo "Redis Port: $REDIS_PORT"
  echo "Redis DB: $REDIS_DB"
  echo "Cluster Mode: $REDIS_CLUSTER_MODE"
  echo "Key Range: 1-1200"
  echo "Key Prefix: key:"
  echo "Workload: GET only, 1MB values, 1200 keys"
  echo "Memtier Profile: profiles/read-1mb-200clients.profile"
  echo "Memtier Flags: $MEMTIER_FLAGS"
  echo ""
  echo "# Azure/VM/Redis Instance Info"
  echo "Resource Group: $AZURE_RESOURCE_GROUP"
  echo "Location: $AZURE_LOCATION"
  echo "VM Name: $VM_NAME"
  echo "Admin User: $ADMIN_USER"
  echo ""
  # Try to get Redis SKU and cluster policy if az CLI is available
  if command -v az >/dev/null 2>&1; then
    echo "Redis SKU: $(az redis show --name $(basename $REDIS_HOST .redis.azure.net) --resource-group $AZURE_RESOURCE_GROUP --query sku.name -o tsv 2>/dev/null)"
    echo "Redis Capacity: $(az redis show --name $(basename $REDIS_HOST .redis.azure.net) --resource-group $AZURE_RESOURCE_GROUP --query sku.capacity -o tsv 2>/dev/null)"
    echo "Cluster Policy: $(az redis show --name $(basename $REDIS_HOST .redis.azure.net) --resource-group $AZURE_RESOURCE_GROUP --query redisConfiguration.cluster-policy -o tsv 2>/dev/null)"
  else
    echo "Redis SKU: (az CLI not available)"
    echo "Cluster Policy: (az CLI not available)"
  fi
  echo ""
} > "$RESULT_FILE"

# Show detailed shard/slot/key distribution using Python script (after results file is created)
if [ "${REDIS_CLUSTER_MODE:-false}" = "true" ]; then
  echo "Shard/slot/key distribution (from check-shard-slots.py):"
  ${VENV_PY} check-shard-slots.py | tee -a "$RESULT_FILE"
else
  echo "Slot-level key distribution is only available for OSS Redis Cluster. Skipping for Enterprise."
fi

# Step 2: Read performance test
echo ""
echo "=========================================="
echo "STEP 2: Read Performance Test"
echo "=========================================="
echo "Running 24.6 million GET operations (no nulls expected)..."

# Remove -t get, -r <value>, and -d <value> from PROFILE_FLAGS for memtier_benchmark
# Source memtier_benchmark config (shell fragment)
source profiles/read-1mb-200clients.profile

echo "Running: memtier_benchmark $MEMTIER_FLAGS | tee $RESULT_FILE"
eval memtier_benchmark $MEMTIER_FLAGS | tee "$RESULT_FILE"

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
