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

def fetch_settings(user_id: str) -> dict:
    url = f"{CONTINUUM_API}/settings?user_id={user_id}"
    req = urllib.request.Request(url, headers={"Accept": "application/json"})

    with urllib.request.urlopen(req, context=ssl_context) as response:
        return json.loads(response.read().decode())

def fetch_tools(user_id: str, data_connections: list) -> dict:
    url = f"{CONTINUUM_API}/tools/"
    payload = json.dumps({
        "user_id": int(user_id),
        "data_connections": data_connections
    }).encode()

    req = urllib.request.Request(
        url,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json"
        },
        method="POST"
    )

    with urllib.request.urlopen(req, context=ssl_context) as response:
        return json.loads(response.read().decode())

def main():
    user_id = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_USER_ID
    connection_filter = sys.argv[2] if len(sys.argv) > 2 else None

    settings = fetch_settings(user_id)
    connections = settings.get("data_connections", [])

    if not connections:
        print("No data connections found.")
        return

    conn_id_map = {c["name"]: c["id"] for c in connections}

    if connection_filter:
        connections = [c for c in connections if connection_filter.lower() in c.get("name", "").lower() or c.get("id") == connection_filter]
        if not connections:
            print(f"No connections matching '{connection_filter}'")
            return

    result = fetch_tools(user_id, connections)
    tools_list = result.get("tools", [])

    if not tools_list:
        print("No tools found.")
        return

    tools_by_server = {}
    for tool in tools_list:
        server = tool.get("server", "Unknown")
        if server not in tools_by_server:
            tools_by_server[server] = []
        tools_by_server[server].append(tool)

    for server_name, tools in sorted(tools_by_server.items()):
        conn_id = conn_id_map.get(server_name, "unknown")
        print(f"\n=== {server_name} ===")
        print(f"Connection ID: {conn_id}")
        print(f"Total tools: {len(tools)}\n")

        for tool in tools:
            print(f"  - {tool.get('name')}")
            if tool.get('description'):
                desc = tool['description'][:80] + "..." if len(tool.get('description', '')) > 80 else tool.get('description', '')
                print(f"    {desc}")

if __name__ == "__main__":
    main()
