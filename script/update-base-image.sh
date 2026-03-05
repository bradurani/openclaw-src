#!/bin/bash
set -e

# Update and rebuild the openclaw base image from the latest upstream main branch.
# Skips the build entirely if an image for the current commit already exists in ECR.

OPENCLAW_DIR="../openclaw"
IMAGE_NAME="openclaw:local"

# ---------------------------------------------------------------------------
# 1. Resolve the latest upstream commit
# ---------------------------------------------------------------------------
cd "$OPENCLAW_DIR"
echo "Pulling latest main branch in $OPENCLAW_DIR..."
git checkout main
git pull origin main
COMMIT_SHA=$(git rev-parse --short HEAD)
cd - > /dev/null

echo "Upstream openclaw commit: $COMMIT_SHA"

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
ECR_IMAGE_URI_SHA="$REGISTRY/$ECR_REPO_NAME:$COMMIT_SHA"

echo "Logging in to ECR..."
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"

# ---------------------------------------------------------------------------
# 3. Check if image for this commit already exists in ECR
# ---------------------------------------------------------------------------
set +e
EXISTING_DIGEST=$(aws ecr describe-images \
  --repository-name "$ECR_REPO_NAME" \
  --image-ids imageTag="$COMMIT_SHA" \
  --query 'imageDetails[0].imageDigest' \
  --output text 2>/dev/null)
ECR_CHECK_RC=$?
set -e

if [ $ECR_CHECK_RC -eq 0 ] && [ -n "$EXISTING_DIGEST" ] && [ "$EXISTING_DIGEST" != "None" ]; then
  echo "Base image already exists for commit $COMMIT_SHA ($EXISTING_DIGEST)"
  echo "Re-tagging as latest..."

  MANIFEST=$(aws ecr batch-get-image \
    --repository-name "$ECR_REPO_NAME" \
    --image-ids imageTag="$COMMIT_SHA" \
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

echo "No existing image for commit $COMMIT_SHA — building..."

# ---------------------------------------------------------------------------
# 4. Build the image
# ---------------------------------------------------------------------------
cd "$OPENCLAW_DIR"
echo "Building Docker base image: $IMAGE_NAME"
docker build --build-arg OPENCLAW_INSTALL_BROWSER=1 -t "$IMAGE_NAME" .
cd - > /dev/null

echo "Base image $IMAGE_NAME built."

# ---------------------------------------------------------------------------
# 5. Tag and push both commit SHA and latest
# ---------------------------------------------------------------------------
docker tag "$IMAGE_NAME" "$ECR_IMAGE_URI_SHA"
docker tag "$IMAGE_NAME" "$ECR_IMAGE_URI_LATEST"

echo "Pushing $ECR_IMAGE_URI_SHA ..."
docker push "$ECR_IMAGE_URI_SHA"

echo "Pushing $ECR_IMAGE_URI_LATEST ..."
docker push "$ECR_IMAGE_URI_LATEST"

echo "Base image pushed to ECR ($COMMIT_SHA + latest)."
