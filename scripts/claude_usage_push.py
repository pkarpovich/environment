import json
import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

HISTORY_FILE = Path.home() / ".config/claude-usage-bar/history.json"
STATE_FILE = Path(
    os.environ.get(
        "CLAUDE_USAGE_PUSH_STATE",
        Path.home() / ".local/state/claude-usage-push/state.json",
    )
)


def load_points() -> list[dict]:
    try:
        history = json.loads(HISTORY_FILE.read_text())
    except (OSError, json.JSONDecodeError) as err:
        print(f"cannot read history: {err}", file=sys.stderr)
        return []

    points = []
    for raw in history.get("dataPoints", []):
        try:
            ts = datetime.fromisoformat(raw["timestamp"].replace("Z", "+00:00"))
            points.append({
                "measured_at": ts,
                "pct5h": round(float(raw["pct5h"]) * 100, 2),
                "pct7d": round(float(raw["pct7d"]) * 100, 2),
            })
        except (KeyError, TypeError, ValueError):
            continue
    points.sort(key=lambda p: p["measured_at"])
    return points


def last_pushed_at() -> datetime | None:
    try:
        state = json.loads(STATE_FILE.read_text())
        return datetime.fromisoformat(state["last_measured_at"])
    except (OSError, json.JSONDecodeError, KeyError, ValueError):
        return None


def save_state(measured_at: datetime) -> None:
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    tmp = STATE_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps({"last_measured_at": measured_at.isoformat()}))
    tmp.replace(STATE_FILE)


def main() -> int:
    points = load_points()
    if not points:
        return 0

    since = last_pushed_at()
    if since is None:
        fresh = points[-1:]
    else:
        fresh = [p for p in points if p["measured_at"] > since]
    if not fresh:
        return 0

    stale_cutoff = datetime.now(timezone.utc) - timedelta(days=2)
    for point in fresh:
        if point["measured_at"] < stale_cutoff:
            continue
        print(json.dumps({
            "msg": "subscription_usage",
            "pct5h": point["pct5h"],
            "pct7d": point["pct7d"],
            "measured_at": point["measured_at"].isoformat(),
        }))

    save_state(fresh[-1]["measured_at"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
