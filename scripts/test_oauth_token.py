import contextlib
import http.server
import io
import itertools
import json
import secrets
import tempfile
import threading
import unittest
import urllib.request
import urllib.response
from email.message import Message
from pathlib import Path
from unittest import mock

import oauth_token as ot

ISSUER = "https://auth.example.com"
DISCOVERY_URL = ISSUER + "/.well-known/openid-configuration"
DEVICE_URL = ISSUER + "/api/oidc/device-authorization"
TOKEN_URL = ISSUER + "/api/oidc/token"
RESOURCE = "https://media.example.com"
OTHER_RESOURCE = "https://media.example.com/narrow"
ACCESS_LIFETIME = 3600
POLL_INTERVAL = 5

CONFIG = f"""
issuer = "{ISSUER}"
client_id = "cli"

[services.media]
resource = "{RESOURCE}"
scope = "media:watch"
"""


def error(status: int, code: str) -> "ot.Response":
    return ot.Response(status, {"error": code})


class FakeClock:
    def __init__(self) -> None:
        self.now = 1_000_000.0
        self.sleeps: list[float] = []

    def __call__(self) -> float:
        return self.now

    def sleep(self, seconds: float) -> None:
        self.sleeps.append(seconds)
        self.now += seconds


class FakeAuthServer:
    """Authorization server that behaves as Authelia 4.39 does on refresh."""

    def __init__(self) -> None:
        self.lock = threading.Lock()
        self.requests: list[tuple[str, dict | None]] = []
        self.discovery = {
            "issuer": ISSUER,
            "device_authorization_endpoint": DEVICE_URL,
            "token_endpoint": TOKEN_URL,
        }
        self.poll_answers: list[str] = []
        self.injected: dict[str, list] = {}
        self.issue_refresh_token = True
        self.rotate_refresh_token = True
        self.refresh_hook = None
        self.grants: dict[int, dict] = {}
        self.refresh_tokens: dict[str, dict] = {}
        self.access_tokens: dict[str, int] = {}
        self.in_flight: set[str] = set()
        self.device_codes: dict[str, str] = {}
        self.secrets: set[str] = set()
        self.counter = itertools.count(1)

    def _secret(self, prefix: str) -> str:
        value = f"{prefix}-{next(self.counter)}-{secrets.token_hex(8)}"
        self.secrets.add(value)
        return value

    def __call__(self, url: str, form: dict[str, str] | None) -> "ot.Response":
        with self.lock:
            self.requests.append((url, None if form is None else dict(form)))
            queued = self.injected.get(url)
            answer = queued.pop(0) if queued else None
        if isinstance(answer, Exception):
            raise answer
        if answer is not None:
            return answer
        if url == DISCOVERY_URL and form is None:
            return ot.Response(200, dict(self.discovery))
        if url == DEVICE_URL and form is not None:
            return self._device_authorization(form)
        if url == TOKEN_URL and form is not None:
            if form.get("grant_type") == ot.DEVICE_CODE_GRANT:
                return self._device_token(form)
            if form.get("grant_type") == "refresh_token":
                return self._refresh(form)
            return error(400, "unsupported_grant_type")
        return ot.Response(404, None)

    def inject(self, url: str, *answers) -> None:
        self.injected.setdefault(url, []).extend(answers)

    def forms(self, url: str) -> list[dict]:
        return [form for request_url, form in self.requests if request_url == url and form is not None]

    def refresh_forms(self) -> list[dict]:
        return [form for form in self.forms(TOKEN_URL) if form.get("grant_type") == "refresh_token"]

    def _device_authorization(self, form: dict[str, str]) -> "ot.Response":
        device_code = self._secret("device")
        self.device_codes[device_code] = form["resource"]
        return ot.Response(
            200,
            {
                "device_code": device_code,
                "user_code": "ABCD-EFGH",
                "verification_uri": ISSUER + "/device",
                "verification_uri_complete": ISSUER + "/device?user_code=ABCD-EFGH",
                "expires_in": 600,
                "interval": POLL_INTERVAL,
            },
        )

    def _issue(self, grant_id: int, refresh_token: str | None) -> "ot.Response":
        access_token = self._secret("access")
        self.access_tokens[access_token] = grant_id
        body = {"access_token": access_token, "token_type": "bearer", "expires_in": ACCESS_LIFETIME}
        if refresh_token is not None:
            body["refresh_token"] = refresh_token
        return ot.Response(200, body)

    def _new_refresh_token(self, grant_id: int) -> str:
        refresh_token = self._secret("refresh")
        self.refresh_tokens[refresh_token] = {"grant": grant_id, "used": False}
        return refresh_token

    def _device_token(self, form: dict[str, str]) -> "ot.Response":
        resource = self.device_codes.get(form["device_code"])
        if resource is None:
            return error(400, "invalid_grant")
        if self.poll_answers:
            return error(400, self.poll_answers.pop(0))
        grant_id = next(self.counter)
        self.grants[grant_id] = {"audience": [resource], "active": True}
        refresh_token = self._new_refresh_token(grant_id) if self.issue_refresh_token else None
        return self._issue(grant_id, refresh_token)

    def _refresh(self, form: dict[str, str]) -> "ot.Response":
        presented = form["refresh_token"]
        with self.lock:
            record = self.refresh_tokens.get(presented)
            if record is None or not self.grants[record["grant"]]["active"]:
                return error(400, "invalid_grant")
            if presented in self.in_flight:
                return error(400, "invalid_request")
            grant = self.grants[record["grant"]]
            if record["used"]:
                grant["active"] = False
                return error(400, "invalid_grant")
            self.in_flight.add(presented)
        try:
            if self.refresh_hook is not None:
                self.refresh_hook()
            with self.lock:
                if "resource" in form:
                    if form["resource"] not in grant["audience"]:
                        return error(400, "invalid_target")
                    grant["audience"] = [form["resource"]]
                if not self.rotate_refresh_token:
                    return self._issue(record["grant"], None)
                record["used"] = True
                return self._issue(record["grant"], self._new_refresh_token(record["grant"]))
        finally:
            with self.lock:
                self.in_flight.discard(presented)

    def audience_of(self, access_token: str) -> list[str] | None:
        grant = self.grants.get(self.access_tokens.get(access_token, -1))
        return list(grant["audience"]) if grant and grant["active"] else None

    def revoke_all(self) -> None:
        for grant in self.grants.values():
            grant["active"] = False


class MemoryStore:
    def __init__(self) -> None:
        self.entries: dict[str, str] = {}
        self.reads = 0
        self.writes = 0
        self.on_read = None

    def read(self, account: str) -> dict | None:
        self.reads += 1
        if self.on_read is not None:
            self.on_read(self.reads)
        value = self.entries.get(account)
        return None if value is None else json.loads(value)

    def write(self, account: str, entry: dict) -> None:
        self.writes += 1
        self.entries[account] = json.dumps(entry)

    def delete(self, account: str) -> None:
        self.entries.pop(account, None)

    def entry(self, account: str = "media") -> dict | None:
        value = self.entries.get(account)
        return None if value is None else json.loads(value)


class OAuthTokenTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = Path(self.enterContext(tempfile.TemporaryDirectory()))
        self.config_path = self.directory / "config.toml"
        self.config_path.write_text(CONFIG)
        self.server = FakeAuthServer()
        self.clock = FakeClock()
        self.store = MemoryStore()
        self.opened: list[str] = []
        self.envs: list = []

    def tearDown(self) -> None:
        for env in self.envs:
            stderr = env.stderr.getvalue()
            for secret in self.server.secrets:
                self.assertNotIn(secret, stderr)

    def make_env(self):
        env = ot.Env(
            http=self.server,
            clock=self.clock,
            sleep=self.clock.sleep,
            store=self.store,
            open_browser=self.opened.append,
            config_path=self.config_path,
            state_dir=self.directory / "state",
            stdout=io.StringIO(),
            stderr=io.StringIO(),
        )
        self.envs.append(env)
        return env

    def run_command(self, *argv: str):
        env = self.make_env()
        status = ot.run(list(argv), env)
        return status, env.stdout.getvalue(), env.stderr.getvalue()

    def login(self) -> dict:
        status, stdout, _ = self.run_command("login", "media")
        self.assertEqual(status, ot.EXIT_OK)
        self.assertEqual(stdout, "")
        return self.store.entry()

    def expire(self) -> None:
        self.clock.now = self.store.entry()["expires_at"] - ot.EXPIRY_MARGIN_SECONDS


class FakeServerTest(OAuthTokenTestCase):
    def signed_in(self) -> tuple[str, str]:
        device = self.server(DEVICE_URL, {"client_id": "cli", "scope": "media:watch offline_access", "resource": RESOURCE})
        answer = self.server(TOKEN_URL, {"grant_type": ot.DEVICE_CODE_GRANT, "client_id": "cli", "device_code": device.body["device_code"]})
        return answer.body["access_token"], answer.body["refresh_token"]

    def refresh(self, refresh_token: str, **extra: str) -> "ot.Response":
        return self.server(TOKEN_URL, {"grant_type": "refresh_token", "client_id": "cli", "refresh_token": refresh_token, **extra})

    def test_fact_1_refresh_keeps_audience(self) -> None:
        _, refresh_token = self.signed_in()
        answer = self.refresh(refresh_token)
        self.assertEqual(self.server.audience_of(answer.body["access_token"]), [RESOURCE])

    def test_fact_2_narrower_resource_narrows_for_good(self) -> None:
        _, refresh_token = self.signed_in()
        self.server.grants[next(iter(self.server.grants))]["audience"].append(OTHER_RESOURCE)
        narrowed = self.refresh(refresh_token, resource=OTHER_RESOURCE)
        later = self.refresh(narrowed.body["refresh_token"])
        self.assertEqual(self.server.audience_of(later.body["access_token"]), [OTHER_RESOURCE])

    def test_fact_3_every_refresh_rotates(self) -> None:
        _, first = self.signed_in()
        second = self.refresh(first).body["refresh_token"]
        third = self.refresh(second).body["refresh_token"]
        self.assertEqual(len({first, second, third}), 3)

    def test_fact_4_reused_refresh_token_revokes_the_sign_in(self) -> None:
        _, old = self.signed_in()
        fresh = self.refresh(old).body
        self.assertEqual(self.refresh(old), error(400, "invalid_grant"))
        self.assertIsNone(self.server.audience_of(fresh["access_token"]))
        self.assertEqual(self.refresh(fresh["refresh_token"]), error(400, "invalid_grant"))

    def test_fact_5_simultaneous_refresh_gets_invalid_request(self) -> None:
        _, refresh_token = self.signed_in()
        answers = []
        self.server.refresh_hook = lambda: answers.append(self.refresh(refresh_token))
        first = self.refresh(refresh_token)
        self.server.refresh_hook = None
        self.assertEqual(answers, [error(400, "invalid_request")])
        self.assertEqual(self.server.audience_of(first.body["access_token"]), [RESOURCE])
        self.assertEqual(self.refresh(first.body["refresh_token"]).status, 200)


class LoginTest(OAuthTokenTestCase):
    def test_device_authorization_and_poll_requests(self) -> None:
        self.login()
        self.assertEqual(self.server.requests[0], (DISCOVERY_URL, None))
        self.assertEqual(
            self.server.forms(DEVICE_URL),
            [{"client_id": "cli", "scope": "media:watch offline_access", "resource": RESOURCE}],
        )
        [poll] = self.server.forms(TOKEN_URL)
        self.assertEqual(set(poll), {"grant_type", "client_id", "device_code"})
        self.assertEqual(poll["grant_type"], "urn:ietf:params:oauth:grant-type:device_code")
        self.assertEqual(poll["client_id"], "cli")

    def test_prints_code_opens_browser_and_stores(self) -> None:
        status, stdout, stderr = self.run_command("login", "media")
        self.assertEqual((status, stdout), (ot.EXIT_OK, ""))
        self.assertIn(ISSUER + "/device", stderr)
        self.assertIn("ABCD-EFGH", stderr)
        self.assertTrue(stderr.endswith("signed in to media\n"))
        self.assertEqual(self.opened, [ISSUER + "/device?user_code=ABCD-EFGH"])
        entry = self.store.entry()
        self.assertEqual((entry["issuer"], entry["client_id"], entry["resource"]), (ISSUER, "cli", RESOURCE))
        self.assertEqual(entry["expires_at"], self.clock.now + ACCESS_LIFETIME)

    def test_authorization_pending_keeps_polling(self) -> None:
        self.server.poll_answers = ["authorization_pending", "authorization_pending"]
        self.login()
        self.assertEqual(self.clock.sleeps, [POLL_INTERVAL] * 3)

    def test_slow_down_adds_five_seconds(self) -> None:
        self.server.poll_answers = ["slow_down", "authorization_pending", "slow_down"]
        self.login()
        self.assertEqual(self.clock.sleeps, [5, 10, 10, 15])

    def test_access_denied(self) -> None:
        self.server.poll_answers = ["access_denied"]
        status, _, stderr = self.run_command("login", "media")
        self.assertEqual(status, ot.EXIT_ERROR)
        self.assertIn("denied", stderr)
        self.assertIsNone(self.store.entry())

    def test_expired_token(self) -> None:
        self.server.poll_answers = ["expired_token"]
        status, _, stderr = self.run_command("login", "media")
        self.assertEqual(status, ot.EXIT_ERROR)
        self.assertIn("expired", stderr)
        self.assertIsNone(self.store.entry())

    def test_gives_up_when_the_code_expires(self) -> None:
        self.server.poll_answers = ["authorization_pending"] * 1000
        status, _, stderr = self.run_command("login", "media")
        self.assertEqual(status, ot.EXIT_ERROR)
        self.assertIn("expired", stderr)
        self.assertEqual(sum(self.clock.sleeps), 600)

    def test_no_refresh_token_means_no_offline_access(self) -> None:
        self.server.issue_refresh_token = False
        status, _, stderr = self.run_command("login", "media")
        self.assertEqual(status, ot.EXIT_ERROR)
        self.assertIn("offline_access", stderr)
        self.assertIsNone(self.store.entry())

    def test_token_answer_needs_access_token_and_expires_in(self) -> None:
        for body in ({"refresh_token": "r", "expires_in": 60}, {"access_token": "a", "refresh_token": "r", "expires_in": 0}):
            self.server.inject(TOKEN_URL, ot.Response(200, body))
            status, _, _ = self.run_command("login", "media")
            self.assertEqual(status, ot.EXIT_ERROR)
            self.assertIsNone(self.store.entry())


class TokenTest(OAuthTokenTestCase):
    def test_reuses_stored_access_token(self) -> None:
        entry = self.login()
        requests = len(self.server.requests)
        self.clock.now += ACCESS_LIFETIME - ot.EXPIRY_MARGIN_SECONDS - 1
        first = self.run_command("token", "media")
        second = self.run_command("token", "media")
        self.assertEqual(first, (ot.EXIT_OK, entry["access_token"] + "\n", ""))
        self.assertEqual(second, first)
        self.assertEqual(len(self.server.requests), requests)

    def test_refreshes_60_seconds_before_expiry(self) -> None:
        entry = self.login()
        self.clock.now = entry["expires_at"] - 61
        self.run_command("token", "media")
        self.assertEqual(self.server.refresh_forms(), [])
        self.clock.now = entry["expires_at"] - 60
        status, stdout, _ = self.run_command("token", "media")
        self.assertEqual(status, ot.EXIT_OK)
        self.assertEqual(len(self.server.refresh_forms()), 1)
        self.assertNotEqual(stdout, entry["access_token"] + "\n")
        self.assertEqual(self.server.audience_of(stdout.strip()), [RESOURCE])

    def test_refresh_request_sends_no_resource_and_no_scope(self) -> None:
        entry = self.login()
        self.expire()
        self.run_command("token", "media")
        self.assertEqual(
            self.server.refresh_forms(),
            [{"grant_type": "refresh_token", "client_id": "cli", "refresh_token": entry["refresh_token"]}],
        )

    def test_rotated_refresh_token_is_stored_at_once(self) -> None:
        for _ in range(3):
            before = self.login() if self.store.entry() is None else self.store.entry()
            self.expire()
            status, stdout, _ = self.run_command("token", "media")
            after = self.store.entry()
            self.assertEqual(status, ot.EXIT_OK)
            self.assertNotEqual(after["refresh_token"], before["refresh_token"])
            self.assertEqual(after["access_token"], stdout.strip())
            self.assertEqual(after["expires_at"], self.clock.now + ACCESS_LIFETIME)
        self.assertTrue(all(grant["active"] for grant in self.server.grants.values()))

    def test_refresh_without_new_refresh_token_keeps_the_old_one(self) -> None:
        entry = self.login()
        self.server.rotate_refresh_token = False
        self.expire()
        self.run_command("token", "media")
        self.assertEqual(self.store.entry()["refresh_token"], entry["refresh_token"])
        self.assertNotEqual(self.store.entry()["access_token"], entry["access_token"])

    def test_invalid_grant_removes_the_sign_in(self) -> None:
        self.login()
        self.server.revoke_all()
        self.expire()
        status, stdout, stderr = self.run_command("token", "media")
        self.assertEqual((status, stdout, stderr), (ot.EXIT_SIGN_IN_NEEDED, "", "sign in again: oauth-token login media\n"))
        self.assertIsNone(self.store.entry())

    def test_temporary_failures_keep_the_sign_in(self) -> None:
        failures = [
            ot.Response(503, None),
            ot.Response(502, {"error": "server_error"}),
            error(400, "invalid_request"),
            ot.Response(302, None),
            ot.TemporaryFailure("request to the token endpoint failed: timed out"),
            ot.Response(200, {"token_type": "bearer"}),
        ]
        entry = self.login()
        self.expire()
        for failure in failures:
            self.server.inject(TOKEN_URL, failure)
            status, stdout, stderr = self.run_command("token", "media")
            self.assertEqual((status, stdout), (ot.EXIT_TEMPORARY, ""), failure)
            self.assertEqual(self.store.entry(), entry)
        self.assertEqual(self.run_command("token", "media")[0], ot.EXIT_OK)

    def test_discovery_outage_is_temporary(self) -> None:
        entry = self.login()
        self.expire()
        self.server.inject(DISCOVERY_URL, ot.Response(503, None))
        self.assertEqual(self.run_command("token", "media")[0], ot.EXIT_TEMPORARY)
        self.assertEqual(self.store.entry(), entry)

    def test_header_output(self) -> None:
        entry = self.login()
        status, stdout, stderr = self.run_command("token", "--header", "media")
        self.assertEqual((status, stdout, stderr), (ot.EXIT_OK, f"Authorization: Bearer {entry['access_token']}\n", ""))

    def test_not_signed_in(self) -> None:
        status, stdout, stderr = self.run_command("token", "media")
        self.assertEqual((status, stdout, stderr), (ot.EXIT_SIGN_IN_NEEDED, "", "not signed in: oauth-token login media\n"))
        self.assertEqual(self.server.requests, [])

    def test_entry_for_another_configuration_counts_as_no_sign_in(self) -> None:
        entry = self.login()
        for field, value in (
            ("issuer", "https://other.example.com"),
            ("client_id", "other"),
            ("resource", OTHER_RESOURCE),
            ("scope", "media:other"),
        ):
            self.store.write("media", {**entry, field: value})
            requests = len(self.server.requests)
            status, stdout, _ = self.run_command("token", "media")
            self.assertEqual((status, stdout), (ot.EXIT_SIGN_IN_NEEDED, ""), field)
            self.assertEqual(len(self.server.requests), requests)

    def test_logout_removes_the_sign_in(self) -> None:
        self.login()
        status, stdout, stderr = self.run_command("logout", "media")
        self.assertEqual((status, stdout, stderr), (ot.EXIT_OK, "", "signed out of media\n"))
        self.assertIsNone(self.store.entry())
        self.assertEqual(self.run_command("token", "media")[0], ot.EXIT_SIGN_IN_NEEDED)

    def test_exit_statuses_are_distinct(self) -> None:
        self.assertEqual(len({ot.EXIT_OK, ot.EXIT_ERROR, 2, ot.EXIT_SIGN_IN_NEEDED, ot.EXIT_TEMPORARY}), 5)

    def test_two_threads_refresh_exactly_once(self) -> None:
        self.login()
        self.expire()
        second_read = threading.Event()
        self.store.reads = 0
        self.store.on_read = lambda count: second_read.set() if count == 2 else None
        # Without the lock, the second thread reads the old refresh token while
        # the first one is inside the refresh. With it, this wait runs out.
        self.server.refresh_hook = lambda: second_read.wait(0.5)
        start = threading.Barrier(2)
        results: list = [None, None]

        def ask(index: int) -> None:
            env = self.make_env()
            start.wait()
            results[index] = (ot.run(["token", "media"], env), env.stdout.getvalue())

        threads = [threading.Thread(target=ask, args=(index,)) for index in range(2)]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join()

        self.assertEqual([status for status, _ in results], [ot.EXIT_OK, ot.EXIT_OK])
        self.assertEqual(results[0][1], results[1][1])
        self.assertEqual(len(self.server.refresh_forms()), 1)
        self.assertEqual(self.server.audience_of(results[0][1].strip()), [RESOURCE])
        self.assertEqual(self.store.entry()["access_token"], results[0][1].strip())


class ErrorMessageTest(OAuthTokenTestCase):
    MARKER = "marker-from-the-server"

    def leaky(self, code: str) -> "ot.Response":
        return ot.Response(400, {"error": code, "error_description": self.MARKER, "detail": self.MARKER})

    def test_errors_name_the_status_and_the_code_only(self) -> None:
        self.server.inject(DEVICE_URL, self.leaky("invalid_scope"))
        device = self.run_command("login", "media")
        self.server.inject(TOKEN_URL, self.leaky("invalid_client"))
        poll = self.run_command("login", "media")
        self.login()
        self.expire()
        self.server.inject(TOKEN_URL, self.leaky("invalid_request"))
        refresh = self.run_command("token", "media")
        cases = (
            (device, ot.EXIT_ERROR, "invalid_scope"),
            (poll, ot.EXIT_ERROR, "invalid_client"),
            (refresh, ot.EXIT_TEMPORARY, "invalid_request"),
        )
        for (status, stdout, stderr), expected_status, code in cases:
            self.assertEqual((status, stdout), (expected_status, ""), code)
            self.assertIn(f"HTTP 400 {code}", stderr)
            self.assertNotIn(self.MARKER, stderr)


class ConfigurationTest(OAuthTokenTestCase):
    def test_refuses_issuer_that_is_not_https(self) -> None:
        self.config_path.write_text(CONFIG.replace("https://auth", "http://auth"))
        status, _, stderr = self.run_command("login", "media")
        self.assertEqual(status, ot.EXIT_ERROR)
        self.assertIn("https", stderr)
        self.assertEqual(self.server.requests, [])

    def test_refuses_discovery_document_with_another_issuer(self) -> None:
        self.server.discovery["issuer"] = "https://evil.example.com"
        status, _, stderr = self.run_command("login", "media")
        self.assertEqual(status, ot.EXIT_ERROR)
        self.assertIn("another issuer", stderr)
        self.assertEqual(self.server.forms(DEVICE_URL), [])

    def test_refuses_endpoint_that_is_not_https(self) -> None:
        for field in ("device_authorization_endpoint", "token_endpoint"):
            self.server.discovery = {**FakeAuthServer().discovery, field: "http://auth.example.com/x"}
            status, _, _ = self.run_command("login", "media")
            self.assertEqual(status, ot.EXIT_ERROR, field)
        self.assertEqual(self.server.forms(DEVICE_URL), [])

    def test_unknown_service(self) -> None:
        status, _, stderr = self.run_command("token", "other")
        self.assertEqual(status, ot.EXIT_ERROR)
        self.assertIn("no service 'other'", stderr)

    def test_missing_configuration(self) -> None:
        self.config_path.unlink()
        self.assertEqual(self.run_command("token", "media")[0], ot.EXIT_ERROR)

    def test_service_name_must_be_plain(self) -> None:
        self.config_path.write_text(CONFIG.replace("[services.media]", '[services."me dia"]'))
        self.assertEqual(self.run_command("token", "me dia")[0], ot.EXIT_ERROR)


class FakeHttpsHandler(urllib.request.HTTPSHandler):
    def __init__(self) -> None:
        super().__init__()
        self.requests: list = []

    def https_open(self, request):
        self.requests.append(request)
        headers = Message()
        headers["Location"] = "https://elsewhere.example.com/"
        response = urllib.response.addinfourl(io.BytesIO(b""), headers, request.full_url, code=302)
        response.msg = "Found"
        return response


class RedirectingHandler(http.server.BaseHTTPRequestHandler):
    def do_POST(self) -> None:
        self.server.paths.append(self.path)
        self.rfile.read(int(self.headers.get("Content-Length", 0)))
        self.send_response(302)
        self.send_header("Location", "/target")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def log_message(self, *arguments) -> None:
        pass


class HttpRequestTest(unittest.TestCase):
    def test_times_out_after_10_seconds(self) -> None:
        handler = FakeHttpsHandler()
        with mock.patch.object(ot, "_OPENER", urllib.request.build_opener(ot._NoRedirect, handler)):
            ot.http_request(TOKEN_URL, {"client_id": "cli"})
        self.assertEqual(handler.requests[0].timeout, 10)

    def test_real_opener_does_not_follow_a_redirect(self) -> None:
        server = http.server.HTTPServer(("127.0.0.1", 0), RedirectingHandler)
        server.paths = []
        thread = threading.Thread(target=server.serve_forever)
        thread.start()
        self.addCleanup(thread.join)
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        response = ot.http_request(f"http://127.0.0.1:{server.server_port}/start", {"client_id": "cli"})
        self.assertEqual(response.status, 302)
        self.assertEqual(server.paths, ["/start"])


class KeychainStoreTest(unittest.TestCase):
    def setUp(self) -> None:
        self.calls: list = []
        self.answer = mock.Mock(returncode=0, stdout="")

        def fake_run(argv, **kwargs):
            self.calls.append((argv, kwargs.get("input")))
            return self.answer

        self.enterContext(mock.patch.object(ot.subprocess, "run", fake_run))
        self.store = ot.KeychainStore()

    def test_write_passes_the_value_on_stdin_only(self) -> None:
        entry = {"access_token": "access-secret", "refresh_token": "refresh-secret"}
        self.store.write("media", entry)
        [(argv, stdin)] = self.calls
        self.assertEqual(argv, ["/usr/bin/security", "-i"])
        self.assertEqual(stdin, f"add-generic-password -U -s oauth-token -a media -X {json.dumps(entry).encode().hex()}\n")

    def test_write_refuses_a_line_security_would_cut(self) -> None:
        with self.assertRaises(ot.Failure):
            self.store.write("media", {"access_token": "a" * 2100})
        self.assertEqual(self.calls, [])

    def test_write_failure_is_an_error(self) -> None:
        self.answer.returncode = 1
        with self.assertRaises(ot.Failure):
            self.store.write("media", {})

    def test_read(self) -> None:
        self.answer.stdout = '{"access_token": "a"}\n'
        self.assertEqual(self.store.read("media"), {"access_token": "a"})
        self.assertEqual(self.calls[0][0], ["/usr/bin/security", "find-generic-password", "-s", "oauth-token", "-a", "media", "-w"])
        self.answer.returncode = 44
        self.assertIsNone(self.store.read("media"))

    def test_delete_of_a_missing_item_is_fine(self) -> None:
        self.answer.returncode = 44
        self.store.delete("media")
        self.assertEqual(self.calls[0][0], ["/usr/bin/security", "delete-generic-password", "-s", "oauth-token", "-a", "media"])


class PlatformTest(unittest.TestCase):
    def test_other_systems_get_a_clear_message(self) -> None:
        stderr = io.StringIO()
        with mock.patch.object(ot.sys, "platform", "linux"), contextlib.redirect_stderr(stderr):
            self.assertEqual(ot.main(), ot.EXIT_ERROR)
        self.assertIn("needs macOS", stderr.getvalue())


if __name__ == "__main__":
    unittest.main()
