#!/bin/bash
set -e

# Update and rebuild the openclaw:local base image from the latest main branch

OPENCLAW_DIR="../openclaw"
IMAGE_NAME="openclaw:local"

# Get the current commit SHA from the openclaw repo
cd "$OPENCLAW_DIR"
COMMIT_SHA=$(git rev-parse --short HEAD)
cd - > /dev/null

cd "$OPENCLAW_DIR"
echo "Pulling latest main branch in $OPENCLAW_DIR..."
git checkout main
git pull origin main

echo "Building Docker base image: $IMAGE_NAME"
docker build --build-arg OPENCLAW_INSTALL_BROWSER=1 -t $IMAGE_NAME .

# Tag image locally with commit SHA
IMAGE_NAME_SHA="openclaw:$COMMIT_SHA"
docker tag $IMAGE_NAME $IMAGE_NAME_SHA

echo "Base image $IMAGE_NAME updated."

# AWS and ECR setup
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ -z "$AWS_REGION" ]; then
  echo "Error: AWS_REGION environment variable is not set."
  exit 1
fi
ECR_REPO_NAME="openclaw" # <-- update as needed
ECR_IMAGE_URI_LATEST="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:latest"
ECR_IMAGE_URI_SHA="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:$COMMIT_SHA"


# Tag image for ECR (latest only)
echo "Tagging image for ECR: $ECR_IMAGE_URI_LATEST"
docker tag $IMAGE_NAME $ECR_IMAGE_URI_LATEST

echo "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com


echo "Pushing image to ECR: $ECR_IMAGE_URI_LATEST"
docker push $ECR_IMAGE_URI_LATEST

echo "Image pushed to ECR successfully."
