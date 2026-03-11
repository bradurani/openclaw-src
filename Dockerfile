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
    && apt-get update && apt-get install -y --no-install-recommends \
         gh vim nano \
         dnsutils \
         jq \
         libimage-exiftool-perl \
         ffmpeg \
         yt-dlp \
         python3 python3-pip \
         imagemagick \
         poppler-utils \
         libreoffice \
    && rm -rf /var/lib/apt/lists/*

# Terraform (HashiCorp APT repo)
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com bookworm main" \
      > /etc/apt/sources.list.d/hashicorp.list \
    && apt-get update && apt-get install -y --no-install-recommends terraform \
    && rm -rf /var/lib/apt/lists/*

# Whisper CLI (OpenAI Whisper)
# Installs `whisper` command. (Depends on ffmpeg, installed above.)
# NOTE: Debian/Ubuntu images may enforce PEP 668 (externally managed env),
# so we explicitly allow system installs.
RUN python3 -m pip install --no-cache-dir --break-system-packages --upgrade pip \
    && python3 -m pip install --no-cache-dir --break-system-packages openai-whisper

# Google Workspace CLI (gws)
# Installed via npm so we can regularly update it (Dependabot/Renovate can bump pinned version).
ARG GWS_VERSION=latest
RUN npm install -g @googleworkspace/cli@${GWS_VERSION}

# Add any local configuration or customizations below.
# Examples:
COPY config/ ./config/
COPY skills/ ./skills/

# Static config — baked into the image from git.
# Runtime state dirs (sessions, logs, workspace, credentials) are NOT included;
# they live on EFS and are symlinked at startup by the entrypoint script.
COPY --chown=node:node openclaw/completions/    /home/node/src/openclaw/completions/
COPY --chown=node:node openclaw/extensions/     /home/node/src/openclaw/extensions/
COPY --chown=node:node config/patches/          /home/node/src/openclaw/config/patches/

# Install dependencies for custom extensions (memory-pgvector)
RUN cd /home/node/src/openclaw/extensions/memory-pgvector && npm install --omit=dev

# AWS SDK for the SecretRef exec provider (aws-sm-resolver)
# Install to a standalone directory — /app uses pnpm's strict lockfile
# and `npm install` inside it fails with a lockfile parse error.
RUN mkdir -p /opt/aws-sdk && cd /opt/aws-sdk && npm init -y --silent && npm install --no-save @aws-sdk/client-secrets-manager

# Entrypoint script — merges image config with EFS persistent state on ECS.
COPY --chown=node:node script/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chown=node:node script/load-secrets /usr/local/bin/load-secrets
COPY --chown=node:node script/aws-sm-resolver /usr/local/bin/aws-sm-resolver
# The upstream image symlinks /usr/local/bin/openclaw -> /app/openclaw.mjs.
# COPY follows symlinks, so without removing it first the wrapper script would
# overwrite the real Node.js entry point and crash the container.
RUN rm -f /usr/local/bin/openclaw
COPY --chown=node:node script/openclaw-wrapper.sh /usr/local/bin/openclaw
COPY --chown=node:node script/restart-openclaw /usr/local/bin/restart-openclaw
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/load-secrets /usr/local/bin/aws-sm-resolver /usr/local/bin/openclaw /usr/local/bin/restart-openclaw

# Add .bashrc for node user
COPY --chown=node:node .bashrc /home/node/.bashrc

# Git identity for the agent (commits appear as bradurani)
RUN git config --system user.name "bradurani" \
    && git config --system user.email "bradurani@gmail.com"

# Set ownership of the entire src directory to the node user, since some files are copied to the EFS int he entrypoint.
RUN chown -R node:node /home/node/src/openclaw

# Bake the .openclaw -> EFS symlink at build time so the root filesystem can be
# mounted read-only at runtime (readonlyRootFilesystem=true in ECS).
# The base image ships /home/node/.openclaw as a real directory; replace it with
# a symlink to /data/.openclaw (the EFS mount point).  At runtime the entrypoint
# only needs to mkdir on EFS, not touch the root FS.
RUN rm -rf /home/node/.openclaw && ln -sfn /data/.openclaw /home/node/.openclaw

USER node

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Override default CMD to bind to LAN (required for ECS + API Gateway traffic)
CMD ["openclaw", "gateway", "--allow-unconfigured", "--bind", "lan"]
