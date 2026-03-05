# openclaw-src

Private deployment layer on top of the upstream [OpenClaw](https://github.com/openclaw/openclaw) gateway. This repo owns the **Dockerfile**, config patches, custom scripts, and the CI/CD pipeline that builds a derived Docker image and deploys it to **AWS ECS Fargate**.

## Architecture

```
┌──────────────────────────────────────────────────┐
│  upstream openclaw/openclaw (public)             │
│  → built & pushed to ECR as  openclaw:latest     │
└──────────────┬───────────────────────────────────┘
               │ FROM openclaw:latest
┌──────────────▼───────────────────────────────────┐
│  this repo (openclaw-src)                        │
│  + AWS CLI, GitHub CLI, Terraform, jq            │
│  + config patches, skills, extensions            │
│  + entrypoint & wrapper scripts                  │
│  → built & pushed to ECR as  openclaw-src:<sha>  │
└──────────────┬───────────────────────────────────┘
               │
┌──────────────▼───────────────────────────────────┐
│  ECS Fargate  (cluster: openclaw)                │
│  + EFS for persistent state (~/.openclaw)        │
│  + Secrets Manager for credentials               │
└──────────────────────────────────────────────────┘
```

## Deploy process

Deploys are fully automated via the [deploy workflow](.github/workflows/deploy.yml). A push to `main` that touches any deploy-relevant path triggers a build and deploy.

### Trigger paths

Changes to any of these paths trigger the workflow on push to `main`:

- `Dockerfile`
- `config/**`
- `skills/**`
- `openclaw/**`
- `script/**`
- `.github/workflows/deploy.yml`

The workflow can also be triggered manually via `workflow_dispatch`.

### What happens on deploy

1. **check-skip** — Extracts the PR number from the squash-merge commit message and looks up its labels.
2. **build-and-deploy** (skipped if `skip deploy` label is present):
   - Computes a context hash of all deploy-relevant files.
   - If the `upgrade openclaw` label is set, clones upstream openclaw and rebuilds the **base image** (`openclaw:latest` in ECR).
   - Builds the **derived image** (`openclaw-src`) from the base image with our Dockerfile customizations.
   - Compares the new image digest against what's currently running — if unchanged, the deploy is skipped.
   - Registers a new ECS task definition and updates the service.
   - Waits for ECS to reach steady state (`services-stable`).
   - Writes a deploy manifest (JSON) to both a GitHub Actions artifact and S3.

### PR labels

| Label | Effect |
|-------|--------|
| **`upgrade openclaw`** | Rebuilds the base image from the latest upstream openclaw source before building the derived image. Use this when you want to pull in upstream changes. |
| **`skip deploy`** | Skips the entire build-and-deploy job. The workflow will complete immediately with no ECS changes. Useful for documentation-only or config changes that shouldn't trigger a deploy. |

Labels are read from the merged PR via the GitHub API. If no PR number is found in the commit message (e.g. a direct push), label checks are skipped and the deploy proceeds normally without a base image upgrade.

## Project layout

```
Dockerfile              # Derived image — extends upstream base with tools & config
config/patches/         # Idempotent jq patches applied to openclaw.json on startup
openclaw/completions/   # Shell completions baked into the image
openclaw/extensions/    # Custom extensions (e.g. memory-pgvector)
script/
  entrypoint.sh         # EFS symlink setup + config patch runner
  openclaw-wrapper.sh   # Injects env vars (GH_TOKEN, PGVECTOR_URL) then exec's node
  aws-sm-resolver       # Exec provider for SecretRef — reads from Secrets Manager
  update-base-image.sh  # Rebuilds openclaw:latest in ECR from upstream source
  ecs-exec              # Convenience wrapper for aws ecs execute-command
  tail-logs             # Tail CloudWatch logs for the ECS service
skills/                 # Custom skills/prompts
.github/workflows/
  deploy.yml            # Main CI/CD pipeline
```
