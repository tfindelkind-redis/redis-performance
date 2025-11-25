# Setup Instructions

## First-Time Setup

1. **Create your configuration file from template**:
   ```bash
   cp config.sh.template config.sh
   ```

2. **Edit config.sh with your actual Redis credentials**:
   ```bash
   vim config.sh
   # or
   nano config.sh
   ```

3. **Fill in your Azure Redis details**:
   - `REDIS_HOST`: Your Azure Redis hostname (e.g., myredis.redis.cache.windows.net)
   - `REDIS_PORT`: Port number (usually 6380 for SSL, 6379 for non-SSL)
   - `REDIS_PASSWORD`: Your access key from Azure Portal
   - `USE_SSL`: Set to "true" for Azure Redis (recommended)
   - `REDIS_DB`: Database number (usually 0)

4. **Run the benchmark**:
   ```bash
   ./run-benchmark.sh
   ```

## Important Notes

- ⚠️ **Never commit config.sh** - It contains your Redis password!
- ✅ **config.sh is in .gitignore** - Your credentials are safe
- 📝 **config.sh.template** is tracked in git as a reference
- 🔑 Keep your access keys secure

## Finding Your Azure Redis Credentials

1. Go to Azure Portal
2. Navigate to your Azure Cache for Redis instance
3. Click on "Access keys" in the left menu
4. Copy the "Primary connection string" or use:
   - Host: shown in the Overview
   - Port: 6380 (SSL) or 6379 (non-SSL)
   - Primary key: from Access keys section
