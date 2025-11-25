#!/bin/bash

# Quick setup script for Rediread -p "Redis Password (Access Key): " redis_password
echo ""
read -p "Use SSL/TLS? [true]: " use_ssl
use_ssl=${use_ssl:-true}
read -p "Database Number [0]: " redis_db
redis_db=${redis_db:-0}
echo ""
echo -e "${BLUE}Azure Deployment Configuration (optional):${NC}"
read -p "Azure Resource Group (for deploy-to-aci.sh): " azure_rg
read -p "Azure Location [eastus]: " azure_location
azure_location=${azure_location:-eastus}ormance Benchmark Tool

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "  Redis Benchmark Setup"
echo "==========================================${NC}"
echo ""

# Check if config.sh already exists
if [ -f "config.sh" ]; then
    echo -e "${YELLOW}⚠️  config.sh already exists!${NC}"
    read -p "Do you want to overwrite it? (y/n) [n]: " overwrite
    if [ "$overwrite" != "y" ] && [ "$overwrite" != "Y" ]; then
        echo -e "${GREEN}✓ Keeping existing config.sh${NC}"
        echo ""
        echo "To edit your configuration:"
        echo "  vim config.sh"
        exit 0
    fi
fi

# Copy template
echo -e "${BLUE}Creating config.sh from template...${NC}"
cp config.sh.template config.sh
echo -e "${GREEN}✓ config.sh created${NC}"
echo ""

# Prompt for values
echo -e "${BLUE}Enter your Azure Redis configuration:${NC}"
echo ""

read -p "Redis Host (e.g., myredis.redis.cache.windows.net): " redis_host
read -p "Redis Port [6380]: " redis_port
redis_port=${redis_port:-6380}
read -sp "Redis Password (Access Key): " redis_password
echo ""
read -p "Use SSL/TLS? [true]: " use_ssl
use_ssl=${use_ssl:-true}
read -p "Database Number [0]: " redis_db
redis_db=${redis_db:-0}

# Update config.sh
sed -i.bak "s|REDIS_HOST=\"\"|REDIS_HOST=\"$redis_host\"|g" config.sh
sed -i.bak "s|REDIS_PORT=\"6380\"|REDIS_PORT=\"$redis_port\"|g" config.sh
sed -i.bak "s|REDIS_PASSWORD=\"\"|REDIS_PASSWORD=\"$redis_password\"|g" config.sh
sed -i.bak "s|USE_SSL=\"true\"|USE_SSL=\"$use_ssl\"|g" config.sh
sed -i.bak "s|REDIS_DB=\"0\"|REDIS_DB=\"$redis_db\"|g" config.sh
sed -i.bak "s|AZURE_RESOURCE_GROUP=\"\"|AZURE_RESOURCE_GROUP=\"$azure_rg\"|g" config.sh
sed -i.bak "s|AZURE_LOCATION=\"eastus\"|AZURE_LOCATION=\"$azure_location\"|g" config.sh
rm config.sh.bak

echo ""
echo -e "${GREEN}✓ Configuration saved!${NC}"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT: config.sh contains your password${NC}"
echo "   - Do NOT commit this file to git"
echo "   - It's already in .gitignore"
echo ""
echo -e "${GREEN}Setup complete! You can now run:${NC}"
echo "  ./run-benchmark.sh"
echo ""
echo "Or deploy to Azure Container Instances:"
echo "  ./deploy-to-aci.sh"
echo ""
