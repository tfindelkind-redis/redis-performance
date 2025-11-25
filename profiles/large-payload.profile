# Large Payload Test
# Tests Redis with larger data sizes

# Number of requests
-n 5000

# Number of parallel connections
-c 25

# Pipeline requests
-P 1

# Test SET/GET with large payloads
-t set,get

# Data size in bytes (10KB)
-d 10240
