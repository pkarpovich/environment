#!/usr/bin/env python3
import json
import ssl
import sys
import urllib.request
import urllib.error

CONTINUUM_API = "https://continuum-api.localhost/api"
DEFAULT_USER_ID = "181084522"

ssl_context = ssl.create_default_context()
ssl_context.check_hostname = False
ssl_context.verify_mode = ssl.CERT_NONE

def fetch_data_connections(user_id: str = DEFAULT_USER_ID) -> dict:
    url = f"{CONTINUUM_API}/settings?user_id={user_id}"
    req = urllib.request.Request(url, headers={"Accept": "application/json"})

    with urllib.request.urlopen(req, context=ssl_context) as response:
        data = json.loads(response.read().decode())

    return data

def main():
    user_id = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_USER_ID

    result = fetch_data_connections(user_id)

    connections = result.get("data_connections", [])
    if not connections:
        print("No data connections found.")
        return

    print(f"Found {len(connections)} data connection(s):\n")
    for conn in connections:
        print(f"  ID: {conn.get('id')}")
        print(f"  Name: {conn.get('name')}")
        print(f"  Type: {conn.get('type')}")
        if conn.get('config', {}).get('url'):
            print(f"  URL: {conn['config']['url']}")
        print()

if __name__ == "__main__":
    main()
