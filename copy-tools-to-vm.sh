#!/bin/bash
# Copy tools and profiles to the VM using vm-connection-info.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_CONFIG_FILE="$SCRIPT_DIR/vm-connection-info.sh"

if [ ! -f "$VM_CONFIG_FILE" ]; then
  echo "VM config file not found: $VM_CONFIG_FILE" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$VM_CONFIG_FILE"

if [ -z "$VM_IP" ] || [ -z "$ADMIN_USER" ]; then
  echo "VM_IP or ADMIN_USER not set in $VM_CONFIG_FILE" >&2
  exit 1
fi

# Copy all scripts and profiles to the VM home directory
scp -r -o StrictHostKeyChecking=no "$SCRIPT_DIR/"* "$ADMIN_USER@$VM_IP":~/

echo "Copied all tools and profiles to $ADMIN_USER@$VM_IP:~/"
