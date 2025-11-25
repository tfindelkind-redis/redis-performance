# Basic Redis Performance Test
# Tests basic GET/SET operations

# Number of requests
-n 10000

# Number of parallel connections
-c 50

# Pipeline requests
-P 1

# Test only specified commands (comma-separated)
-t set,get

# Data size in bytes
-d 256
