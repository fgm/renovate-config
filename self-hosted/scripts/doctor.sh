#!/usr/bin/env bash
# Full read-only health check: host + deploy + cron. Exits non-zero if any fail.
# Token authentication is checked separately (network): just check-tokens
here="$(dirname "$0")"
rc=0
for c in check-host check-deploy check-cron; do
  "$here/$c.sh" || rc=1
  echo
done
[ "$rc" -eq 0 ] && echo "doctor: all groups ok" || echo "doctor: problems found (see ✗ above)"
exit "$rc"
