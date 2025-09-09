#!/bin/bash

set -e

# Load config from repo root
source "$(pwd)/build/BUILD_CONFIG"

# List available services
echo "Available services:"
for i in "${!SERVICES[@]}"; do
  IFS='|' read -r service_name _ _ _ <<< "${SERVICES[$i]}"
  echo "  $((i+1))) $service_name"
done

# Prompt for service
read -p "Select a service to tag (number): " svc_num
if [[ -z "$svc_num" || ! "$svc_num" =~ ^[0-9]+$ || "$svc_num" -lt 1 || "$svc_num" -gt "${#SERVICES[@]}" ]]; then
  echo "❌ Invalid selection."
  exit 1
fi

# Get the selected service
SERVICE_INFO="${SERVICES[$((svc_num-1))]}"
IFS='|' read -r SERVICE _ _ _ <<< "$SERVICE_INFO"

# Prompt for version
read -p "Enter version (e.g., v1.0.0): " VERSION
if [[ -z "$VERSION" ]]; then
  echo "❌ Version cannot be empty."
  exit 1
fi

TAG_NAME="${SERVICE}-${VERSION}"

# Show confirmation
echo "\nYou are about to:"
echo "1. Add all changes to git"
echo "2. Create commit with message: 'Update $SERVICE to $VERSION'"
echo "3. Create and push tag: $TAG_NAME"

read -p "Proceed? (y/n): " confirm
if [[ "$confirm" != "y" ]]; then
  echo "Aborted."
  exit 0
fi

# Execute git operations
echo "\n🔄 Adding changes to git..."
git add .

echo "📝 Creating commit..."
git commit -m "Update $SERVICE to $VERSION"

echo "📡 Pushing changes to remote..."
git push

echo "🏷️  Creating and pushing tag $TAG_NAME..."
git tag -a "$TAG_NAME" -m "Release $SERVICE $VERSION"
git push origin "$TAG_NAME"

echo "\n✅ Successfully created and pushed tag: $TAG_NAME"
echo "Jenkins will now detect the new tag and start the build process."
