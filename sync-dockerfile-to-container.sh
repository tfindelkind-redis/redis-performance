#!/bin/bash


# Dynamic sync script: copies all files/folders from Dockerfile COPY lines to a running container
# Gets container name from config.sh (CONTAINER_NAME)
# Usage: ./sync-dockerfile-to-container.sh

CONFIG_FILE="config.sh"
DOCKERFILE="Dockerfile"

# Extract CONTAINER_NAME from config.sh
if [[ -f "$CONFIG_FILE" ]]; then
  CONTAINER_NAME=$(grep '^CONTAINER_NAME=' "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '"')
else
  echo "Error: $CONFIG_FILE not found."
  exit 1
fi

if [[ -z "$CONTAINER_NAME" ]]; then
  echo "Error: CONTAINER_NAME not set in $CONFIG_FILE."
  exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
  echo "Error: Container '$CONTAINER_NAME' is not running."
  exit 1
fi

# Parse COPY lines from Dockerfile
awk '/^COPY / { 
  for (i=2; i<=NF-1; i++) print $i, $NF
}' "$DOCKERFILE" | while read -r src dest; do
  # Remove trailing slashes for files
  src_clean="${src%/}"
  dest_clean="${dest%/}"
  # If dest is absolute, use as is; else, prepend /app/
  if [[ "$dest_clean" == /* ]]; then
    target="$dest_clean"
  else
    target="/app/$dest_clean"
  fi
  echo "Copying $src_clean to $CONTAINER_NAME:$target"
  docker cp "$src_clean" "$CONTAINER_NAME":"$target"
done

# Make scripts executable inside the container
for script in /app/run-benchmark.sh /app/run-two-step-test.sh; do
  docker exec "$CONTAINER_NAME" chmod +x "$script" 2>/dev/null
done

echo "Sync complete."
