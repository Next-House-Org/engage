#!/bin/bash

set -e

# Load config from repo root
source "$(pwd)/build/BUILD_CONFIG"

# List available services
echo "Available services:"
for i in "${!SERVICES[@]}"; do
  IFS='|' read -r service_name display_name _ _ <<< "${SERVICES[$i]}"
  echo "  $((i+1))) $service_name"
done

# Prompt for service
read -p "Select a service to build (number): " svc_num
if [[ -z "$svc_num" || ! "$svc_num" =~ ^[0-9]+$ || "$svc_num" -lt 1 || "$svc_num" -gt "${#SERVICES[@]}" ]]; then
  echo "❌ Invalid selection."
  exit 1
fi

# Get the selected service info
SERVICE_INFO="${SERVICES[$((svc_num-1))]}"
IFS='|' read -r SERVICE _ _ _ <<< "$SERVICE_INFO"

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
