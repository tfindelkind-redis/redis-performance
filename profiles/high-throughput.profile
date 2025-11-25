# High Throughput Test
# Tests Redis under high load with pipelining

# Number of requests
-n 100000

# Number of parallel connections
-c 100

# Pipeline 16 requests at a time
-P 16

# Test multiple commands
-t set,get,incr,lpush,rpush,lpop,rpop,sadd,hset,spop,zadd,zpopmin

# Data size in bytes
-d 512
