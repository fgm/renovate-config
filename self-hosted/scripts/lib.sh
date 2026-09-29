#!/usr/bin/env bash
# Shared constants + tiny assertion helpers for the cof Renovate recipes.
# Sourced by every other script; not meant to run on its own.
set -euo pipefail

# Where things live on cof, all nested under /var/www/renovate/.
# Override the checkout dir for testing with RENOVATE_CHECKOUT.
#   /var/www/renovate/config   git checkout of this repo
#   /var/www/renovate/cache    npx + renovate clones (off the small root fs)
CHECKOUT="${RENOVATE_CHECKOUT:-/var/www/renovate/config}"
SELF="$CHECKOUT/self-hosted"
ENV_FILE="$SELF/renovate.env"
LOG_DIR="$SELF/log"
CACHE_BASE="/var/www/renovate/cache/base"
NPM_CACHE="/var/www/renovate/cache/npm"
SWAPFILE="/var/www/swapfile"   # system-level, kept at the /var/www root
SWAP_MB=2048           # 2 GB — covers the ~1 GB RSS spike on npm-heavy repos with headroom.
OWNER="ubuntu:www-data"
FREE_MB_MIN=2000       # refuse-to-be-happy floor for /var/www; a run needs room for clones + npm cache.

# The monthly cron. CRON_MATCH is the stable substring used to detect/remove it;
# CRON_LINE is the full entry. The redirection is single-quoted so $(date …) and the
# cron-required \% escapes stay literal in the crontab.
CRON_MATCH="cd $SELF && ./renovate-run.sh"
CRON_LINE="0 7 1 * * $CRON_MATCH"' >> log/cron.$(date +\%Y\%m).log 2>&1'

# --- assertion helpers -------------------------------------------------------
# Each script prints ✓/✗ lines and ends with `report`, which exits non-zero if
# anything failed — so a script doubles as an executable test of host state.
FAILS=0
ok() { printf '  \033[32m✓\033[0m %s\n' "$*"; }
no() { printf '  \033[31m✗\033[0m %s\n' "$*"; FAILS=$((FAILS + 1)); }

# assert "description" cmd args...   — ✓ if the command succeeds, ✗ otherwise.
assert() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$desc"; else no "$desc"; fi
}

report() {
  if [ "$FAILS" -gt 0 ]; then
    printf '\n%s: %d check(s) failed\n' "${0##*/}" "$FAILS"
    exit 1
  fi
  printf '\n%s: ok\n' "${0##*/}"
}
