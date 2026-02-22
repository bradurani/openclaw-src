# openclaw-src

Configuration, agents, hooks, skills, and workspace files that customize our OpenClaw instance. These files are included in the Docker container built by `openclaw-tf`.

## Workflow Rules

1. **Never push directly to `main`.** This repo has a branch protection ruleset that requires pull requests. Always create a feature branch, open a PR, and ask Brad for review before merging. No exceptions — even for "quick fixes." If a deploy is broken, the fix still goes through a PR.
2. **All changes deploy automatically.** Merging to `main` triggers a CI build and ECS deployment. Treat every merge as a production deploy.
3. **Local dev is read-only.** Use `docker-compose` and `script/fetch-env` for local testing. Infrastructure changes belong in `openclaw-tf`.
