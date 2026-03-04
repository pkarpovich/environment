#!/usr/bin/env python3

import os
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone

GATUS_URL = os.environ.get("GATUS_URL", "")
GATUS_TOKEN = os.environ.get("GATUS_TOKEN", "")
MAX_BACKUP_AGE_HOURS = int(os.environ.get("MAX_BACKUP_AGE_HOURS", "48"))

BACKUP_DATE_PATTERN = re.compile(r"(\d{4}-\d{2}-\d{2}-\d{6})")


def log(msg):
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    print(f"[{ts}] {msg}", flush=True)


def get_latest_backup_time() -> datetime | None:
    try:
        result = subprocess.run(
            ["tmutil", "latestbackup"],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode != 0:
            log(f"tmutil failed: {result.stderr.strip()}")
            return None

        if match := BACKUP_DATE_PATTERN.search(result.stdout.strip()):
            return datetime.strptime(match.group(1), "%Y-%m-%d-%H%M%S")

        log(f"no date found in tmutil output: {result.stdout.strip()}")
        return None
    except Exception as e:
        log(f"error getting backup time: {e}")
        return None


def push_to_gatus(success: bool, error_message: str = ""):
    params = f"?success={str(success).lower()}"
    if error_message:
        params += f"&error={urllib.parse.quote(error_message)}"

    req = urllib.request.Request(
        f"{GATUS_URL}{params}",
        method="POST",
        headers={"Authorization": f"Bearer {GATUS_TOKEN}"},
    )
    try:
        urllib.request.urlopen(req, timeout=10)
        log(f"pushed to gatus: success={success}")
    except Exception as e:
        log(f"gatus push failed: {e}")


def check_and_report():
    backup_time = get_latest_backup_time()
    if not backup_time:
        push_to_gatus(False, "could not determine latest backup time")
        return

    age_hours = (datetime.now() - backup_time).total_seconds() / 3600
    log(f"latest backup: {backup_time.isoformat()}, age: {age_hours:.1f}h")

    if age_hours <= MAX_BACKUP_AGE_HOURS:
        push_to_gatus(True)
    else:
        push_to_gatus(False, f"backup is {age_hours:.0f}h old")


def run_tests():
    import unittest
    from unittest.mock import patch, MagicMock

    class TestGetLatestBackupTime(unittest.TestCase):
        @patch("subprocess.run")
        def test_parses_date_from_apfs_path(self, mock_run):
            mock_run.return_value = MagicMock(
                returncode=0,
                stdout="/Volumes/Backup/Backups.backupdb/Mac/2026-03-03-142530\n",
            )
            result = get_latest_backup_time()
            self.assertEqual(result, datetime(2026, 3, 3, 14, 25, 30))

        @patch("subprocess.run")
        def test_parses_date_from_long_path(self, mock_run):
            mock_run.return_value = MagicMock(
                returncode=0,
                stdout="/Volumes/com.apple.TimeMachine/Backups.backupdb/MyMac/2026-01-15-083000\n",
            )
            result = get_latest_backup_time()
            self.assertEqual(result, datetime(2026, 1, 15, 8, 30, 0))

        @patch("subprocess.run")
        def test_returns_none_on_failure(self, mock_run):
            mock_run.return_value = MagicMock(
                returncode=1,
                stderr="No backups found",
            )
            self.assertIsNone(get_latest_backup_time())

        @patch("subprocess.run")
        def test_returns_none_on_no_date_match(self, mock_run):
            mock_run.return_value = MagicMock(
                returncode=0,
                stdout="/Volumes/Backup/something-else\n",
            )
            self.assertIsNone(get_latest_backup_time())

        @patch("subprocess.run")
        def test_returns_none_on_exception(self, mock_run):
            mock_run.side_effect = OSError("tmutil not found")
            self.assertIsNone(get_latest_backup_time())

    class TestPushToGatus(unittest.TestCase):
        @patch("urllib.request.urlopen")
        def test_sends_success(self, mock_urlopen):
            mock_urlopen.return_value = MagicMock()
            global GATUS_URL, GATUS_TOKEN
            old_url, old_token = GATUS_URL, GATUS_TOKEN
            GATUS_URL = "http://gatus/api/v1/endpoints/test/external"
            GATUS_TOKEN = "test-token"
            try:
                push_to_gatus(True)
            finally:
                GATUS_URL, GATUS_TOKEN = old_url, old_token

            req = mock_urlopen.call_args[0][0]
            self.assertIn("success=true", req.full_url)
            self.assertEqual(req.get_header("Authorization"), "Bearer test-token")
            self.assertEqual(req.get_method(), "POST")

        @patch("urllib.request.urlopen")
        def test_sends_failure_with_error(self, mock_urlopen):
            mock_urlopen.return_value = MagicMock()
            global GATUS_URL, GATUS_TOKEN
            old_url, old_token = GATUS_URL, GATUS_TOKEN
            GATUS_URL = "http://gatus/api/v1/endpoints/test/external"
            GATUS_TOKEN = "test-token"
            try:
                push_to_gatus(False, "backup is 72h old")
            finally:
                GATUS_URL, GATUS_TOKEN = old_url, old_token

            req = mock_urlopen.call_args[0][0]
            self.assertIn("success=false", req.full_url)
            self.assertIn("error=", req.full_url)

    class TestCheckAndReport(unittest.TestCase):
        @patch("subprocess.run")
        @patch("urllib.request.urlopen")
        def test_reports_success_for_recent_backup(self, mock_urlopen, mock_run):
            recent = datetime.now().strftime("%Y-%m-%d-%H%M%S")
            mock_run.return_value = MagicMock(
                returncode=0,
                stdout=f"/Volumes/Backup/Mac/{recent}\n",
            )
            mock_urlopen.return_value = MagicMock()
            global GATUS_URL, GATUS_TOKEN
            old_url, old_token = GATUS_URL, GATUS_TOKEN
            GATUS_URL = "http://gatus/api/v1/endpoints/test/external"
            GATUS_TOKEN = "test-token"
            try:
                check_and_report()
            finally:
                GATUS_URL, GATUS_TOKEN = old_url, old_token

            req = mock_urlopen.call_args[0][0]
            self.assertIn("success=true", req.full_url)

        @patch("subprocess.run")
        @patch("urllib.request.urlopen")
        def test_reports_failure_for_old_backup(self, mock_urlopen, mock_run):
            mock_run.return_value = MagicMock(
                returncode=0,
                stdout="/Volumes/Backup/Mac/2020-01-01-120000\n",
            )
            mock_urlopen.return_value = MagicMock()
            global GATUS_URL, GATUS_TOKEN
            old_url, old_token = GATUS_URL, GATUS_TOKEN
            GATUS_URL = "http://gatus/api/v1/endpoints/test/external"
            GATUS_TOKEN = "test-token"
            try:
                check_and_report()
            finally:
                GATUS_URL, GATUS_TOKEN = old_url, old_token

            req = mock_urlopen.call_args[0][0]
            self.assertIn("success=false", req.full_url)

        @patch("subprocess.run")
        @patch("urllib.request.urlopen")
        def test_reports_failure_when_no_backup_found(self, mock_urlopen, mock_run):
            mock_run.return_value = MagicMock(returncode=1, stderr="No backups")
            mock_urlopen.return_value = MagicMock()
            global GATUS_URL, GATUS_TOKEN
            old_url, old_token = GATUS_URL, GATUS_TOKEN
            GATUS_URL = "http://gatus/api/v1/endpoints/test/external"
            GATUS_TOKEN = "test-token"
            try:
                check_and_report()
            finally:
                GATUS_URL, GATUS_TOKEN = old_url, old_token

            req = mock_urlopen.call_args[0][0]
            self.assertIn("success=false", req.full_url)

    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    for tc in [TestGetLatestBackupTime, TestPushToGatus, TestCheckAndReport]:
        suite.addTests(loader.loadTestsFromTestCase(tc))
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    sys.exit(0 if result.wasSuccessful() else 1)


def main():
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--test", action="store_true")
    args = parser.parse_args()

    if args.test:
        run_tests()
        return

    if not GATUS_URL or not GATUS_TOKEN:
        log("GATUS_URL and GATUS_TOKEN are required")
        sys.exit(1)

    check_and_report()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\r\033[K", end="")
        sys.exit(130)
