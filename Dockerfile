# Base image is the upstream OpenClaw gateway, pre-built and pushed to ECR
# by the build-base-image workflow.
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

# Add any local configuration or customizations below.
# Examples:
COPY config/ ./config/
COPY skills/ ./skills/

# Static config — baked into the image from git.
# Runtime state dirs (sessions, logs, workspace, credentials) are NOT included;
# they live on EFS and are symlinked at startup by the entrypoint script.
COPY --chown=node:node openclaw/openclaw.json   /home/node/.openclaw/openclaw.json
COPY --chown=node:node openclaw/agents/         /home/node/.openclaw/agents/
COPY --chown=node:node openclaw/hooks/          /home/node/.openclaw/hooks/
COPY --chown=node:node openclaw/completions/    /home/node/.openclaw/completions/
COPY --chown=node:node openclaw/extensions/     /home/node/.openclaw/extensions/

# Install dependencies for custom extensions (memory-pgvector)
RUN cd /home/node/.openclaw/extensions/memory-pgvector && npm install --omit=dev

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
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# Terraform (HashiCorp APT repo)
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com bookworm main" \
      > /etc/apt/sources.list.d/hashicorp.list \
    && apt-get update && apt-get install -y --no-install-recommends terraform \
    && rm -rf /var/lib/apt/lists/*

# Entrypoint script — merges image config with EFS persistent state on ECS.
COPY --chown=node:node script/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Git identity for the agent (commits appear as bradurani)
RUN git config --system user.name "bradurani" \
    && git config --system user.email "bradurani@gmail.com"

RUN chown -R node:node /home/node/.openclaw
USER node

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Override default CMD to bind to LAN (required for ECS + API Gateway traffic)
CMD ["node", "openclaw.mjs", "gateway", "--allow-unconfigured", "--bind", "lan"]