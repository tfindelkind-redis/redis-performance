
# memtier_benchmark config (shell fragment)
# Source this file in your test script to set memtier parameters

# Number of threads
MEMTIER_THREADS=4
# Number of clients (connections)
MEMTIER_CLIENTS=50
# Data size in bytes
MEMTIER_DATA_SIZE=1048576
# Key range
MEMTIER_KEY_MIN=1
MEMTIER_KEY_MAX=1200
# Key prefix
MEMTIER_KEY_PREFIX="key:"
# Ratio of SET:GET (0:1 for read-only)
MEMTIER_RATIO="0:1"
# Test duration in seconds
MEMTIER_TEST_TIME=600
# Use TLS
MEMTIER_TLS="--tls --tls-skip-verify"
# Authenticate
MEMTIER_AUTH="--authenticate $REDIS_PASSWORD"
# Server and port
MEMTIER_SERVER="--server $REDIS_HOST --port $REDIS_PORT"
# Cluster mode (set to --cluster-mode if needed)
MEMTIER_CLUSTER_MODE="${REDIS_CLUSTER_MODE:+--cluster-mode}"

# Rate limit (ops/sec)
MEMTIER_RATE_LIMIT="--rate-limit 20"

# Compose all flags
MEMTIER_FLAGS="--threads $MEMTIER_THREADS --clients $MEMTIER_CLIENTS --data-size $MEMTIER_DATA_SIZE --key-minimum $MEMTIER_KEY_MIN --key-maximum $MEMTIER_KEY_MAX --key-prefix $MEMTIER_KEY_PREFIX --ratio $MEMTIER_RATIO --test-time $MEMTIER_TEST_TIME $MEMTIER_RATE_LIMIT $MEMTIER_TLS $MEMTIER_AUTH $MEMTIER_SERVER $MEMTIER_CLUSTER_MODE"
