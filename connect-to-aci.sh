#!/bin/bash

# Quick Connect Script for Redis Benchmark Container
# This script connects to the running Azure Container Instance

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"

# Load configuration
if [ ! -f "$CONFIG_FILE" ]; then
    print_error "config.sh not found!"
    exit 1
fi

source "$CONFIG_FILE"

# Set defaults
AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-redis-benchmark-rg}"
CONTAINER_NAME="${CONTAINER_NAME:-redis-benchmark-aci}"

echo "=========================================="
echo "  Connect to Redis Benchmark Container"
echo "=========================================="
echo ""

# Check if container exists and is running
print_info "Checking container status..."
if ! az container show --resource-group "$AZURE_RESOURCE_GROUP" --name "$CONTAINER_NAME" &> /dev/null; then
    print_error "Container '$CONTAINER_NAME' not found in resource group '$AZURE_RESOURCE_GROUP'"
    print_info "Run ./deploy-to-aci.sh to create the container first"
    exit 1
fi

CONTAINER_STATE=$(az container show --resource-group "$AZURE_RESOURCE_GROUP" --name "$CONTAINER_NAME" --query "instanceView.state" -o tsv)
print_success "Container state: $CONTAINER_STATE"
echo ""

if [ "$CONTAINER_STATE" != "Running" ]; then
    print_error "Container is not in 'Running' state"
    exit 1
fi

print_info "Connecting to container..."
echo ""
echo "=========================================="
print_info "You can run benchmarks using:"
echo "  ./run-benchmark.sh"
echo ""
print_info "Or redis-benchmark directly:"
echo "  redis-benchmark -h \$REDIS_HOST -p \$REDIS_PORT -a \$REDIS_PASSWORD --tls -n 1000 -c 50"
echo ""
print_info "Type 'exit' to disconnect from the container"
echo "=========================================="
echo ""

# Connect to container
az container exec \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --name "$CONTAINER_NAME" \
    --exec-command /bin/bash
