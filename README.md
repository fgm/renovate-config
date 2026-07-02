# renovate-config

Shared [Renovate](https://docs.renovatebot.com/) configuration for my FOSS repositories.

## Usage

Add a `renovate.json` to a repository that extends this preset:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["github>fgm/renovate-config"]
}
```

`github>fgm/renovate-config` resolves to `github.com/fgm/renovate-config` and loads the
root `default.json`. Because the preset is addressed with the explicit `github>` prefix,
it can be extended from repositories hosted on other forges (GitLab, Gitea) as well.

## What `default.json` does

- `config:recommended` — Renovate's recommended baseline (dependency dashboard,
  grouping, sane PR limits).
- `helpers:pinGitHubActionDigests` — pins GitHub Actions to commit SHAs and keeps them
  updated, for supply-chain integrity.
- `schedule:monthly` — batches update PRs to a monthly window to limit churn.

No automerge: every update opens a PR for review.

## Self-hosted runner

Repos on forges without a hosted Renovate app (GitLab, and later Forgejo) are driven by a
self-hosted monthly runner documented in [`self-hosted/`](self-hosted/) — deployed on the
`cof` host, which is provisioned *from* that directory.
