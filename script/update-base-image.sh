#!/bin/bash
set -e

# Update and rebuild the openclaw base image from the latest upstream release.
# Skips the build entirely if an image for that release already exists in ECR.

OPENCLAW_DIR="../openclaw"
IMAGE_NAME="openclaw:local"

# ---------------------------------------------------------------------------
# 1. Resolve the latest stable release tag (exclude betas)
# ---------------------------------------------------------------------------
cd "$OPENCLAW_DIR"
git fetch --tags --force origin
RELEASE_TAG=$(git tag --sort=-v:refname | grep -v beta | head -1)
if [ -z "$RELEASE_TAG" ]; then
  echo "Error: no stable release tag found in upstream repo."
  exit 1
fi
echo "Latest upstream release: $RELEASE_TAG"
git checkout "$RELEASE_TAG"
cd - > /dev/null

# Use the tag name (e.g. v2026.2.19) as the ECR image tag.
IMAGE_TAG="$RELEASE_TAG"

# ---------------------------------------------------------------------------
# 2. AWS / ECR setup
# ---------------------------------------------------------------------------
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ -z "$AWS_REGION" ]; then
  echo "Error: AWS_REGION environment variable is not set."
  exit 1
fi
ECR_REPO_NAME="openclaw"
REGISTRY="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
ECR_IMAGE_URI_LATEST="$REGISTRY/$ECR_REPO_NAME:latest"
ECR_IMAGE_URI_TAG="$REGISTRY/$ECR_REPO_NAME:$IMAGE_TAG"

echo "Logging in to ECR..."
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"

# ---------------------------------------------------------------------------
# 3. Check if image for this release already exists in ECR
# ---------------------------------------------------------------------------
set +e
EXISTING_DIGEST=$(aws ecr describe-images \
  --repository-name "$ECR_REPO_NAME" \
  --image-ids imageTag="$IMAGE_TAG" \
  --query 'imageDetails[0].imageDigest' \
  --output text 2>/dev/null)
ECR_CHECK_RC=$?
set -e

if [ $ECR_CHECK_RC -eq 0 ] && [ -n "$EXISTING_DIGEST" ] && [ "$EXISTING_DIGEST" != "None" ]; then
  echo "Base image already exists for $IMAGE_TAG ($EXISTING_DIGEST)"
  echo "Re-tagging as latest..."

  MANIFEST=$(aws ecr batch-get-image \
    --repository-name "$ECR_REPO_NAME" \
    --image-ids imageTag="$IMAGE_TAG" \
    --query 'images[0].imageManifest' \
    --output text)

  # put-image is a no-op if latest already points to this manifest
  aws ecr put-image \
    --repository-name "$ECR_REPO_NAME" \
    --image-tag "latest" \
    --image-manifest "$MANIFEST" 2>/dev/null || true

  echo "Skipped build — reused existing image."
  exit 0
fi

echo "No existing image for $IMAGE_TAG — building..."

# ---------------------------------------------------------------------------
# 4. Build the image
# ---------------------------------------------------------------------------
cd "$OPENCLAW_DIR"
echo "Building Docker base image: $IMAGE_NAME"
docker build --build-arg OPENCLAW_INSTALL_BROWSER=1 -t "$IMAGE_NAME" .
cd - > /dev/null

echo "Base image $IMAGE_NAME built."

# ---------------------------------------------------------------------------
# 5. Tag and push both release tag and latest
# ---------------------------------------------------------------------------
docker tag "$IMAGE_NAME" "$ECR_IMAGE_URI_TAG"
docker tag "$IMAGE_NAME" "$ECR_IMAGE_URI_LATEST"

echo "Pushing $ECR_IMAGE_URI_TAG ..."
docker push "$ECR_IMAGE_URI_TAG"

echo "Pushing $ECR_IMAGE_URI_LATEST ..."
docker push "$ECR_IMAGE_URI_LATEST"

echo "Base image pushed to ECR ($IMAGE_TAG + latest)."
