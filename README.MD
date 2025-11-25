# Redis Performance Benchmark Tool

A flexible bash script for running performance benchmarks against Azure Managed Redis Database using different profiles.

## Features

- 🚀 Multiple pre-configured performance profiles
- 📊 Automatic result logging with timestamps
- 🔧 Easy configuration through a single config file
- 🔐 Secure authentication using Azure Redis Access Key
- 📝 Profile-based testing for different scenarios

## Prerequisites

- Redis command-line tools (includes `redis-benchmark`)
  - **macOS**: `brew install redis`
  - **Linux**: `sudo apt-get install redis-tools`

## Setup

### Option 1: Interactive Setup (Recommended)

```bash
./setup.sh
```

The script will prompt you for your Redis credentials and create `config.sh` automatically.

### Option 2: Manual Setup

1. **Create your configuration file**:
   ```bash
   # Copy the template
   cp config.sh.template config.sh
   
   # Edit with your Azure Redis details
   vim config.sh
   ```
   
   Fill in your Redis details:
   ```bash
   REDIS_HOST="yourredis.redis.cache.windows.net"
   REDIS_PORT="6380"
   REDIS_PASSWORD="your-access-key-here"
   USE_SSL="true"
   REDIS_DB="0"
   ```

### Important Security Notes

- ⚠️ **Never commit `config.sh`** - It contains your Redis password!
- ✅ `config.sh` is already in `.gitignore` - Your credentials are safe
- 📝 `config.sh.template` is the safe template tracked in git
- 🔑 Keep your access keys secure

## Usage

Run the benchmark script:

```bash
./run-benchmark.sh
```

The script will:
1. Display available performance profiles
2. Prompt you to select a profile
3. Run the benchmark against your Azure Redis Database
4. Save results to the `results/` directory
5. Optionally run additional tests

## Available Profiles

The tool comes with several pre-configured profiles in the `profiles/` directory:

- **basic-test.profile** - Basic GET/SET operations test
- **high-throughput.profile** - High load test with pipelining
- **large-payload.profile** - Tests with larger data sizes (10KB)
- **mixed-workload.profile** - Realistic mixed workload simulation

## Creating Custom Profiles

You can create your own profiles by adding `.profile` files to the `profiles/` directory. Each profile file contains redis-benchmark command-line arguments:

```bash
# Custom Profile Description
# Additional details

# Number of requests
-n 10000

# Number of parallel connections
-c 50

# Pipeline requests
-P 1

# Test specific commands
-t set,get

# Data size in bytes
-d 256
```

### Common redis-benchmark Options

- `-n <requests>` - Total number of requests
- `-c <clients>` - Number of parallel connections
- `-P <pipeline>` - Pipeline N requests
- `-t <tests>` - Only run comma-separated list of tests
- `-d <size>` - Data size of SET/GET value in bytes
- `-r <keyspacelen>` - Use random keys for SET/GET/INCR
- `-q` - Quiet mode, only show query/sec values
- `--csv` - Output in CSV format

## Results

All benchmark results are automatically saved to the `results/` directory with timestamps:

```
results/
├── basic-test_20251124_143022.txt
├── high-throughput_20251124_143145.txt
└── large-payload_20251124_143302.txt
```

## Security Notes

- ✅ `config.sh` is in `.gitignore` - your credentials won't be committed
- 🔒 Access keys are stored in `config.sh` - keep this file secure
- 🎭 The scripts mask passwords in console output
- 🔐 SSL/TLS is enabled by default for Azure Redis
- 📝 Use `config.sh.template` for reference/sharing

### Finding Your Azure Redis Credentials

1. Go to **Azure Portal**
2. Navigate to your **Azure Cache for Redis** instance
3. Click on **"Access keys"** in the left menu
4. Copy the **Primary key** or connection string
5. The host is shown in the **Overview** section

## Azure Container Deployment (Recommended)

For the **best performance and network bandwidth**, deploy the benchmark container to Azure Container Instances:

### Quick Start

```bash
./deploy-to-aci.sh
```

This creates a **persistent, interactive container** with:
- ✅ **Static names**: `redis-benchmark-acr` and `redis-benchmark-aci`
- ✅ **Persistent**: Container stays running for multiple benchmark sessions
- ✅ **Interactive**: Full bash access to run any redis-benchmark commands
- ✅ **Azure network**: Proper bandwidth without home network bottlenecks
- ✅ **Environment variables**: Redis credentials pre-configured

### Connect to Running Container

```bash
# Easy connection with helper script
./connect-to-aci.sh

# Or manually
az container exec \
  --resource-group rg-azure-managed-redis-terraform3 \
  --name redis-benchmark-aci \
  --exec-command /bin/bash
```

### Run Benchmarks in Container

```bash
# Option 1: Interactive profile selection
./run-benchmark.sh

# Option 2: Direct redis-benchmark commands
redis-benchmark -h $REDIS_HOST -p $REDIS_PORT -a $REDIS_PASSWORD --tls -n 10000 -c 50

# Option 3: Specific tests
redis-benchmark -h $REDIS_HOST -p $REDIS_PORT -a $REDIS_PASSWORD --tls -t get,set -n 100000 -c 200 -d 1048576
```

📖 **See [INTERACTIVE-CONTAINER-GUIDE.md](INTERACTIVE-CONTAINER-GUIDE.md)** for detailed Azure deployment documentation.

## Troubleshooting

### redis-benchmark not found
Install Redis tools:
- macOS: `brew install redis`
- Linux: `sudo apt-get install redis-tools`

### Connection timeout or refused
- Verify `REDIS_HOST` and `REDIS_PORT` in config.sh
- Check Azure Redis firewall rules
- Ensure SSL is enabled if required (`USE_SSL="true"`)

### Authentication failed
- Verify `REDIS_PASSWORD` contains the correct access key
- Check if the key has expired or been rotated

### Container exec format error
- This is an architecture mismatch issue
- The script now uses Docker buildx for cross-platform builds
- Automatically detects ARM64 (Apple Silicon) and builds for AMD64

## Documentation

- **[SETUP.md](SETUP.md)** - Detailed setup instructions
- **[CONFIG-MANAGEMENT.md](CONFIG-MANAGEMENT.md)** - Configuration best practices
- **[INTERACTIVE-CONTAINER-GUIDE.md](INTERACTIVE-CONTAINER-GUIDE.md)** - Azure container deployment guide
- **[AZURE-CONTAINERS-GUIDE.md](AZURE-CONTAINERS-GUIDE.md)** - Azure Container Instances overview
- **[AZURE-RG-CONFIG.md](AZURE-RG-CONFIG.md)** - Azure resource group configuration

## License

MIT
