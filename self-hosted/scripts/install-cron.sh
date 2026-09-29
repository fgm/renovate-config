#!/usr/bin/env bash
# Install the monthly cron for user ubuntu. Idempotent: adds nothing if already present.
source "$(dirname "$0")/lib.sh"

mkdir -p "$LOG_DIR"
if crontab -l 2>/dev/null | grep -Fq "$CRON_MATCH"; then
  echo "cron already installed — nothing to do"
else
  { crontab -l 2>/dev/null || true; echo "$CRON_LINE"; } | crontab -
  echo "cron installed"
fi

echo
exec "$(dirname "$0")/check-cron.sh"
