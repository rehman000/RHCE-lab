#!/bin/bash
# ================================================================
# gen_keys.sh — Generate SSH keypair for the lab
# Run ONCE before the first `vagrant up`
# ================================================================
set -e

KEYS_DIR="$(dirname "$0")/keys"
mkdir -p "$KEYS_DIR"

if [ -f "$KEYS_DIR/ansible_key" ]; then
  echo "Keys already exist at $KEYS_DIR/ — skipping generation."
  echo "Delete keys/ and re-run to regenerate."
  exit 0
fi

ssh-keygen -t ed25519 -N "" -C "rhce-lab-ansible" -f "$KEYS_DIR/ansible_key"

echo ""
echo "Keys generated:"
echo "  Private: $KEYS_DIR/ansible_key"
echo "  Public:  $KEYS_DIR/ansible_key.pub"
echo ""
echo "Now run: vagrant up  OR  bash lab_setup.sh"
