#!/bin/bash

set -e

# Default values
DEFAULT_CONFIG_FILE="build/BUILD_CONFIG"
DEFAULT_DOCKER_REGISTRY="docker.nexthouse.org"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -c|--config)
      CONFIG_FILE="$2"
      shift 2
      ;;
    -r|--registry)
      CUSTOM_REGISTRY="$2"
      shift 2
      ;;
    -p|--product)
      PRODUCT_NAME_OVERRIDE="$2"
      shift 2
      ;;
    -h|--help)
      echo -e "${GREEN}Usage: $0 [options]${NC}"
      echo -e "Options:"
      echo -e "  -c, --config FILE    Path to build config file (default: build/BUILD_CONFIG)"
      echo -e "  -r, --registry URL   Override Docker registry URL"
      echo -e "  -p, --product NAME   Override product name"
      echo -e "  -h, --help           Show this help message"
      exit 0
      ;;
    *)
      echo -e "${YELLOW}Unknown option: $1${NC}"
      exit 1
      ;;
  esac
done

# Load config
CONFIG_FILE="${CONFIG_FILE:-$DEFAULT_CONFIG_FILE}"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo -e "${YELLOW}❌ Config file not found: $CONFIG_FILE${NC}"
  exit 1
fi
source "$CONFIG_FILE"

# Set product name and registry
PRODUCT_NAME="${PRODUCT_NAME_OVERRIDE:-$PRODUCT_NAME}"
DOCKER_REGISTRY="${CUSTOM_REGISTRY:-$DOCKER_REGISTRY}"
FULL_REGISTRY="${DOCKER_REGISTRY}/${PRODUCT_NAME}"

# Display header
echo -e "${BLUE}🚀 Docker Image Builder${NC}"
echo -e "${BLUE}======================${NC}"
echo -e "Config: ${YELLOW}$CONFIG_FILE${NC}"
echo -e "Registry: ${YELLOW}$FULL_REGISTRY${NC}"

# List available services
echo -e "\n${GREEN}📋 Available Services:${NC}"
for i in "${!SERVICES[@]}"; do
  IFS='|' read -r service_name image_name _ _ description <<< "${SERVICES[$i]}"
  printf "${BLUE}%2d) ${NC}%-15s ${YELLOW}%s${NC}\n" "$((i+1))" "$service_name" "${description:-No description}"
done

# Service selection
while true; do
  read -p $'\n🔢 Select a service (number): ' svc_num
  if [[ "$svc_num" =~ ^[0-9]+$ && "$svc_num" -ge 1 && "$svc_num" -le "${#SERVICES[@]}" ]]; then
    break
  fi
  echo -e "${YELLOW}❌ Invalid selection. Please enter a number between 1 and ${#SERVICES[@]}${NC}"
done

# Get selected service info
SERVICE_INFO="${SERVICES[$((svc_num-1))]}"
IFS='|' read -r SERVICE IMAGE_NAME BUILD_CONTEXT DOCKERFILE DESCRIPTION <<< "$SERVICE_INFO"

# Version input
while true; do
  read -p $'\n🔖 Enter version (e.g., v1.0.0): ' VERSION
  if [[ -n "$VERSION" ]]; then
    break
  fi
  echo -e "${YELLOW}❌ Version cannot be empty${NC}"
done

# Set image tags
TAG_NAME="${SERVICE}-${VERSION}"
FULL_IMAGE="${FULL_REGISTRY}/${IMAGE_NAME}:${VERSION}"
LATEST_IMAGE="${FULL_REGISTRY}/${IMAGE_NAME}:latest"

# Show confirmation
echo -e "\n${GREEN}📝 Release Summary:${NC}"
echo -e "Service:    ${BLUE}${SERVICE}${NC} (${DESCRIPTION:-No description})"
echo -e "Version:    ${BLUE}${VERSION}${NC}"
echo -e "Dockerfile: ${YELLOW}${DOCKERFILE}${NC}"
echo -e "Context:    ${YELLOW}${BUILD_CONTEXT}${NC}"
echo -e "Images to build:"
echo -e "  • ${FULL_IMAGE}"
echo -e "  • ${LATEST_IMAGE}"

read -p $'\n✅ Proceed with release? (y/n): ' confirm
if [[ "$confirm" != "y" ]]; then
  echo -e "${YELLOW}❌ Release cancelled${NC}"
  exit 0
fi

# Execute git operations
echo -e "\n${BLUE}🔄 Updating git repository...${NC}"
git add .

echo -e "\n${BLUE}📝 Creating commit...${NC}"
git commit -m "Update ${SERVICE} to ${VERSION}" || echo -e "${YELLOW}⚠️  No changes to commit${NC}"

echo -e "\n${BLUE}📡 Pushing changes to remote...${NC}"
git push

echo -e "\n${BLUE}🏷️  Creating and pushing tag ${TAG_NAME}...${NC}"
git tag -f -a "$TAG_NAME" -m "Release ${SERVICE} ${VERSION}"
git push -f origin "$TAG_NAME"

echo -e "\n${GREEN}✅ Release ${TAG_NAME} created successfully!${NC}"
echo -e "\n${BLUE}🚀 Jenkins will now build and push:${NC}"
echo -e "• ${FULL_IMAGE}"
echo -e "• ${LATEST_IMAGE}"
echo -e "\n${GREEN}✨ All done!${NC}"
