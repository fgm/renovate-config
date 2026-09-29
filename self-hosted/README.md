# Self-hosted Renovate runner

- Monthly [Renovate](https://docs.renovatebot.com/) runner for the active `fgm`/OSInet FOSS repositories,
  extending the shared preset in this repo's [`../default.json`](../default.json).
- **Not currently running.** Intended for the **cof** host; built and exercised by hand on
  2026-07-02, never put on cron. Verified 2026-08-30: `/var/www/renovate/` holds only the two
  cache directories, the `config/` checkout below is absent, and there is no cron entry, no
  `/etc/cron.d` file and no timer. Treat every "is deployed" statement below as "is provisioned
  by these recipes".
- This directory is the source of truth: **cof runs a git checkout of it — do not hand-edit the copy on
  the server.** Change it here, then `just deploy` (a `git pull`); `check-deploy` flags a dirty checkout.

## Operating it: `just` recipes

- Operations are [`just`](https://just.systems) recipes wrapping small, individually testable scripts in
  [`scripts/`](scripts/). Run them from this directory **on cof**:
  - `just` — list every recipe.
  - `just doctor` — read-only health check (host + deploy + cron).
- Every `check-*` script exits non-zero on any failure, so it doubles as a test of host state.

| Recipe | Does | Idempotent | Verifies after |
|--------|------|:---:|----------------|
| `host-setup` | one-time: swap + cache/log dirs | yes | `check-host` |
| `deploy` | `git pull` the latest scripts + preset | yes | `check-deploy` |
| `dry-run` | full run that creates **no** PRs/MRs | — | — |
| `run` | live run — opens update/onboarding PRs & MRs | — | — |
| `install-cron` | add the monthly cron — **the go-live switch** | yes | `check-cron` |
| `uninstall-cron` | remove the monthly cron | yes | `check-cron` |
| `doctor` | run all read-only checks | (read-only) | — |
| `check-host` / `check-deploy` / `check-cron` | the individual checks | (read-only) | — |
| `check-tokens` | confirm the tokens authenticate (network) | (read-only) | — |

## Scope

- **GitHub** (`github.com/fgm`): the active set, minus mirrors. Excluded:
  - `renovate-config` (this preset repo, no deps),
  - `g2` + `drupal_adminrss` (mirrors of drupal.org contrib — canonical on `git.drupalcode.org`).
  - Exact list is in `renovate-run.sh`.
- **GitLab** (`gitlab.com/fgmarand`): `gopal`, `gocoverstats`.
- **Gogs** (`code.osinet.fr`): **out of scope.**
  - Renovate has no Gogs platform, and the current Gogs 0.15-dev backend lacks `/api/v1/version` and `/api/v1/repos/*/pulls`.
  - This is unblocked by the Gogs→Forgejo migration (Jira **WOF-47**); Forgejo is Gitea-API compatible.
  - Afterward, add a third pass (`RENOVATE_PLATFORM=gitea`, `RENOVATE_ENDPOINT=https://code.osinet.fr`) to `renovate-run.sh`.
- Onboarding is automatic: any in-scope repo without a `renovate.json` gets a PR/MR adopting
  `github>fgm/renovate-config` on the first run (via `RENOVATE_ONBOARDING_CONFIG` in the script).
- 🔴 **The GitHub list in `renovate-run.sh` is stale and would collide.** It names `fgm/envrun` and
  `fgm/izidic` among 19 repos, but the hosted Mend app has been installed since 2026-04-11 (onboarding
  PRs open on eight repos), and envrun, container and pflagheaders each run Dependabot with
  a tuned `dependabot.yml`. Armed as written, envrun would be updated by three mechanisms at once.
  Trim the list before any go-live — and note the three actively maintained repos (envrun, container,
  izidic) are all GitHub-hosted, where this runner is redundant.

## Policy

- From `../default.json`: `config:recommended` + `helpers:pinGitHubActionDigests` + `schedule:monthly`,
- **no automerge** (every update opens a PR you review).
- `schedule:monthly` gates *when* PRs may open; the cron just triggers a run. Monthly cadence is
  deliberate — the binding cost is PR review time, not compute.

## What is deployed on cof

- Everything lives under **`/var/www/renovate/`** (the xfs data volume; `/` is small and near-full).

| Path                                              | Perms           | Notes                                          |
|---------------------------------------------------|-----------------|------------------------------------------------|
| `/var/www/renovate/config/`                       | ubuntu:www-data | git checkout of this repo                      |
| `…/config/self-hosted/renovate.env`               | 600             | secrets, from `renovate.env.example`; **never in git** |
| `…/config/self-hosted/log/`                       | dir             | per-run logs (gitignored)                      |
| `/var/www/renovate/cache/{base,npm}`              | ubuntu:www-data | Renovate clones + npm cache, kept off `/`      |
| `/var/www/swapfile`                               | 600             | 2 GB swap (system-level)                       |

- **Host:** cof (the code.osinet.fr server), Ubuntu 22.04 x86_64, ~3.8 GB RAM as of 2026-07-01.
- **User:** `ubuntu`.
- **Runtime:**
  - `npx renovate` using the host's system Node (v22).
  - No Docker image (keeps the ~1.5 GB image off cof's tight disk).
  - Renovate is pinned to **42** in `renovate.env` because cof's Node 22 can't run renovate 43+ (needs Node 24); see `renovate.env.example`.

## Why the host constraints exist

- As of 2026-07-01, cof has two volumes:
  - **`/`** (20 GB, small and near-full),
  - **`/var/www`** (xfs, 30 GB — the data volume holding Docker's root dir and the Gogs repos).
- **Node / version pin — the reason for it is gone.** System Node is v22 (NodeSource `node_22.x`,
  not the distro), and renovate 43+ needs Node 24, so `RENOVATE_VERSION=42` is pinned and
  `check-host` asserts the Node major.
  The pin was justified by `gogs-vite.service` — `pnpm dev` on :5173, as root, installed 2026-06-26
  when Gogs broke on an update and triggered the WOF-47 migration. **That service was disabled at the
  2026-07-19 cutover and nothing has replaced it**: verified 2026-08-30, no Node process runs on cof and
  no installed `node_modules` remains. The one intermittent consumer is the WOF theme rebuild under
  `/var/www/osinet.fr/www11`, whose Storybook toolchain will raise its own Node floor when it is next
  updated, not lower it.
  So nothing on cof pins Node down, and moving to `node_24.x` is an apt source change rather than a
  distro upgrade. Drop `RENOVATE_VERSION` and the `check-host` assertion when that happens.
- **Swap.** npm-heavy repos spike ~1 GB RSS, and cof's ~1 GB free (of 3.8 GB; Gogs+Postgres use the rest)
  wasn't enough → the run was OOM-killed.
  - Fix: a **2 GB swapfile on `/var/www`** (`dd`, not `fallocate`, since xfs rejects holey files), in `/etc/fstab`.
  - `host-setup` creates it; `check-host` asserts it is active and persisted.
- **Disk.** Clones + npm cache go under `/var/www/renovate/cache/` via `RENOVATE_BASE_DIR` and
  `npm_config_cache` (see `renovate.env.example`) so a run can't fill `/`. `check-host` asserts free space.
- **Token scopes.** GitHub PAT needs **`repo` + `workflow`** — `workflow` because the preset pins GitHub
  Action digests, so Renovate edits `.github/workflows/*.yml` and GitHub rejects those pushes otherwise.
  GitLab PAT needs `api`. Tokens are sourced from the operator's laptop `~/.netrc` (machines `github.com`,
  `gitlab.com`). `check-tokens` confirms they authenticate.

## One-time bootstrap

- Requires `just` on cof (already installed). From an ssh session on cof:

```sh
sudo mkdir -p /var/www/renovate && sudo chown ubuntu:www-data /var/www/renovate
git clone https://github.com/fgm/renovate-config.git /var/www/renovate/config
cd /var/www/renovate/config/self-hosted
cp renovate.env.example renovate.env && chmod 600 renovate.env   # then fill in the tokens
just host-setup      # swap + cache/log dirs
just doctor          # all green except cron (held until go-live)
```

## Go live

```sh
just dry-run         # optional: confirm 22/22 clean, no OOM
just install-cron    # 07:00 Europe/Paris on the 1st of each month
# ...or trigger a one-off run right now:
just run
```

- The first live run opens ~22 onboarding PRs/MRs (one per in-scope repo without a `renovate.json`).
