#!/bin/bash
# Delete VM and all related Azure resources using vm-connection-info.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_CONFIG_FILE="$SCRIPT_DIR/vm-connection-info.sh"

if [ ! -f "$VM_CONFIG_FILE" ]; then
  echo "VM config file not found: $VM_CONFIG_FILE" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$VM_CONFIG_FILE"

if [ -z "$AZURE_RESOURCE_GROUP" ] || [ -z "$VM_NAME" ] || [ -z "$NIC_NAME" ] || [ -z "$NSG_NAME" ] || [ -z "$PUBLIC_IP_NAME" ] || [ -z "$DISK_NAME" ]; then
  echo "One or more required resource names are missing in $VM_CONFIG_FILE" >&2
  exit 1
fi

echo "Deleting VM: $VM_NAME"
az vm delete --yes --no-wait --resource-group "$AZURE_RESOURCE_GROUP" --name "$VM_NAME"

echo "Deleting NIC: $NIC_NAME"
az network nic delete --resource-group "$AZURE_RESOURCE_GROUP" --name "$NIC_NAME"

echo "Deleting NSG: $NSG_NAME"
az network nsg delete --resource-group "$AZURE_RESOURCE_GROUP" --name "$NSG_NAME"

echo "Deleting Public IP: $PUBLIC_IP_NAME"
az network public-ip delete --resource-group "$AZURE_RESOURCE_GROUP" --name "$PUBLIC_IP_NAME"

echo "Deleting Disk: $DISK_NAME"
az disk delete --yes --resource-group "$AZURE_RESOURCE_GROUP" --name "$DISK_NAME"

echo "All resources deleted. (Resource group $AZURE_RESOURCE_GROUP remains unless you delete it manually.)"
