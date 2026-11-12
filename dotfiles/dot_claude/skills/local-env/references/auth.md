# Local authorization server

One Authelia with Redis serves the whole Mac at `https://auth.localhost`. Every local service signs its users in there and validates its tokens against it. A local service never talks to a production authorization server, and nothing issued here is valid anywhere else: the server has its own signing key, and every client has its own key that exists only on this Mac.

It runs the image production runs, as the compose project `authelia` in `~/.local/share/authelia`. Docker restarts it, foster does not run it, and its route is the `auth.localhost` line in `static.map`. Nothing in that directory is in a repository.

| Path in `~/.local/share/authelia` | What it is |
|---|---|
| `compose.yml` | Authelia and Redis, port `50900` on loopback |
| `config/configuration.yml` | the whole configuration, the client list included |
| `config/users_database.yml` | the one user, `dev` |
| `config/clients/<client>.pub` | public key of each client |
| `config/secrets/` | the server's own secrets and signing key |
| `keys/<client>.pem` | private key of each client, read by the local service |
| `password` | the password of `dev` |
| `token` | prints an access token for a machine caller |

What a service needs to know about the server:

| | |
|---|---|
| issuer | `https://auth.localhost` |
| keys (JWKS) | `https://auth.localhost/jwks.json` |
| token endpoint | `https://auth.localhost/api/oidc/token` |
| metadata | `https://auth.localhost/.well-known/openid-configuration` |

## Signing in

The user is `dev`. Never print or read the password. For a browser, put it on the clipboard: `pbcopy < ~/.local/share/authelia/password`. A sign in survives a restart of Authelia, because the sessions are in Redis.

## Changing the configuration

Authelia has no admin API and no client registration endpoint. A change is an edit of `config/configuration.yml`, then, from `~/.local/share/authelia`:

```sh
docker compose exec -T authelia authelia config validate
docker compose restart authelia
```

Restart only after the validation exits 0. Authelia does not start on a configuration it rejects, and then no local service can sign anyone in. If it is already down, validate with `docker compose run --rm --no-deps authelia authelia config validate`. A restart takes about two seconds.

Two warnings are expected and are not errors: no `access_control` rules, and a scope outside the standard OpenID ones.

## A token for a machine caller

The client `agent` stands in for every machine caller a server has in production. It uses the `client_credentials` grant and proves itself with its key, never with a secret.

```sh
~/.local/share/authelia/token https://yotei.localhost/mcp yotei:read yotei:write
```

The first argument is the resource: the audience the server checks, not the address you call. The rest are scopes. The script prints the access token alone, so use it in place: `curl -H "Authorization: Bearer $(~/.local/share/authelia/token <resource> <scope>)" ...`. A refusal prints the OAuth error code: `invalid_target` means the resource is not in the `audience` list of `agent`, `invalid_scope` means the scope is not in its `scopes` list. To let `agent` call a new server, add that server's audience and scopes to those two lists.

## A client for a service

A service that signs users in, or that asks for tokens itself, gets its own client. Two services never share a client or a key.

1. Make the key pair. The private key stays in `keys/`, and only the service reads it.

   ```sh
   cd ~/.local/share/authelia
   openssl genrsa -out keys/yotei.pem 2048 && chmod 600 keys/yotei.pem
   openssl rsa -in keys/yotei.pem -pubout -out config/clients/yotei.pub
   ```

2. Add the client to `clients` in `config/configuration.yml`. Copy the `yotei` block for a service that signs users in, or the `agent` block for one that only asks for tokens, and keep every setting the production client has. The client id is the service name, the key id is `<client>-local`, and the redirect URI is the full address the service returns to.
3. Validate and restart.
4. Point the service at the server in its own `.env`. For yotei:

   ```sh
   MCP_AUTH_ISSUER=https://auth.localhost
   MCP_AUTH_JWKS_URL=https://auth.localhost/jwks.json
   MCP_AUTH_AUDIENCE=https://yotei.localhost/mcp
   OAUTH_CLIENT_ID=yotei
   OAUTH_KEY_FILE=/Users/<user>/.local/share/authelia/keys/yotei.pem
   OAUTH_KEY_ID=yotei-local
   ```

The audience is a name, not an address. It stays the same in every worktree of the service, so one entry in the client's `audience` list is enough.

## A worktree

Authelia matches a redirect URI exactly, with no patterns. A service in a linked worktree runs on `https://<worktree folder>.<domain>.localhost`, so its redirect URI is not registered. When the worktree needs a real sign in, add its URI as one more line under `redirect_uris` of the client, validate and restart. Remove the line when you remove the worktree. A worktree that only needs tokens for its API needs no change: `agent` works as it is.

## Facts that cost time once

- A session cookie domain cannot be bare `localhost`. `auth.localhost` works.
- Client lists from several configuration files are not merged, the last file wins. Keep one file.
- A token asked for without a resource has no `aud`, and a server that checks the audience refuses it.
- Authelia does not tie a scope to an audience. A server must check both.
- The requests follow the standards: the target of a token is named with `resource` (RFC 8707), and a client assertion is addressed to the issuer alone, `https://auth.localhost`, not to the token endpoint.
- Go and curl trust the certificate of `auth.localhost` through the macOS keychain, where Caddy's local CA is installed. A service needs no certificate setting.
