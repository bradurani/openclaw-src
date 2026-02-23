# Agent Rules — openclaw-src

## Git Workflow

- **Never push directly to `main`.**
- **Never merge pull requests.** Create PRs and leave them for the human to review and merge.
- Always work on feature branches.
- Do not use `--admin` bypass on `gh pr merge`.
- Do not reset code that has not been commited yet
- Do not git stash changes that have not been commited yet
- Do not automatically approve device pairing requests

## Docker / Compose

- Use `docker compose` (not `docker-compose`) for all commands.
- Environment variables in compose files that should be passed through to containers (not interpolated by compose) must use `$$` escaping.

## Secrets

- Never log, print, or echo secrets, tokens, or passwords.
- Secrets are injected via AWS Secrets Manager at container launch — do not hardcode them.
