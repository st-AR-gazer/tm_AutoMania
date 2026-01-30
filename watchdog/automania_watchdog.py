from __future__ import annotations
import json
import time
import subprocess
from pathlib import Path
from collections import deque

try:
    import psutil
except ImportError:
    raise SystemExit("Missing dependency: psutil. Install with: pip install psutil")


# --- CONFIG ---

TRACKMANIA_EXE = r"C:\Program Files (x86)\Ubisoft\Ubisoft Game Launcher\games\Trackmania\Trackmania.exe"
TRACKMANIA_ARGS: list[str] = []
PROCESS_NAMES = {"Trackmania.exe", "Trackmania"}

USERGAME_FOLDER = Path.home() / "Documents" / "Trackmania2020"
AUTOMANIA_DIR = USERGAME_FOLDER / "AutoMania"

STATUS_FILE = AUTOMANIA_DIR / "status" / "flow.status.json"
AUTORUN_FILE = AUTOMANIA_DIR / "status" / "autorun.json"

PREFLIGHT_FLOW_NAME = "Preflight_ToMapEditor"

POLL_INTERVAL_SEC = 1.0

MAX_RESTARTS_PER_10MIN = 1000
RESTART_WINDOW_SEC = 1 * 20

LAUNCH_GRACE_SEC = 45


# --- helpers ---

def is_trackmania_running() -> bool:
    for p in psutil.process_iter(attrs=["name"]):
        try:
            name = (p.info.get("name") or "").strip()
            if name in PROCESS_NAMES:
                return True
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue
    return False


def read_status() -> dict | None:
    try:
        if not STATUS_FILE.exists():
            return None
        return json.loads(STATUS_FILE.read_text(encoding="utf-8"))
    except Exception:
        return None


def flow_active(status: dict | None) -> bool:
    if not status:
        return False
    run = status.get("run") or {}
    st = str(run.get("status") or "").lower().strip()
    return st in {"running", "paused"}


def build_autorun_from_status(status: dict) -> dict | None:
    run = status.get("run") or {}
    flow_name = run.get("flowName")
    params = run.get("params") or {}

    if not flow_name:
        return None

    req = {
        "schema": 1,
        "reason": "watchdog.recover",
        "createdAtEpoch": time.time(),
        "preflightFlow": PREFLIGHT_FLOW_NAME,
        "preflightParams": {},
        "flow": flow_name,
        "params": params,
    }
    return req


def write_autorun(req: dict) -> None:
    AUTORUN_FILE.parent.mkdir(parents=True, exist_ok=True)
    AUTORUN_FILE.write_text(json.dumps(req, indent=2), encoding="utf-8")


def launch_trackmania() -> None:
    exe = Path(TRACKMANIA_EXE)
    if not exe.exists():
        raise FileNotFoundError(f"TRACKMANIA_EXE not found: {exe}")

    subprocess.Popen([str(exe), *TRACKMANIA_ARGS], cwd=str(exe.parent))


# --- main loop ---

def main() -> None:
    restarts = deque()
    last_seen_running = is_trackmania_running()
    launch_in_progress = False
    launch_started_at = 0.0

    print("AutoMania Watchdog started.")
    print(f"Watching status: {STATUS_FILE}")
    print(f"Autorun path:   {AUTORUN_FILE}")
    print(f"TM exe:         {TRACKMANIA_EXE}")

    while True:
        tm_running = is_trackmania_running()

        if launch_in_progress:
            if tm_running:
                launch_in_progress = False
            else:
                if time.time() - launch_started_at > LAUNCH_GRACE_SEC:
                    print("Launch grace expired; will allow another restart attempt.")
                    launch_in_progress = False

        if tm_running:
            last_seen_running = True

        else:
            status = read_status()
            active = flow_active(status)

            just_exited = last_seen_running

            stale_recover = (not last_seen_running) and active

            if not launch_in_progress and (just_exited or stale_recover) and active:
                now = time.time()

                while restarts and now - restarts[0] > RESTART_WINDOW_SEC:
                    restarts.popleft()
                if len(restarts) >= MAX_RESTARTS_PER_10MIN:
                    print("Too many restarts in 10 minutes; stopping watchdog to avoid a loop.")
                    return

                req = build_autorun_from_status(status or {})
                if req:
                    try:
                        write_autorun(req)
                        print(f"Wrote autorun request for flow: {req['flow']}")
                    except Exception as e:
                        print(f"Failed writing autorun.json: {e}")

                try:
                    print("Trackmania exited while flow active -> restarting...")
                    launch_trackmania()
                    restarts.append(now)
                    launch_in_progress = True
                    launch_started_at = now
                except Exception as e:
                    print(f"Failed to launch Trackmania: {e}")

            last_seen_running = False

        time.sleep(POLL_INTERVAL_SEC)


if __name__ == "__main__":
    main()
