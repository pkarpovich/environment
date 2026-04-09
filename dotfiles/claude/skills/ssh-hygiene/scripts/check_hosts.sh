#!/bin/bash
ssh_config="${1:-$HOME/.ssh/config}"

echo "Checking SSH hosts from $ssh_config..."
echo ""

grep -E "^\s*HostName\s+" "$ssh_config" | while read -r line; do
    ip=$(echo "$line" | awk '{print $2}')
    host_alias=$(grep -B5 "$ip" "$ssh_config" | grep -E "^Host\s+" | tail -1 | awk '{print $2}')
    nc -z -w 3 "$ip" 22 2>/dev/null && echo "alive   $host_alias ($ip)" || echo "DEAD    $host_alias ($ip)"
done
