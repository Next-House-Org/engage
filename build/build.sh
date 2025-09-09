#!/bin/bash
# build.sh V.3.0
# Usage: ./build.sh <service> <tag>

set -e

if ! source ./BUILD_CONFIG; then
  echo "❌ Failed to source BUILD_CONFIG"
  exit 1
fi

SERVICE=$1
TAG=$2

if [ -z "$SERVICE" ] || [ -z "$TAG" ]; then
  echo "Usage: $0 <service> <tag>"
  echo "Available services: ${!SERVICES[@]}"
  exit 1
fi

IMAGE="${DOCKER_REGISTRY}/${SERVICES[$SERVICE]}"

echo "🚀 Building service: $SERVICE"
echo "➡️  Image: $IMAGE"
echo "➡️  Tag: $TAG"

cd ../ || { echo "Failed to change directory"; exit 1; }

# Build using the correct Dockerfile
docker build -f packages/$SERVICE/Dockerfile -t $IMAGE:$TAG -t $IMAGE:latest .

echo "✅ Build complete: $IMAGE:$TAG"

