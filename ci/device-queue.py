"""Exercise two FIFO payments via Android touch. Seed only the starting shop state."""
import json
from pathlib import Path
import subprocess
import sys
import time

adb, package, slot = sys.argv[1:]
out = Path("build/device")


def shell(*args, **kwargs):
    return subprocess.run([adb, "shell", *args], check=True, timeout=45, **kwargs)


def screen(label, filename, tap=False):
    args = [sys.executable, "ci/device-screen.py", label, str(out / filename)]
    subprocess.run(args + (["tap"] if tap else []), check=True, timeout=230)


def launch():
    shell("am", "start", "-W", "-a", "android.intent.action.MAIN", "-c",
          "android.intent.category.LAUNCHER", "-p", package)


shell("am", "force-stop", package)
shift = json.loads((out / "background-save.json").read_bytes())
shift.update(cash=51, spend=20, revenue=8, receipt=1, xp=36, queue_lane=True,
             open=True, pos=[4.15, 0.08, -1.15], yaw=0.6,
             flags=dict.fromkeys(("visit", "terminal", "order", "collect", "stock", "open", "sale"), True),
             log=[{"n": 1, "id": "tea", "paid": 8}])
shift["goods"]["tea"].update(back=0, shelf=4, sold=1, price=8)
shell("run-as", package, "tee", slot, input=json.dumps(shift).encode(), stdout=subprocess.DEVNULL)
launch()
screen("Continue", "queue-continue.png", True)
screen("full-line", "queue-floor.png", True)
screen("payment", "queue-first-basket.png", True)
screen("ready-line", "queue-advance.png", True)
screen("payment", "queue-second-basket.png", True)
screen("Pause", "queue-after-sales.png")
shell("input", "keyevent", "KEYCODE_HOME")
# Wait for Android's background notification and the atomic snapshot.
for _ in range(20):
    raw = subprocess.check_output([adb, "exec-out", "run-as", package, "cat", slot], timeout=10)
    paid = json.loads(raw)
    if paid["receipt"] == 3:
        break
    time.sleep(0.5)
assert (paid["cash"], paid["revenue"], paid["receipt"]) == (67, 24, 3), paid
assert (paid["goods"]["tea"]["shelf"], paid["goods"]["tea"]["sold"]) == (2, 3), paid
assert [row["n"] for row in paid["log"]] == [3, 2, 1], paid
(out / "queue-paid-save.json").write_bytes(raw)
print("Android till recorded two touch payments, $67 cash and two remaining tea units.")
