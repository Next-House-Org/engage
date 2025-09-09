#!/bin/bash
# build.sh V.5.0
# Usage: ./build.sh <service> <version>

set -e

SERVICE=$1
VERSION=$2

if [[ -z "$SERVICE" || -z "$VERSION" ]]; then
  echo "❌ Usage: ./build.sh <service> <version>"
  exit 1
fi

# Load config
source $(dirname "$0")/BUILD_CONFIG

# Find the service in the array
SERVICE_INFO=""
for service_info in "${SERVICES[@]}"; do
  IFS='|' read -r service_name image_name context dockerfile <<< "$service_info"
  if [[ "$service_name" == "$SERVICE" ]]; then
    SERVICE_INFO="$service_info"
    break
  fi
done

if [[ -z "$SERVICE_INFO" ]]; then
  echo "❌ Unknown service: $SERVICE"
  echo "➡️ Available services:"
  for service_info in "${SERVICES[@]}"; do
    IFS='|' read -r service_name _ _ _ <<< "$service_info"
    echo "  - $service_name"
  done
  exit 1
fi

# Parse mapping
IFS='|' read -r _ IMAGE_NAME CONTEXT DOCKERFILE <<< "$SERVICE_INFO"

FULL_IMAGE="${DOCKER_REGISTRY}/${IMAGE_NAME}:${VERSION}"

# Go to repo root
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "🚀 Building service: $SERVICE"
echo "➡️ Context: $CONTEXT"
echo "➡️ Dockerfile: $DOCKERFILE"
echo "➡️ Image: $FULL_IMAGE"

docker build -t "$FULL_IMAGE" -f "$DOCKERFILE" "$CONTEXT"
docker push "$FULL_IMAGE"
