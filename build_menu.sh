#!/bin/bash

set -e

# Load config from repo root
source "$(pwd)/build/BUILD_CONFIG"

# List available services
echo "Available services:"
i=1
SERVICE_NAMES=()
for svc in "${SERVICES[@]}"; do
  echo "  $i) $svc"
  SERVICE_NAMES+=("$svc")
  ((i++))
done

# Prompt for service
read -p "Select a service to build (number): " svc_num
if [[ -z "$svc_num" || "$svc_num" -lt 1 || "$svc_num" -gt "${#SERVICE_NAMES[@]}" ]]; then
  echo "❌ Invalid selection."
  exit 1
fi
SERVICE_INDEX=$((svc_num-1))
SERVICE="${SERVICE_NAMES[$SERVICE_INDEX]}"

# Prompt for version
read -p "Enter version (e.g., v1.0.0): " VERSION
if [[ -z "$VERSION" ]]; then
  echo "❌ Version cannot be empty."
  exit 1
fi

# Confirm
echo "You selected: $SERVICE, version: $VERSION"
read -p "Proceed with build, commit, tag, and push? (y/n): " confirm
if [[ "$confirm" != "y" ]]; then
  echo "Aborted."
  exit 0
fi

# Run build
./build/build.sh "$SERVICE" "$VERSION"

# Git operations
git add .
git commit -m "Build & Deploy $SERVICE $VERSION"
git push
git tag "$SERVICE-$VERSION"
git push origin "$SERVICE-$VERSION"

echo "✅ Done!"