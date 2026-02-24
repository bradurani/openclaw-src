# Base image is the upstream OpenClaw gateway, pre-built and pushed to ECR
# by the build-base-image workflow.
ARG BASE_IMAGE=728951607453.dkr.ecr.us-west-2.amazonaws.com/openclaw:latest
FROM ${BASE_IMAGE}

# ---------------------------------------------------------------------------
# CLI tools: AWS CLI, GitHub CLI, Terraform
# ---------------------------------------------------------------------------
USER root

# AWS CLI v2
RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o /tmp/awscli.zip \
    && unzip -q /tmp/awscli.zip -d /tmp \
    && /tmp/aws/install \
    && rm -rf /tmp/aws /tmp/awscli.zip

# GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh vim nano \
    && rm -rf /var/lib/apt/lists/*

# Terraform (HashiCorp APT repo)
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com bookworm main" \
      > /etc/apt/sources.list.d/hashicorp.list \
    && apt-get update && apt-get install -y --no-install-recommends terraform \
    && rm -rf /var/lib/apt/lists/*

# Add any local configuration or customizations below.
# Examples:
COPY config/ ./config/
COPY skills/ ./skills/

# Static config — baked into the image from git.
# Runtime state dirs (sessions, logs, workspace, credentials) are NOT included;
# they live on EFS and are symlinked at startup by the entrypoint script.
COPY --chown=node:node openclaw/completions/    /home/node/src/openclaw/completions/
COPY --chown=node:node openclaw/extensions/     /home/node/src/openclaw/extensions/

# Install dependencies for custom extensions (memory-pgvector)
RUN cd /home/node/src/openclaw/extensions/memory-pgvector && npm install --omit=dev

# Entrypoint script — merges image config with EFS persistent state on ECS.
COPY --chown=node:node script/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && printf '%s\n' '#!/bin/sh' 'exec node /app/openclaw.mjs "$@"' > /usr/local/bin/openclaw \
    && chmod +x /usr/local/bin/openclaw

# Add .bashrc for node user
COPY --chown=node:node .bashrc /home/node/.bashrc

# Git identity for the agent (commits appear as bradurani)
RUN git config --system user.name "bradurani" \
    && git config --system user.email "bradurani@gmail.com"

# Set ownership of the entire src directory to the node user, since some files are copied to the EFS int he entrypoint.
RUN chown -R node:node /home/node/src/openclaw
USER node

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Override default CMD to bind to LAN (required for ECS + API Gateway traffic)
CMD ["openclaw", "gateway", "--allow-unconfigured", "--bind", "lan"]
