# Base image is the upstream OpenClaw gateway, pre-built and pushed to ECR
# by the build-base-image workflow.
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

# Add any local configuration or customizations below.
# Examples:
#   COPY config/ ./config/
#   COPY skills/ ./skills/
#   ENV OPENCLAW_SOME_SETTING=value

# Override default CMD to bind to LAN (required for ECS + API Gateway traffic)
CMD ["node", "openclaw.mjs", "gateway", "--allow-unconfigured", "--bind", "lan"]
