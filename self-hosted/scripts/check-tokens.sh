#!/usr/bin/env bash
# Read-only, network: do the stored tokens actually authenticate?
# Not part of `doctor` (it hits the network); run it on demand: just check-tokens
source "$(dirname "$0")/lib.sh"

echo "tokens:"

[ -f "$ENV_FILE" ] || { no "renovate.env missing"; report; }
# Read values in a subshell so they never touch this script's environment or output.
gh=$(set -a; . "$ENV_FILE"; printf '%s' "${GITHUB_TOKEN:-}")
gl=$(set -a; . "$ENV_FILE"; printf '%s' "${GITLAB_TOKEN:-}")

if [ -n "$gh" ] && login=$(curl -fsS -H "Authorization: token $gh" https://api.github.com/user \
    | grep -o '"login"[^,]*' | head -1); then
  ok "GitHub token authenticates (${login:-user ok})"
else
  no "GitHub token failed to authenticate"
fi

if [ -n "$gl" ] && curl -fsS -H "PRIVATE-TOKEN: $gl" https://gitlab.com/api/v4/user >/dev/null; then
  ok "GitLab token authenticates"
else
  no "GitLab token failed to authenticate"
fi

report
