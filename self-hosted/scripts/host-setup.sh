#!/usr/bin/env bash
# One-time host provisioning on cof: swap + cache/log dirs. Safe to re-run.
# Needs passwordless sudo (the cloud-image default for user ubuntu).
source "$(dirname "$0")/lib.sh"

echo "== swap =="
if swapon --show=NAME --noheadings | grep -qx "$SWAPFILE"; then
  echo "  swap already active at $SWAPFILE"
else
  # xfs rejects holey files, so dd (not fallocate) the swapfile.
  sudo dd if=/dev/zero of="$SWAPFILE" bs=1M count="$SWAP_MB"
  sudo chmod 600 "$SWAPFILE"
  sudo mkswap "$SWAPFILE"
  sudo swapon "$SWAPFILE"
fi
if grep -q "$SWAPFILE" /etc/fstab; then
  echo "  fstab entry present"
else
  echo "$SWAPFILE none swap sw 0 0" | sudo tee -a /etc/fstab >/dev/null
fi

echo "== cache + log dirs =="
sudo mkdir -p "$CACHE_BASE" "$NPM_CACHE" "$LOG_DIR"
sudo chown -R "$OWNER" "$CACHE_BASE" "$NPM_CACHE"

echo
exec "$(dirname "$0")/check-host.sh"
