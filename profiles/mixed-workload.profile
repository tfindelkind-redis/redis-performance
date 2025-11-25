# Mixed Workload Test
# Simulates a realistic mixed workload

# Number of requests
-n 50000

# Number of parallel connections
-c 75

# Pipeline 8 requests
-P 8

# Test various commands
-t set,get,incr,lpush,rpop,sadd,hset,zadd

# Data size in bytes
-d 1024
