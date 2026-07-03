#!/bin/bash
# Export every "SSH Key" item from 1Password to ~/.ssh/keys/ as on-disk OpenSSH
# key files, so SSH/git work without the 1Password agent (remote/headless safe).
#
# Run this in YOUR OWN terminal - `op` needs the 1Password desktop prompt and
# fails with promptError in a non-interactive shell. Run it on each laptop; both
# pull the same vault, so both end up with the same keys.
#
# Each item "My Key" -> ~/.ssh/keys/my-key (private, 600) + my-key.pub (644).
# The ?ssh-format=openssh is required - without it op emits PKCS#8 that ssh rejects.

set -euo pipefail

OP=/opt/homebrew/bin/op
JQ=/opt/homebrew/bin/jq
DEST="$HOME/.ssh/keys"

mkdir -p "$DEST"
chmod 700 "$HOME/.ssh" "$DEST"

items=$("$OP" item list --categories "SSH Key" --format=json) || {
  echo "Could not list SSH keys - unlock 1Password and enable the CLI integration." >&2
  exit 1
}

if [ "$(printf '%s' "$items" | "$JQ" 'length')" -eq 0 ]; then
  echo "No SSH Key items found in 1Password."
  exit 0
fi

printf '%s' "$items" | "$JQ" -r '.[] | "\(.id)\t\(.vault.id)\t\(.title)"' \
| while IFS=$'\t' read -r id vault title; do
  name=$(printf '%s' "$title" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9._-')
  [ -z "$name" ] && name="$id"
  priv="$DEST/$name"
  pub="$DEST/$name.pub"

  if [ -e "$priv" ]; then
    echo "skip  $name (file already exists - remove it to re-export)"
    continue
  fi

  if "$OP" read "op://$vault/$id/private key?ssh-format=openssh" > "$priv" 2>/dev/null; then
    chmod 600 "$priv"
  else
    echo "FAIL  $name (could not read private key)" >&2
    rm -f "$priv"
    continue
  fi

  if "$OP" read "op://$vault/$id/public key" > "$pub" 2>/dev/null; then
    chmod 644 "$pub"
  else
    rm -f "$pub"
  fi

  if ! head -1 "$priv" | grep -q "BEGIN OPENSSH PRIVATE KEY"; then
    echo "WARN  $name (not OpenSSH format - ssh may reject it)" >&2
  fi

  echo "ok    $name"
done

echo
echo "Exported to $DEST:"
ls -la "$DEST"
