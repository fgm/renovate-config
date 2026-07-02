# Self-hosted Renovate runner

Monthly [Renovate](https://docs.renovatebot.com/) runner for the active `fgm`/OSInet FOSS
repositories, extending the shared preset in this repo's [`../default.json`](../default.json).
Deployed on the **cof** host. This directory is the source of truth: **cof is deployed *from*
here — do not hand-edit the copy on the server.**

## Scope

- **GitHub** (`github.com/fgm`): the active set, minus mirrors. Excluded: `renovate-config`
  (this preset repo, no deps), `g2` + `drupal_adminrss` (mirrors of drupal.org contrib —
  canonical on `git.drupalcode.org`). Exact list is in `renovate-run.sh`.
- **GitLab** (`gitlab.com/fgmarand`): `gopal`, `gocoverstats`.
- **Gogs** (`code.osinet.fr`): **out of scope.** Renovate has no Gogs platform, and the current
  Gogs 0.15-dev backend lacks `/api/v1/version` and `/api/v1/repos/*/pulls`. This is unblocked
  by the Gogs→Forgejo migration (Jira **WOF-47**); Forgejo is Gitea-API compatible. Afterward,
  add a third pass (`RENOVATE_PLATFORM=gitea`, `RENOVATE_ENDPOINT=https://code.osinet.fr`) to
  `renovate-run.sh`.

## Policy

From `../default.json`: `config:recommended` + `helpers:pinGitHubActionDigests` +
`schedule:monthly`, **no automerge** (every update opens a PR you review). Repos without a
`renovate.json` get an onboarding PR that adopts `github>fgm/renovate-config`.

## What is deployed on cof

| Path | Perms | Notes |
|------|-------|-------|
| `/home/ubuntu/renovate/renovate-run.sh` | 755 | copy of `renovate-run.sh` here |
| `/home/ubuntu/renovate/renovate.env`    | 600 | secrets, from `renovate.env.example`; **never in git** |
| `/home/ubuntu/renovate/log/`            | dir | per-run logs |

- **Host:** cof (the code.osinet.fr server), Ubuntu 22.04 x86_64, ~3.8 GB RAM.
- **User:** `ubuntu`.
- **Runtime:** `npx renovate` using the host's system Node (v22). No Docker image (keeps the
  ~1.5 GB image off cof's tight disk). Renovate is pinned to **42** in `renovate.env` because
  cof's Node 22 can't run renovate 43+ (needs Node 24); see `renovate.env.example`.

## Host resources (memory & disk)

cof has two volumes: **`/`** (20 GB, small and near-full — holds `/home/ubuntu`) and
**`/var/www`** (xfs, 30 GB — the data volume holding Docker's root dir and the Gogs repos).
So Renovate keeps everything off `/`:

- **npm-heavy repos spike ~1 GB RSS**, and cof's ~1 GB free (of 3.8 GB; Gogs+Postgres use the
  rest) wasn't enough → the run was OOM-killed. Fix: a **2 GB swapfile on `/var/www`**
  (`/var/www/swapfile`, in `/etc/fstab`; created with `dd`, not `fallocate`, since xfs swapfiles
  reject holey files). Renovate is also pinned to 42 for the Node 22 constraint (above).
- **Clones + npm cache go on `/var/www`** via `RENOVATE_BASE_DIR` and `npm_config_cache`
  (see `renovate.env.example`) so a run can't fill `/`.

One-time host setup (reproducible):

```sh
# swap (xfs -> dd, not fallocate)
sudo dd if=/dev/zero of=/var/www/swapfile bs=1M count=2048
sudo chmod 600 /var/www/swapfile && sudo mkswap /var/www/swapfile && sudo swapon /var/www/swapfile
echo '/var/www/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
# cache dirs
sudo mkdir -p /var/www/renovate/base /var/www/renovate/npmcache
sudo chown -R ubuntu:www-data /var/www/renovate
```

## Deploy / redeploy

```sh
# from a checkout of this repo
scp self-hosted/renovate-run.sh cof:renovate/renovate-run.sh
ssh cof 'chmod 755 ~/renovate/renovate-run.sh'
# renovate.env is created once from renovate.env.example (tokens sourced from the operator's
# ~/.netrc: machine github.com and machine gitlab.com), then chmod 600. Never scp it into git.
```

## Run

```sh
# dry run (creates nothing) — always do this after changing scope or the pin
ssh cof 'cd ~/renovate && RENOVATE_DRY_RUN=full LOG_LEVEL=info ./renovate-run.sh'

# live
ssh cof 'cd ~/renovate && ./renovate-run.sh'
```

## Schedule (monthly cron, user `ubuntu`)

`schedule:monthly` in the preset gates *when PRs are created*; the cron just triggers a run.
Monthly cadence is deliberate — the binding cost is PR review time, not compute.

```cron
# 07:00 Europe/Paris on the 1st of each month
0 7 1 * * cd $HOME/renovate && ./renovate-run.sh >> log/cron.$(date +\%Y\%m).log 2>&1
```
