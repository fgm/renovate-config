#!/usr/bin/env bash
# Read-only: is the checkout deployed and are secrets in place? (no token values printed)
source "$(dirname "$0")/lib.sh"

echo "deploy:"

if git -C "$CHECKOUT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  ok "git checkout at $CHECKOUT"
  [ -z "$(git -C "$CHECKOUT" status --porcelain)" ] \
    && ok "checkout clean (no local edits)" \
    || no "checkout has uncommitted changes — server copy was hand-edited"
else
  no "no git checkout at $CHECKOUT"
fi

assert "renovate-run.sh present + executable" test -x "$SELF/renovate-run.sh"
assert "log dir $LOG_DIR exists" test -d "$LOG_DIR"

if [ -f "$ENV_FILE" ]; then
  ok "renovate.env present"
  mode=$(stat -c '%a' "$ENV_FILE" 2>/dev/null || echo '?')
  [ "$mode" = 600 ] && ok "renovate.env mode 600" || no "renovate.env mode $mode, want 600"
  # Value present = at least one non-comment char after the '='. Never printed.
  for var in GITHUB_TOKEN GITLAB_TOKEN RENOVATE_VERSION; do
    if grep -Eq "^${var}=.+" "$ENV_FILE"; then ok "$var set"; else no "$var empty/missing in renovate.env"; fi
  done
else
  no "renovate.env missing — copy renovate.env.example, fill it, chmod 600"
fi

report
