#!/bin/bash

# Azure Container Instance Deployment Script for Redis Benchmarking
# This script automates the deployment and execution of redis-benchmark in Azure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"
IMAGE_NAME="redis-benchmark"
IMAGE_TAG="latest"

echo "=========================================="
echo "  Azure Container Instance Deployment"
echo "  Redis Benchmark Tool"
echo "=========================================="
echo ""

# Check prerequisites
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed!"
    echo "Install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed!"
    echo "Install from: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if logged in to Azure
print_info "Checking Azure login status..."
if ! az account show &> /dev/null; then
    print_warning "Not logged in to Azure"
    print_info "Logging in..."
    az login
fi

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
print_success "Logged in to subscription: $SUBSCRIPTION_ID"
echo ""

# Load Redis configuration
if [ ! -f "$CONFIG_FILE" ]; then
    print_error "config.sh not found!"
    print_info "Please copy config.sh.template to config.sh and fill in your Redis details:"
    print_info "  cp config.sh.template config.sh"
    print_info "  vim config.sh"
    exit 1
fi

source "$CONFIG_FILE"

# Set defaults for optional parameters
REDIS_DB="${REDIS_DB:-0}"
USE_SSL="${USE_SSL:-true}"
REDIS_PORT="${REDIS_PORT:-6380}"
AZURE_LOCATION="${AZURE_LOCATION:-eastus}"

# Set defaults for Azure deployment
if [ -z "$AZURE_RESOURCE_GROUP" ]; then
    AZURE_RESOURCE_GROUP="redis-benchmark-rg"
    print_warning "AZURE_RESOURCE_GROUP not set in config.sh, using default: $AZURE_RESOURCE_GROUP"
fi

# Validate required configuration
if [ -z "$REDIS_HOST" ] || [ -z "$REDIS_PASSWORD" ]; then
    print_error "REDIS_HOST or REDIS_PASSWORD not set in config.sh"
    exit 1
fi

print_success "Configuration loaded"
echo ""
print_info "Redis Configuration:"
print_info "  Host: $REDIS_HOST"
print_info "  Port: $REDIS_PORT"
print_info "  SSL: $USE_SSL"
print_info "  Database: $REDIS_DB"
echo ""
print_info "Azure Configuration:"
print_info "  Resource Group: $AZURE_RESOURCE_GROUP"
print_info "  Location: $AZURE_LOCATION"
print_info "  ACR Name: $ACR_NAME"
echo ""

# Create resource group if it doesn't exist
print_info "Creating resource group (if needed)..."
az group create --name "$AZURE_RESOURCE_GROUP" --location "$AZURE_LOCATION" -o none
print_success "Resource group ready"

# Create Azure Container Registry if it doesn't exist
print_info "Checking Azure Container Registry..."
if ! az acr show --name "$ACR_NAME" --resource-group "$AZURE_RESOURCE_GROUP" &> /dev/null; then
    print_info "Creating Azure Container Registry..."
    az acr create \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --name "$ACR_NAME" \
        --sku Basic \
        --admin-enabled true \
        -o none
    print_success "ACR created"
else
    print_success "ACR already exists"
    # Enable admin if not already enabled
    print_info "Ensuring admin access is enabled..."
    az acr update --name "$ACR_NAME" --admin-enabled true -o none
fi

# Get ACR credentials
ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer -o tsv)
ACR_USERNAME=$(az acr credential show --name "$ACR_NAME" --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name "$ACR_NAME" --query passwords[0].value -o tsv)

print_success "ACR: $ACR_LOGIN_SERVER"
echo ""

# Build Docker image for AMD64 (Azure Container Instances uses x86_64)
print_info "Building Docker image for AMD64 architecture..."

# Check if running on ARM (Apple Silicon)
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
    print_warning "Detected ARM architecture (Apple Silicon)"
    print_warning "Building for AMD64 - this requires Docker with QEMU support"
    
    # Try to build with buildx if available
    if docker buildx version &> /dev/null; then
        print_info "Using docker buildx for cross-platform build..."
        docker buildx build --platform linux/amd64 --load -t "$IMAGE_NAME:$IMAGE_TAG" "$SCRIPT_DIR"
    else
        print_error "Docker buildx not available!"
        print_info "For cross-platform builds on Apple Silicon, you have two options:"
        print_info ""
        print_info "Option 1: Use Azure Cloud Shell or an AMD64 machine"
        print_info "  - Upload your code to Azure Cloud Shell"
        print_info "  - Run the deployment from there"
        print_info ""
        print_info "Option 2: Install Docker Desktop (has buildx support)"
        print_info "  - Docker Desktop includes buildx by default"
        print_info "  - Alternatively, install buildx plugin for Colima"
        print_info ""
        print_info "Option 3: Push to GitHub and use GitHub Actions"
        print_info "  - GitHub Actions runners are AMD64"
        print_info ""
        exit 1
    fi
else
    # Native AMD64 build
    docker build -t "$IMAGE_NAME:$IMAGE_TAG" "$SCRIPT_DIR"
fi

print_success "Image built successfully"

# Tag image for ACR
print_info "Tagging image for ACR..."
docker tag "$IMAGE_NAME:$IMAGE_TAG" "$ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG"

# Login to ACR
print_info "Logging in to ACR..."
az acr login --name "$ACR_NAME"

# Push image to ACR
print_info "Pushing image to ACR..."
docker push "$ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG"
print_success "Image pushed successfully"
echo ""

# Select CPU and memory
echo "Select container size:"
echo "  1) Small  - 1 vCPU, 1.5GB RAM (~$0.004/hour)"
echo "  2) Medium - 2 vCPU, 4GB RAM   (~$0.008/hour)"
echo "  3) Large  - 4 vCPU, 8GB RAM   (~$0.016/hour)"
echo "  4) XLarge - 8 vCPU, 16GB RAM  (~$0.032/hour)"
read -p "Select size (1-4) [3]: " size_selection
size_selection=${size_selection:-3}

case $size_selection in
    1) CPU=1; MEMORY=1.5 ;;
    2) CPU=2; MEMORY=4 ;;
    3) CPU=4; MEMORY=8 ;;
    4) CPU=8; MEMORY=16 ;;
    *) CPU=4; MEMORY=8 ;;
esac

echo ""

# Check if container already exists
print_info "Checking if container already exists..."
if az container show --resource-group "$AZURE_RESOURCE_GROUP" --name "$CONTAINER_NAME" &> /dev/null; then
    print_warning "Container '$CONTAINER_NAME' already exists!"
    read -p "Delete and recreate? (y/n) [y]: " recreate
    recreate=${recreate:-y}
    
    if [ "$recreate" = "y" ] || [ "$recreate" = "Y" ]; then
        print_info "Deleting existing container..."
        az container delete --resource-group "$AZURE_RESOURCE_GROUP" --name "$CONTAINER_NAME" --yes -o none
        print_success "Container deleted"
    else
        print_info "Keeping existing container. You can connect with:"
        echo "  az container exec --resource-group $AZURE_RESOURCE_GROUP --name $CONTAINER_NAME --exec-command /bin/bash"
        exit 0
    fi
fi

echo ""
print_info "Creating container instance with bash access..."
print_info "Container: $CONTAINER_NAME"
print_info "Resources: ${CPU} vCPU, ${MEMORY}GB RAM"
echo ""

# Create container that stays running with tail -f /dev/null
# This keeps the container alive so we can exec into it
az container create \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --name "$CONTAINER_NAME" \
    --image "$ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG" \
    --registry-login-server "$ACR_LOGIN_SERVER" \
    --registry-username "$ACR_USERNAME" \
    --registry-password "$ACR_PASSWORD" \
    --cpu "$CPU" \
    --memory "$MEMORY" \
    --os-type Linux \
    --restart-policy Always \
    --command-line "tail -f /dev/null" \
    --environment-variables \
        REDIS_HOST="$REDIS_HOST" \
        REDIS_PORT="$REDIS_PORT" \
        REDIS_PASSWORD="$REDIS_PASSWORD" \
        USE_SSL="$USE_SSL" \
        REDIS_DB="$REDIS_DB" \
    -o none

print_success "Container created and running!"
echo ""
print_info "Waiting for container to start..."
sleep 5

# Check container status
CONTAINER_STATE=$(az container show --resource-group "$AZURE_RESOURCE_GROUP" --name "$CONTAINER_NAME" --query "instanceView.state" -o tsv)
print_info "Container state: $CONTAINER_STATE"
echo ""

print_success "Container is ready for interactive use!"
echo ""
echo "=========================================="
print_info "To connect to the container, run:"
echo ""
echo "  az container exec --resource-group $AZURE_RESOURCE_GROUP --name $CONTAINER_NAME --exec-command /bin/bash"
echo ""
print_info "Inside the container, you can run benchmarks using:"
echo "  ./run-benchmark.sh"
echo ""
print_info "Or run redis-benchmark directly:"
echo "  redis-benchmark -h \$REDIS_HOST -p \$REDIS_PORT -a \$REDIS_PASSWORD --tls -n 1000 -c 50"
echo ""
echo "=========================================="
echo ""

read -p "Connect to container now? (y/n) [y]: " connect_now
connect_now=${connect_now:-y}

if [ "$connect_now" = "y" ] || [ "$connect_now" = "Y" ]; then
    print_info "Connecting to container..."
    echo ""
    az container exec --resource-group "$AZURE_RESOURCE_GROUP" --name "$CONTAINER_NAME" --exec-command /bin/bash
fi

echo ""
read -p "Delete container instance? (y/n) [n]: " delete_container
delete_container=${delete_container:-n}

if [ "$delete_container" = "y" ] || [ "$delete_container" = "Y" ]; then
    print_info "Deleting container..."
    az container delete --resource-group "$AZURE_RESOURCE_GROUP" --name "$CONTAINER_NAME" --yes -o none
    print_success "Container deleted"
else
    print_warning "Container left running. Delete manually with:"
    echo "  az container delete --resource-group $AZURE_RESOURCE_GROUP --name $CONTAINER_NAME --yes"
fi

echo ""
read -p "Delete Azure Container Registry (ACR)? (y/n) [n]: " delete_acr
delete_acr=${delete_acr:-n}

if [ "$delete_acr" = "y" ] || [ "$delete_acr" = "Y" ]; then
    print_info "Deleting ACR: $ACR_NAME..."
    az acr delete --resource-group "$AZURE_RESOURCE_GROUP" --name "$ACR_NAME" --yes -o none
    print_success "ACR deleted"
else
    print_info "ACR kept: $ACR_NAME"
    print_info "To delete manually: az acr delete --resource-group $AZURE_RESOURCE_GROUP --name $ACR_NAME --yes"
fi

echo ""
print_success "All done!"
print_info "To run another test, execute this script again."
echo ""
