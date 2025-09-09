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

if [[ -z "${SERVICES[$SERVICE]}" ]]; then
  echo "❌ Unknown service: $SERVICE"
  echo "➡️ Available: ${!SERVICES[@]}"
  exit 1
fi

# Parse mapping
IFS='|' read -r IMAGE_NAME CONTEXT DOCKERFILE <<< "${SERVICES[$SERVICE]}"

FULL_IMAGE="${DOCKER_REGISTRY}/${IMAGE_NAME}:${VERSION}"

echo "🚀 Building service: $SERVICE"
echo "➡️ Context: $CONTEXT"
echo "➡️ Dockerfile: $DOCKERFILE"
echo "➡️ Image: $FULL_IMAGE"

docker build -t "$FULL_IMAGE" -f "$DOCKERFILE" "$CONTEXT"
docker push "$FULL_IMAGE"

