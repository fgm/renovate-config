#!/usr/bin/env bash
# Remove the monthly cron for user ubuntu. Idempotent.
source "$(dirname "$0")/lib.sh"

if crontab -l 2>/dev/null | grep -Fq "$CRON_MATCH"; then
  crontab -l 2>/dev/null | grep -Fv "$CRON_MATCH" | crontab -
  echo "cron removed"
else
  echo "no cron to remove"
fi

echo
exec "$(dirname "$0")/check-cron.sh"
