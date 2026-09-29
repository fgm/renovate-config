#!/usr/bin/env bash
# Read-only: is cof provisioned to run Renovate? (swap, cache, disk, node)
source "$(dirname "$0")/lib.sh"

echo "host:"

assert "swap active at $SWAPFILE" \
  bash -c 'swapon --show=NAME --noheadings | grep -qx "$0"' "$SWAPFILE"
assert "swap persisted in /etc/fstab" grep -q "$SWAPFILE" /etc/fstab

assert "cache dir $CACHE_BASE exists" test -d "$CACHE_BASE"
assert "npm cache $NPM_CACHE exists" test -d "$NPM_CACHE"
if owner=$(stat -c '%U:%G' "$CACHE_BASE" 2>/dev/null); then
  [ "$owner" = "$OWNER" ] && ok "cache owned by $OWNER" || no "cache owned by $owner, want $OWNER"
else
  no "cannot stat $CACHE_BASE"
fi

# Node: renovate 42 needs ^22.13 || ^24.11; cof is pinned to 22 on purpose.
if node_v=$(node --version 2>/dev/null); then
  case "$node_v" in
    v22.*|v24.*) ok "node $node_v (compatible with the renovate pin)" ;;
    *)           no "node $node_v — renovate 42 needs 22.x or 24.x" ;;
  esac
else
  no "node not found on PATH"
fi

if free_mb=$(df -Pm "$CACHE_BASE" 2>/dev/null | awk 'NR==2 {print $4}'); then
  [ "${free_mb:-0}" -ge "$FREE_MB_MIN" ] \
    && ok "/var/www free: ${free_mb} MB (>= ${FREE_MB_MIN})" \
    || no "/var/www free: ${free_mb} MB (< ${FREE_MB_MIN})"
else
  no "cannot read free space on /var/www"
fi

report
