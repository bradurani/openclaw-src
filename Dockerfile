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

# Entrypoint script — merges image config with EFS persistent state on ECS.
COPY --chown=node:node script/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

RUN chown -R node:node /home/node/.openclaw
USER node

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Override default CMD to bind to LAN (required for ECS + API Gateway traffic)
CMD ["node", "openclaw.mjs", "gateway", "--allow-unconfigured", "--bind", "lan"]