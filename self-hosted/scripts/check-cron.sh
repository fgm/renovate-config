#!/usr/bin/env bash
# Read-only: is the monthly cron installed exactly once?
# Absence is not a failure — go-live is deliberately held until the cron is added.
source "$(dirname "$0")/lib.sh"

echo "cron:"

n=$(crontab -l 2>/dev/null | grep -Fc "$CRON_MATCH" || true)
case "$n" in
  0) ok "no cron installed (held; run 'just install-cron' to go live)" ;;
  1) ok "monthly cron installed" ;;
  *) no "cron installed $n times — duplicates; run 'just uninstall-cron' then reinstall" ;;
esac

report
