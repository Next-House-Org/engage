#!/bin/bash
# build.sh V.3.0
# Usage: ./build.sh <service> <tag>


#!/bin/bash
SERVICE=$1
VERSION=$2

echo "🚀 Building service: $SERVICE"
echo "➡️  Image: docker.nexthouse.org/$SERVICE"
echo "➡️  Tag: $VERSION"

docker build -t docker.nexthouse.org/$SERVICE:$VERSION ./services/$SERVICE
docker push docker.nexthouse.org/$SERVICE:$VERSION

