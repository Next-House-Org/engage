#!/bin/bash
# build.sh V.6.0
# Usage: ./build.sh <service> <version>

set -e

SERVICE=$1
VERSION=$2

if [[ -z "$SERVICE" || -z "$VERSION" ]]; then
  echo "❌ Usage: $0 <service> <version>"
  exit 1
fi

# Load config
CONFIG_FILE="$(dirname "$0")/BUILD_CONFIG"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ Config file not found: $CONFIG_FILE"
  exit 1
fi

# Source the config file in a subshell to avoid variable pollution
CONFIG_VARS=$(mktemp)
(
  source "$CONFIG_FILE"
  declare -p DOCKER_REGISTRY PRODUCT_NAME SERVICES 2>/dev/null || true
) > "$CONFIG_VARS"
source "$CONFIG_VARS"
rm -f "$CONFIG_VARS"

# Set defaults
PRODUCT_NAME="${PRODUCT_NAME:-engage}"
DOCKER_REGISTRY="${DOCKER_REGISTRY:-docker.nexthouse.org}"
FULL_REGISTRY="${DOCKER_REGISTRY}/${PRODUCT_NAME}"

# Find the service in the array
SERVICE_INFO=""
for service_info in "${SERVICES[@]}"; do
  IFS='|' read -r service_name image_name context dockerfile description <<< "$service_info"
  if [[ "$service_name" == "$SERVICE" ]]; then
    SERVICE_INFO="$service_info"
    break
  fi
done

if [[ -z "$SERVICE_INFO" ]]; then
  echo "❌ Unknown service: $SERVICE"
  echo "➡️ Available services:"
  for service_info in "${SERVICES[@]}"; do
    IFS='|' read -r service_name _ _ _ _ <<< "$service_info"
    echo "  - $service_name"
  done
  exit 1
fi

# Parse mapping
IFS='|' read -r _ IMAGE_NAME BUILD_CONTEXT DOCKERFILE _ <<< "$SERVICE_INFO"

# Clean up any description text that might be in the dockerfile path
DOCKERFILE=$(echo "$DOCKERFILE" | awk '{print $1}')

# Go to repo root
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Resolve paths
if [[ ! "$BUILD_CONTEXT" =~ ^/ ]]; then
    BUILD_CONTEXT="$REPO_ROOT/$BUILD_CONTEXT"
fi

if [[ ! "$DOCKERFILE" =~ ^/ ]]; then
    DOCKERFILE="$REPO_ROOT/$DOCKERFILE"
fi

# Validate paths
if [[ ! -d "$BUILD_CONTEXT" ]]; then
    echo "❌ Build context directory not found: $BUILD_CONTEXT"
    exit 1
fi

if [[ ! -f "$DOCKERFILE" ]]; then
    echo "❌ Dockerfile not found: $DOCKERFILE"
    exit 1
fi

# Get relative paths for display
RELATIVE_DOCKERFILE=${DOCKERFILE#$REPO_ROOT/}
RELATIVE_CONTEXT=${BUILD_CONTEXT#$REPO_ROOT/}

# Set image tags
FULL_IMAGE="${FULL_REGISTRY}/${IMAGE_NAME}:${VERSION}"
LATEST_IMAGE="${FULL_REGISTRY}/${IMAGE_NAME}:latest"

echo "🚀 Building service: $SERVICE"
echo "➡️ Context: $REPO_ROOT"
echo "➡️ Dockerfile: $RELATIVE_DOCKERFILE"
echo "➡️ Versioned Image: $FULL_IMAGE"
echo "➡️ Latest Image: $LATEST_IMAGE"

# Build and push the image
set -x
cd "$REPO_ROOT"
docker build \
  --build-arg APP_VERSION="$VERSION" \
  -t "$FULL_IMAGE" \
  -t "$LATEST_IMAGE" \
  -f "$DOCKERFILE" \
  --progress=plain \
  .

docker push "$FULL_IMAGE"
docker push "$LATEST_IMAGE"
set +x

echo "✅ Successfully built and pushed $FULL_IMAGE"
echo "✨ All done!"
