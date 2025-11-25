# Read-Only 1MB String Workload
# Tests read performance with 1MB string values
# Configured to run for approximately 10 minutes
#
# TWO-STEP APPROACH (CRITICAL):
# Step 1: Populate database with SET operations (creates 1200 keys × 1MB = ~1.4 GB)
# Step 2: Run GET operations (reads same 1200 keys, ~20,500 times each over 10 minutes)
#
# This profile is for STEP 2 (GET test)
# Before running this, you must populate with: redis-benchmark -t set -n 1200 -r 1200 -d 1048576 ...

# Number of requests - based on ~41,000 RPS for 10 minutes (600 seconds)
# 41,000 RPS × 600 seconds = 24,600,000 requests
# With 1200 keys, each key will be accessed ~20,500 times
-n 24600000

# Number of parallel connections (200 clients for read test)
-c 200

# Test only GET operations (read-only)
-t get

# Data size: 1MB (1048576 bytes)
-d 1048576

# Use random keys from keyspace 0-1199 (MUST match populate step!)
# This ensures we read the same keys that were created during populate
-r 1200

# Quiet mode - only show requests per second
-q

# Memory usage: 1200 keys × 1 MB × 1.2 overhead = ~1.4 GB (47% of X3's 3 GB)
# Each key accessed: 24,600,000 / 1,200 = 20,500 times during test
