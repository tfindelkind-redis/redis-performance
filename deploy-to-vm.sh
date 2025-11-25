#!/bin/bash
# Azure VM Deployment Script for Redis Benchmarking
# Provisions a VM, installs dependencies, and copies benchmark scripts

set -e

# Load config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "config.sh not found!" >&2
  exit 1
fi

source "$CONFIG_FILE"




# Create VM if it does not exist, with error checking and verbose output
if ! az vm show -g "$AZURE_RESOURCE_GROUP" -n "$VM_NAME" &>/dev/null; then
  echo "[INFO] Creating VM $VM_NAME in resource group $AZURE_RESOURCE_GROUP..."
  az vm create \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --name "$VM_NAME" \
  --image Ubuntu2204 \
    --admin-username "$ADMIN_USER" \
    --generate-ssh-keys \
    --public-ip-sku Standard \
    --size Standard_D4s_v3 \
    --verbose
  VM_CREATE_EXIT_CODE=$?
  if [ $VM_CREATE_EXIT_CODE -ne 0 ]; then
    echo "[ERROR] az vm create failed with exit code $VM_CREATE_EXIT_CODE. Aborting." >&2
    exit $VM_CREATE_EXIT_CODE
  fi
  echo "[INFO] VM creation complete."
else
  echo "[INFO] VM $VM_NAME already exists. Skipping creation."
fi

# Get public IP (avoid instanceView bug)
VM_IP=$(az vm list-ip-addresses -g "$AZURE_RESOURCE_GROUP" -n "$VM_NAME" --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" -o tsv)
echo "VM Public IP: $VM_IP"

# Get all related resource names
NIC_NAME=$(az vm show -g "$AZURE_RESOURCE_GROUP" -n "$VM_NAME" --query 'networkProfile.networkInterfaces[0].id' -o tsv | awk -F/ '{print $NF}')
NSG_NAME=$(az network nic show -g "$AZURE_RESOURCE_GROUP" -n "$NIC_NAME" --query 'networkSecurityGroup.id' -o tsv | awk -F/ '{print $NF}')
PUBLIC_IP_NAME=$(az network nic show -g "$AZURE_RESOURCE_GROUP" -n "$NIC_NAME" --query 'ipConfigurations[0].publicIpAddress.id' -o tsv | awk -F/ '{print $NF}')
DISK_NAME=$(az vm show -g "$AZURE_RESOURCE_GROUP" -n "$VM_NAME" --query 'storageProfile.osDisk.name' -o tsv)

# Write all info to config file for later use
VM_CONFIG_FILE="$SCRIPT_DIR/vm-connection-info.sh"
echo "VM_IP=\"$VM_IP\"" > "$VM_CONFIG_FILE"
echo "VM_NAME=\"$VM_NAME\"" >> "$VM_CONFIG_FILE"
echo "ADMIN_USER=\"$ADMIN_USER\"" >> "$VM_CONFIG_FILE"
echo "AZURE_RESOURCE_GROUP=\"$AZURE_RESOURCE_GROUP\"" >> "$VM_CONFIG_FILE"
echo "NIC_NAME=\"$NIC_NAME\"" >> "$VM_CONFIG_FILE"
echo "NSG_NAME=\"$NSG_NAME\"" >> "$VM_CONFIG_FILE"
echo "PUBLIC_IP_NAME=\"$PUBLIC_IP_NAME\"" >> "$VM_CONFIG_FILE"
echo "DISK_NAME=\"$DISK_NAME\"" >> "$VM_CONFIG_FILE"
echo "VM config written to $VM_CONFIG_FILE"


# Wait for SSH to become available
echo "[INFO] Waiting for SSH to become available on $VM_IP..."
for i in {1..30}; do
  if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$ADMIN_USER@$VM_IP" 'echo ok' 2>/dev/null; then
    echo "[INFO] SSH is available."
    break
  fi
  sleep 5
  if [ $i -eq 30 ]; then
    echo "[ERROR] SSH did not become available after 30 attempts. Aborting." >&2
    exit 1
  fi
done

# Copy scripts to VM
echo "[INFO] Copying scripts to VM..."
scp -r -o StrictHostKeyChecking=no "$SCRIPT_DIR/"* "$ADMIN_USER@$VM_IP":~/


# Install dependencies and Redis 7.4 with TLS on VM (run only once)
echo "[INFO] Installing dependencies and Redis 7.4 with TLS on VM..."
ssh -o StrictHostKeyChecking=no "$ADMIN_USER@$VM_IP" <<'ENDSSH'
set -e
if [ ! -f "$HOME/.redis74_installed" ]; then
  sudo apt-get update
  sudo apt-get install -y python3 python3-venv python3-pip redis-tools
  python3 -m venv ~/venv
  ~/venv/bin/pip install --upgrade pip
  ~/venv/bin/pip install redis
  chmod +x ~/run-benchmark.sh ~/run-two-step-test.sh
  chmod +x ~/install-redis74-tls.sh
  chmod +x ~/install-memtier.sh
  bash ~/install-redis74-tls.sh
  bash ~/install-memtier.sh
else
  echo "[INFO] Redis 7.4 with TLS and memtier_benchmark already installed. Skipping install."
fi
ENDSSH

echo "[INFO] VM setup complete. SSH with: ssh $ADMIN_USER@$VM_IP"
echo "[INFO] To run the test: ssh $ADMIN_USER@$VM_IP '~/venv/bin/bash ~/run-two-step-test.sh'"
