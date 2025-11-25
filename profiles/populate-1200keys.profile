# Populate Database with 1200 Keys × 1MB
# This is STEP 1 before running read-1mb-200clients.profile
#
# Purpose: Create 1200 keys in Redis, each containing 1MB of data
# Memory usage: 1200 × 1 MB × 1.2 = ~1.4 GB (safe for X3 3GB Redis)
#
# Usage:
#   redis-benchmark -h $HOST -p $PORT -a $PASS --tls \
#     $(cat profiles/populate-1200keys.profile)

# Number of requests = number of keys to create (1200)
-n 1200

# Number of parallel connections (50 clients for populate)
-c 50

# Test only SET operations (write keys)
-t set

# Data size: 1MB (1048576 bytes)
-d 1048576

# Use random keys from keyspace 0-1199
# This creates keys: key:000000000000 to key:000000001199
-r 1200

# Quiet mode - only show requests per second
-q

# After this completes, you'll have exactly 1200 keys in Redis
# Then run read-1mb-200clients.profile to test read performance
