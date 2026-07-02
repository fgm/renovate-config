#!/usr/bin/env bash
# Monthly self-hosted Renovate for active fgm FOSS repos (GitHub + GitLab).
#
# Gogs (code.osinet.fr) is intentionally OUT of scope: its custom backend lacks
# /api/v1/version and /api/v1/repos/*/pulls, which Renovate's gitea platform needs.
# Central policy comes from github>fgm/renovate-config (recommended + pinned GH Action
# digests + monthly schedule, no automerge).
#
# Secrets are read from ./renovate.env (chmod 600) and never logged.
# Dry run:  RENOVATE_DRY_RUN=full ./renovate-run.sh
set -euo pipefail
cd "$(dirname "$0")"
set -a; . ./renovate.env; set +a

export LOG_LEVEL="${LOG_LEVEL:-info}"
# Repos without a renovate.json get an onboarding PR adopting the shared preset.
export RENOVATE_ONBOARDING_CONFIG='{"$schema":"https://docs.renovatebot.com/renovate-schema.json","extends":["github>fgm/renovate-config"]}'
# A github.com token so non-GitHub passes can still resolve the github>fgm/renovate-config
# preset and fetch GitHub-hosted release notes.
export GITHUB_COM_TOKEN="$GITHUB_TOKEN"

# Pin RENOVATE_VERSION in renovate.env after the first successful dry run for reproducibility.
RENOVATE=(npx --yes "renovate@${RENOVATE_VERSION:-latest}")

echo "=== GitHub pass $(date -u +%FT%TZ) ==="
RENOVATE_PLATFORM=github RENOVATE_TOKEN="$GITHUB_TOKEN" "${RENOVATE[@]}" \
  fgm/izidic fgm/envrun fgm/untilMongod fgm/container fgm/drupal_redis_stats \
  fgm/bo_htmx fgm/pflagheaders fgm/go__web_demo fgm/filog fgm/accounts-drupal \
  fgm/twinui fgm/frankenphp-drupal fgm/accordion fgm/subcommands_demo fgm/drupal-sso \
  fgm/accounts-fake fgm/xmlrpc fgm/tooling fgm/crm fgm/oui

echo "=== GitLab pass $(date -u +%FT%TZ) ==="
RENOVATE_PLATFORM=gitlab RENOVATE_TOKEN="$GITLAB_TOKEN" "${RENOVATE[@]}" \
  fgmarand/gopal fgmarand/gocoverstats

echo "=== done $(date -u +%FT%TZ) ==="
