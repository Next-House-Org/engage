#!/bin/bash
# build.sh V.4.0
# Usage: ./build.sh <service> <version>
# Example: ./build.sh admin-cli v1.0.0-19

set -euo pipefail

SERVICE=$1
VERSION=$2

# Load build config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/BUILD_CONFIG"

# Validate service
if [[ -z "${SERVICES[$SERVICE]+x}" ]]; then
  echo "❌ Unknown service: $SERVICE"
  echo "Available services: ${!SERVICES[@]}"
  exit 1
fi

IMAGE_NAME="${DOCKER_REGISTRY}/${SERVICES[$SERVICE]}"

echo "🚀 Building service: $SERVICE"
echo "➡️  Image: ${IMAGE_NAME}"
echo "➡️  Tag: ${VERSION}"

docker build -t "${IMAGE_NAME}:${VERSION}" "./services/${SERVICE}"
docker push "${IMAGE_NAME}:${VERSION}"

