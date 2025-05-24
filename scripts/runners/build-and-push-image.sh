#!/bin/bash
set -eo pipefail

# Get environment variables or parameters
REGISTRY=${1:-$REGISTRY}
VERSION=${2:-$VERSION}
PLATFORM=${3:-"linux/arm64"}
ARCH=${4:-"arm64"}
REPO=$5
APP_PATH=$6
CONTAINERFILE_PATH=${7:-"./Containerfile"}

# Ensure required variables are set
if [ -z "$REGISTRY" ] || [ -z "$REPO" ] || [ -z "$VERSION" ]; then
  echo "Error: Required variables not set. Need REGISTRY, and VERSION."
  exit 1
fi

echo "Building and pushing image..."
echo "- Registry: $REGISTRY"
echo "- Image: $REPO"
echo "- Version: $VERSION"
echo "- Platform: $PLATFORM"
echo "- Architecture: $ARCH"

echo "Checking Containerfile location..."
# Verify the Containerfile exists
if [ ! -f "$CONTAINERFILE_PATH" ]; then
  echo "ERROR: Containerfile not found at $CONTAINERFILE_PATH"
  echo "Current directory: $(pwd)"
  exit 1
fi

echo "Verifying registry login..."
if ! docker buildx ls | grep -q "logged in"; then
  echo "WARNING: You might not be logged in to the registry. Try running:"
  echo "  echo \$GITHUB_TOKEN | docker login ${REGISTRY} -u \$GITHUB_ACTOR --password-stdin"
fi

echo "Tagging image..."
LATEST_TAG="${REGISTRY}/customeros/${REPO}:latest"
LATEST_ARCH_TAG="${REGISTRY}/customeros/${REPO}:latest-${ARCH}"
VERSION_TAG="${REGISTRY}/customeros/${REPO}:${VERSION}"
VERSION_ARCH_TAG="${REGISTRY}/customeros/${REPO}:${VERSION}-${ARCH}"
  
# Use Docker buildx to create and push the latest tags
docker buildx prune -a -f


echo "Building and pushing image with buildx..."
if ! docker buildx build \
  --push \
  --tag ${LATEST_TAG} \
  --tag ${LATEST_ARCH_TAG} \
  --tag ${VERSION_TAG} \
  --tag ${VERSION_ARCH_TAG} \
  --no-cache \
  --provenance=false \
  --file ${CONTAINERFILE_PATH} \
  .; then
  echo "ERROR: Failed to build and push image"
  echo "Checking Docker login status..."
  docker login ${REGISTRY} --username ${GITHUB_ACTOR} --password-stdin <<< "${GITHUB_TOKEN}"
  exit 1
fi

echo "Image build and push completed successfully"
echo "- ${LATEST_TAG}"
echo "- ${LATEST_ARCH_TAG}" 
echo "- ${VERSION_TAG}"
echo "- ${VERSION_ARCH_TAG}"
exit 0
