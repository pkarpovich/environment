#!/usr/bin/env python3
"""Sign in once with the OAuth 2.0 device grant and print access tokens."""

import argparse
import contextlib
import dataclasses
import fcntl
import http.client
import json
import os
import re
import subprocess
import sys
import time
import tomllib
import urllib.error
import urllib.parse
import urllib.request
from collections.abc import Callable, Iterator
from pathlib import Path
from typing import Protocol, TextIO

EXIT_OK = 0
EXIT_ERROR = 1
EXIT_SIGN_IN_NEEDED = 3
EXIT_TEMPORARY = 4

REQUEST_TIMEOUT_SECONDS = 10
EXPIRY_MARGIN_SECONDS = 60
SLOW_DOWN_SECONDS = 5
DEFAULT_POLL_INTERVAL_SECONDS = 5
DEVICE_CODE_GRANT = "urn:ietf:params:oauth:grant-type:device_code"
KEYCHAIN_SERVICE = "oauth-token"
# security -i reads one command per line into a 4096-byte buffer. A longer
# line is cut: the first part runs as a command and stores a truncated value.
KEYCHAIN_MAX_LINE_BYTES = 4095
# security find-generic-password exits with errSecItemNotFound.
KEYCHAIN_NOT_FOUND_STATUS = 44
NAME_PATTERN = re.compile(r"[A-Za-z0-9_-]+")
ERROR_CODE_PATTERN = re.compile(r"[A-Za-z0-9_.-]{1,64}")


class Failure(Exception):
    status = EXIT_ERROR


class SignInNeeded(Failure):
    status = EXIT_SIGN_IN_NEEDED


class TemporaryFailure(Failure):
    status = EXIT_TEMPORARY


@dataclasses.dataclass(frozen=True)
class Response:
    status: int
    body: dict | None


@dataclasses.dataclass(frozen=True)
class Service:
    name: str
    resource: str
    scope: str


@dataclasses.dataclass(frozen=True)
class Config:
    issuer: str
    client_id: str
    services: dict[str, Service]


@dataclasses.dataclass(frozen=True)
class Endpoints:
    device_authorization: str
    token: str


@dataclasses.dataclass(frozen=True)
class Tokens:
    access_token: str
    expires_at: float
    refresh_token: str | None


class Store(Protocol):
    def read(self, account: str) -> dict | None: ...
    def write(self, account: str, entry: dict) -> None: ...
    def delete(self, account: str) -> None: ...


Http = Callable[[str, dict[str, str] | None], Response]


@dataclasses.dataclass
class Env:
    http: Http
    clock: Callable[[], float]
    sleep: Callable[[float], None]
    store: Store
    open_browser: Callable[[str], None]
    config_path: Path
    state_dir: Path
    stdout: TextIO
    stderr: TextIO


def is_https(url: object) -> bool:
    if not isinstance(url, str):
        return False
    parts = urllib.parse.urlsplit(url)
    return parts.scheme == "https" and bool(parts.netloc)


def non_empty_string(value: object) -> bool:
    return isinstance(value, str) and value != ""


def positive_number(value: object) -> bool:
    return isinstance(value, int | float) and not isinstance(value, bool) and value > 0


def load_config(path: Path) -> Config:
    try:
        with path.open("rb") as file:
            data = tomllib.load(file)
    except FileNotFoundError:
        raise Failure(f"no configuration: {path}") from None
    except tomllib.TOMLDecodeError as error:
        raise Failure(f"{path}: {error}") from None

    issuer = data.get("issuer")
    client_id = data.get("client_id")
    if not is_https(issuer):
        raise Failure(f"{path}: issuer must be an https address")
    if not non_empty_string(client_id):
        raise Failure(f"{path}: client_id is missing")

    services: dict[str, Service] = {}
    for name, table in data.get("services", {}).items():
        resource = table.get("resource") if isinstance(table, dict) else None
        scope = table.get("scope", "") if isinstance(table, dict) else None
        if not NAME_PATTERN.fullmatch(name):
            raise Failure(f"{path}: service name {name!r} may use letters, digits, _ and - only")
        if not non_empty_string(resource) or not isinstance(scope, str):
            raise Failure(f"{path}: services.{name} needs a resource and a scope")
        services[name] = Service(name, resource, scope)
    return Config(issuer, client_id, services)


def find_service(config: Config, name: str, config_path: Path) -> Service:
    service = config.services.get(name)
    if service is None:
        raise Failure(f"no service {name!r} in {config_path}")
    return service


def describe(response: Response) -> str:
    code = response.body.get("error") if response.body else None
    if isinstance(code, str) and ERROR_CODE_PATTERN.fullmatch(code):
        return f"HTTP {response.status} {code}"
    return f"HTTP {response.status}"


def error_code(response: Response) -> str | None:
    return response.body.get("error") if response.body else None


def raise_for(what: str, response: Response) -> None:
    message = f"{what} answered {describe(response)}"
    if response.status >= 500:
        raise TemporaryFailure(message)
    raise Failure(message)


def discover(env: Env, issuer: str) -> Endpoints:
    response = env.http(issuer.rstrip("/") + "/.well-known/openid-configuration", None)
    if response.status != 200 or response.body is None:
        raise_for("discovery", response)
    document = response.body
    if document.get("issuer") != issuer:
        raise Failure(f"discovery document names another issuer than {issuer}")
    device_authorization = document.get("device_authorization_endpoint")
    token = document.get("token_endpoint")
    if not is_https(device_authorization) or not is_https(token):
        raise Failure("discovery document has an endpoint that is not https")
    return Endpoints(device_authorization, token)


def parse_tokens(env: Env, body: dict | None) -> Tokens:
    body = body or {}
    access_token = body.get("access_token")
    expires_in = body.get("expires_in")
    refresh_token = body.get("refresh_token")
    if not non_empty_string(access_token):
        raise Failure("token answer has no access_token")
    if not positive_number(expires_in):
        raise Failure("token answer has no positive expires_in")
    return Tokens(access_token, env.clock() + expires_in, refresh_token if non_empty_string(refresh_token) else None)


@contextlib.contextmanager
def service_lock(state_dir: Path, service: str) -> Iterator[None]:
    state_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    descriptor = os.open(state_dir / f"{service}.lock", os.O_RDWR | os.O_CREAT, 0o600)
    try:
        fcntl.flock(descriptor, fcntl.LOCK_EX)
        yield
    finally:
        os.close(descriptor)


def make_entry(config: Config, service: Service, tokens: Tokens, refresh_token: str) -> dict:
    return {
        "issuer": config.issuer,
        "client_id": config.client_id,
        "resource": service.resource,
        "scope": service.scope,
        "access_token": tokens.access_token,
        "refresh_token": refresh_token,
        "expires_at": tokens.expires_at,
    }


def entry_matches(entry: dict, config: Config, service: Service) -> bool:
    return (
        entry.get("issuer") == config.issuer
        and entry.get("client_id") == config.client_id
        and entry.get("resource") == service.resource
        and entry.get("scope") == service.scope
        and non_empty_string(entry.get("access_token"))
        and non_empty_string(entry.get("refresh_token"))
        and isinstance(entry.get("expires_at"), int | float)
    )


def login(env: Env, config: Config, service: Service) -> None:
    endpoints = discover(env, config.issuer)
    response = env.http(
        endpoints.device_authorization,
        {
            "client_id": config.client_id,
            "scope": " ".join(filter(None, [service.scope, "offline_access"])),
            "resource": service.resource,
        },
    )
    if response.status != 200 or response.body is None:
        raise_for("device authorization", response)
    answer = response.body
    device_code = answer.get("device_code")
    user_code = answer.get("user_code")
    verification_uri = answer.get("verification_uri")
    interval = answer.get("interval", DEFAULT_POLL_INTERVAL_SECONDS)
    expires_in = answer.get("expires_in")
    if not all(non_empty_string(value) for value in (device_code, user_code, verification_uri)) or not (
        positive_number(interval) and positive_number(expires_in)
    ):
        raise Failure("device authorization answer is incomplete")
    deadline = env.clock() + expires_in
    complete_uri = answer.get("verification_uri_complete")

    print(f"Open {verification_uri} and enter the code {user_code}", file=env.stderr)
    env.open_browser(complete_uri if non_empty_string(complete_uri) else verification_uri)

    while True:
        if env.clock() >= deadline:
            raise Failure("the code expired before the sign in finished: run login again")
        env.sleep(interval)
        response = env.http(
            endpoints.token,
            {"grant_type": DEVICE_CODE_GRANT, "client_id": config.client_id, "device_code": device_code},
        )
        if response.status == 200:
            break
        match error_code(response):
            case "authorization_pending":
                continue
            case "slow_down":
                interval += SLOW_DOWN_SECONDS
                continue
            case "access_denied":
                raise Failure("the sign in was denied")
            case "expired_token":
                raise Failure("the code expired before the sign in finished: run login again")
        raise_for("token endpoint", response)

    tokens = parse_tokens(env, response.body)
    if tokens.refresh_token is None:
        raise Failure("the server sent no refresh token: the client lacks the offline_access scope or the refresh_token grant")
    with service_lock(env.state_dir, service.name):
        env.store.write(service.name, make_entry(config, service, tokens, tokens.refresh_token))
    print(f"signed in to {service.name}", file=env.stderr)


def refresh(env: Env, config: Config, service: Service, entry: dict) -> dict:
    endpoints = discover(env, config.issuer)
    response = env.http(
        endpoints.token,
        {"grant_type": "refresh_token", "client_id": config.client_id, "refresh_token": entry["refresh_token"]},
    )
    if response.status != 200:
        if error_code(response) == "invalid_grant":
            env.store.delete(service.name)
            raise SignInNeeded(f"sign in again: oauth-token login {service.name}")
        raise TemporaryFailure(f"refresh answered {describe(response)}")
    try:
        tokens = parse_tokens(env, response.body)
    except Failure as error:
        raise TemporaryFailure(str(error)) from None
    new_entry = make_entry(config, service, tokens, tokens.refresh_token or entry["refresh_token"])
    env.store.write(service.name, new_entry)
    return new_entry


def token(env: Env, config: Config, service: Service, as_header: bool) -> None:
    with service_lock(env.state_dir, service.name):
        entry = env.store.read(service.name)
        if entry is None or not entry_matches(entry, config, service):
            raise SignInNeeded(f"not signed in: oauth-token login {service.name}")
        if env.clock() >= entry["expires_at"] - EXPIRY_MARGIN_SECONDS:
            entry = refresh(env, config, service, entry)
    access_token = entry["access_token"]
    env.stdout.write(f"Authorization: Bearer {access_token}\n" if as_header else f"{access_token}\n")
    env.stdout.flush()


def logout(env: Env, service: Service) -> None:
    with service_lock(env.state_dir, service.name):
        env.store.delete(service.name)
    print(f"signed out of {service.name}", file=env.stderr)


def parse_arguments(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="oauth-token",
        description="Sign in once with the OAuth 2.0 device grant, then print access tokens.",
        epilog="exit status: 0 ok, 1 error, 2 wrong arguments, 3 sign in needed, 4 temporary failure",
    )
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("login", help="sign in to a service").add_argument("service")
    token_parser = commands.add_parser("token", help="print an access token on stdout")
    token_parser.add_argument("service")
    token_parser.add_argument("--header", action="store_true", help="print an Authorization header line")
    commands.add_parser("logout", help="remove the stored sign in").add_argument("service")
    return parser.parse_args(argv)


def run(argv: list[str], env: Env) -> int:
    arguments = parse_arguments(argv)
    try:
        config = load_config(env.config_path)
        service = find_service(config, arguments.service, env.config_path)
        match arguments.command:
            case "login":
                login(env, config, service)
            case "token":
                token(env, config, service, arguments.header)
            case "logout":
                logout(env, service)
    except Failure as error:
        print(error, file=env.stderr)
        return error.status
    return EXIT_OK


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


_OPENER = urllib.request.build_opener(_NoRedirect)


def _json_object(raw: bytes) -> dict | None:
    try:
        value = json.loads(raw)
    except ValueError:
        return None
    return value if isinstance(value, dict) else None


def http_request(url: str, form: dict[str, str] | None) -> Response:
    data = urllib.parse.urlencode(form).encode() if form is not None else None
    request = urllib.request.Request(url, data=data, headers={"Accept": "application/json"})
    try:
        with _OPENER.open(request, timeout=REQUEST_TIMEOUT_SECONDS) as response:
            return Response(response.status, _json_object(response.read()))
    except urllib.error.HTTPError as error:
        with error:
            return Response(error.code, _json_object(error.read()))
    except urllib.error.URLError as error:
        raise TemporaryFailure(f"request to {url} failed: {error.reason}") from None
    except (OSError, http.client.HTTPException) as error:
        raise TemporaryFailure(f"request to {url} failed: {type(error).__name__}") from None


class KeychainStore:
    """One generic password per service. The value goes to security on stdin."""

    def __init__(self, keychain_service: str = KEYCHAIN_SERVICE) -> None:
        self.keychain_service = keychain_service

    def _security(self, arguments: list[str], stdin: str | None = None) -> subprocess.CompletedProcess:
        return subprocess.run(["/usr/bin/security", *arguments], input=stdin, capture_output=True, text=True)

    def read(self, account: str) -> dict | None:
        result = self._security(["find-generic-password", "-s", self.keychain_service, "-a", account, "-w"])
        if result.returncode == KEYCHAIN_NOT_FOUND_STATUS:
            return None
        if result.returncode != 0:
            raise Failure(f"keychain read failed with status {result.returncode}")
        try:
            value = json.loads(result.stdout)
        except ValueError:
            return None
        return value if isinstance(value, dict) else None

    def write(self, account: str, entry: dict) -> None:
        value = json.dumps(entry).encode().hex()
        line = f"add-generic-password -U -s {self.keychain_service} -a {account} -X {value}\n"
        if len(line.encode()) > KEYCHAIN_MAX_LINE_BYTES:
            raise Failure(f"the sign in is too large for the keychain ({len(line)} bytes)")
        result = self._security(["-i"], stdin=line)
        if result.returncode != 0:
            raise Failure(f"keychain write failed with status {result.returncode}")

    def delete(self, account: str) -> None:
        result = self._security(["delete-generic-password", "-s", self.keychain_service, "-a", account])
        if result.returncode not in (0, KEYCHAIN_NOT_FOUND_STATUS):
            raise Failure(f"keychain delete failed with status {result.returncode}")


def open_in_browser(url: str) -> None:
    subprocess.run(["/usr/bin/open", url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)


def main() -> int:
    if sys.platform != "darwin":
        print("oauth-token needs macOS: it keeps the sign in in the macOS Keychain", file=sys.stderr)
        return EXIT_ERROR
    home = Path.home()
    env = Env(
        http=http_request,
        clock=time.time,
        sleep=time.sleep,
        store=KeychainStore(),
        open_browser=open_in_browser,
        config_path=home / ".config" / "oauth-token" / "config.toml",
        state_dir=home / ".local" / "state" / "oauth-token",
        stdout=sys.stdout,
        stderr=sys.stderr,
    )
    return run(sys.argv[1:], env)


if __name__ == "__main__":
    sys.exit(main())
