#!/bin/bash

set -e

# ==============================================
# 🚀 Engage Docker Build & Tagging Tool
# Version: 1.0.0
# 
# This script helps manage Docker image building and tagging
# for the Engage monorepo. It supports multiple services,
# custom registries, and flexible configuration.
#
# Features:
# - 🔍 Interactive service selection
# - 🏷️ Semantic versioning support
# - 📦 Docker image building with proper context
# - 🔄 Git tag automation
# - 🎨 Colorful console output
#
# Usage:
#   ./git_tag.sh [options]
#
# Options:
#   -c, --config FILE    Path to build config file
#   -r, --registry URL   Override Docker registry URL
#   -p, --product NAME   Override product name
#   -h, --help           Show this help message
#
# Example:
#   ./git_tag.sh -r myregistry.com -p myproduct
# ==============================================

# Default values
DEFAULT_CONFIG_FILE="build/BUILD_CONFIG"
DEFAULT_DOCKER_REGISTRY="docker.nexthouse.org"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
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
      show_help
      exit 0
      ;;
    *)
      echo -e "${RED}❌ Unknown option: $1${NC}"
      show_help
      exit 1
      ;;
  esac
done

# Function to display help
show_help() {
  # Extract the help text from the header comment
  sed -n '2,24p' "$0" | sed 's/^# //'
}

# Load config
CONFIG_FILE="${CONFIG_FILE:-$DEFAULT_CONFIG_FILE}"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo -e "${RED}❌ Config file not found: $CONFIG_FILE${NC}"
  exit 1
fi

# Source the config file in a subshell to avoid variable pollution
# and extract only the variables we need
CONFIG_VARS=$(mktemp)
(
  source "$CONFIG_FILE"
  declare -p DOCKER_REGISTRY PRODUCT_NAME SERVICES 2>/dev/null || true
) > "$CONFIG_VARS"
source "$CONFIG_VARS"
rm -f "$CONFIG_VARS"

# Set product name and registry
PRODUCT_NAME="${PRODUCT_NAME_OVERRIDE:-${PRODUCT_NAME:-engage}}"
DOCKER_REGISTRY="${CUSTOM_REGISTRY:-${DOCKER_REGISTRY:-$DEFAULT_DOCKER_REGISTRY}}"
FULL_REGISTRY="${DOCKER_REGISTRY}/${PRODUCT_NAME}"

# Display header
echo -e "${BLUE}🚀 Engage Docker Image Builder${NC}"
echo -e "${BLUE}==============================${NC}"
echo -e "Config:    ${YELLOW}$CONFIG_FILE${NC}"
echo -e "Registry:  ${YELLOW}$FULL_REGISTRY${NC}"
echo -e "Workspace: ${YELLOW}$(pwd)${NC}"

# Validate services array
if [[ ${#SERVICES[@]} -eq 0 ]]; then
  echo -e "${RED}❌ No services defined in $CONFIG_FILE${NC}"
  exit 1
fi

# List available services
echo -e "\n${GREEN}📋 Available Services:${NC}"
for i in "${!SERVICES[@]}"; do
  IFS='|' read -r service_name image_name build_context dockerfile description <<< "${SERVICES[$i]}"
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

# Clean up any description text that might be in the dockerfile path
DOCKERFILE=$(echo "$DOCKERFILE" | awk '{print $1}')

# Ensure paths are relative to repo root
REPO_ROOT=$(pwd)
if [[ "$BUILD_CONTEXT" != /* ]]; then
    BUILD_CONTEXT="$REPO_ROOT/$BUILD_CONTEXT"
else
    BUILD_CONTEXT="$REPO_ROOT${BUILD_CONTEXT#/}"
fi

# Ensure Dockerfile path is absolute
if [[ "$DOCKERFILE" != /* ]]; then
    DOCKERFILE="$REPO_ROOT/$DOCKERFILE"
else
    DOCKERFILE="$REPO_ROOT${DOCKERFILE#/}"
fi

# For API service, we need to use the repo root as build context
if [[ "$SERVICE" == "api" ]]; then
    BUILD_CONTEXT="$REPO_ROOT"
fi

# Validate paths
if [[ ! -d "$BUILD_CONTEXT" ]]; then
    echo -e "${RED}❌ Build context directory not found: $BUILD_CONTEXT${NC}"
    exit 1
fi

if [[ ! -f "$DOCKERFILE" ]]; then
    echo -e "${RED}❌ Dockerfile not found: $DOCKERFILE${NC}"
    exit 1
fi

# Get relative paths for display
RELATIVE_DOCKERFILE=${DOCKERFILE#$REPO_ROOT/}
RELATIVE_CONTEXT=${BUILD_CONTEXT#$REPO_ROOT/}

# Version input
while true; do
  read -p $'\n🔖 Enter version (e.g., v1.0.0): ' VERSION
  if [[ -n "$VERSION" ]]; then
    if [[ "$VERSION" != v* ]]; then
      VERSION="v$VERSION"
    fi
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
echo -e "Dockerfile: ${YELLOW}${RELATIVE_DOCKERFILE}${NC}"
echo -e "Context:    ${YELLOW}${RELATIVE_CONTEXT}${NC}"
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
echo -e "\n${BLUE}🚀 Next steps:${NC}"
echo -e "1. Jenkins will automatically detect the new tag"
echo -e "2. The following images will be built and pushed:"
echo -e "   • ${FULL_IMAGE}"
echo -e "   • ${LATEST_IMAGE}"

echo -e "\n${GREEN}✨ All done!${NC}"

# ==============================================
# Integration Guide for Other Projects
# ==============================================
# To integrate this script into another project:
#
# 1. Copy this script to your project root
# 2. Create a BUILD_CONFIG file with your services:
#    ```
#    # build/BUILD_CONFIG
#    DOCKER_REGISTRY="your-registry.com"
#    PRODUCT_NAME="your-product"
#    
#    SERVICES=(
#      "service1|service1-image|path/to/context|path/to/Dockerfile|Description 1"
#      "service2|service2-image|path/to/context|path/to/Dockerfile|Description 2"
#    )
#    ```
#
# 3. Make the script executable:
#    chmod +x git_tag.sh
#
# 4. Run the script:
#    ./git_tag.sh
#
# 5. For CI/CD integration (e.g., Jenkins):
#    - Ensure Docker is installed and configured
#    - Set up credentials for your Docker registry
#    - Configure your CI to trigger on tag pushes
# ==============================================
