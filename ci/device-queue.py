"""Exercise two FIFO payments via Android touch. Seed only the starting shop state."""
import csv
import io
import json
from PIL import Image, ImageOps
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


def control(word, filename, box=(0,0,1,1), tap=True):
    # Read the actual framebuffer. Keep areas relative to the landscape viewport.
    for attempt in range(24):
        data = subprocess.check_output([adb, "exec-out", "screencap", "-p"], timeout=15)
        frame = Image.open(io.BytesIO(data)).convert("RGB")
        w,h = frame.size
        left,top,right,bottom = [int(k*v) for k,v in zip(box,(w,h,w,h))]
        crop = ImageOps.grayscale(frame.crop((left,top,right,bottom)))
        crop = crop.resize((crop.width*2,crop.height*2))
        stream = io.BytesIO()
        crop.save(stream,format="PPM")
        ocr = subprocess.run(["tesseract","stdin","stdout","--psm","11","tsv"],
                             input=stream.getvalue(),capture_output=True,timeout=10,check=True)
        rows = csv.DictReader(io.StringIO(ocr.stdout.decode()),delimiter="\t")
        for row in rows:
            if row["text"].strip(".,·").casefold() != word.casefold(): continue
            point=(left+(int(row["left"])+int(row["width"])//2)//2,
                   top+(int(row["top"])+int(row["height"])//2)//2)
            (out/filename).write_bytes(data)
            if tap: shell("input","tap",*map(str,point))
            print(f"Rendered {word} at {point}",flush=True)
            return point
        (out/filename).write_bytes(data)
        time.sleep(0.7)
    raise AssertionError(f"Could not locate {word} in {filename}")


shell("am", "force-stop", package)
shift = json.loads((out / "background-save.json").read_bytes())
shift.update(cash=51, spend=20, revenue=8, receipt=1, xp=36, queue_lane=True,
             open=True, started=True, pos=[4.15, 0.08, -1.15], yaw=0.6,
             flags=dict.fromkeys(("visit", "terminal", "order", "collect", "stock", "open", "sale"), True),
             log=[{"n": 1, "id": "tea", "paid": 8}])
for goods in shift["goods"].values():
    goods.update(back=0, shelf=0, sold=0)
shift["goods"]["tea"].update(back=0, shelf=4, sold=1, price=8)
shell("run-as", package, "tee", slot, input=json.dumps(shift).encode(), stdout=subprocess.DEVNULL)
launch()
screen("Continue", "queue-continue.png", True)
screen("full-line", "queue-floor.png", True)
screen("Scan", "queue-first-basket.png", True)
control("Add","queue-cash-drawer.png",(.6,.25,.99,.92))
control("Add","queue-cash-change.png",(.6,.25,.99,.92))
screen("payment", "queue-cash-paid.png", True)
screen("ready-line", "queue-advance.png", True)
screen("Scan", "queue-second-basket.png", True)
screen("payment", "queue-card-paid.png", True)
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

# Separate staged views of the installed APK using the same private QA slot.
# The seed is confined to the emulator. Nothing is added to the shipping game.
for name, pos, yaw in [
        ("waterfront-street", [-0.4,0.08,13.35], 0.68),
        ("pantry-display", [-4.42,0.08,-5.13], 0.0)]:
    shell("am", "force-stop", package)
    scene = json.loads(raw)
    scene.update(pos=pos, yaw=yaw, open=False, clock=565.0)
    for key in ("tea","cocoa","soap"):
        scene["goods"][key]["shelf"] = 5
    shell("run-as", package, "tee", slot, input=json.dumps(scene).encode(), stdout=subprocess.DEVNULL)
    launch()
    screen("Continue", name+"-menu.png", True)
    screen("Pause", name+".png")


def stage(pos, clock):
    shell("am","force-stop",package)
    scene = json.loads(raw)
    scene.update(pos=pos, yaw=0.0, open=False, started=True, clock=clock)
    shell("run-as", package,"tee",slot,input=json.dumps(scene).encode(),stdout=subprocess.DEVNULL)
    launch()
    screen("Continue","scenario-continue.png",True)
    screen("Pause","scenario-floor.png")


def background():
    shell("input","keyevent","KEYCODE_HOME")
    time.sleep(1.2)
    return json.loads(subprocess.check_output([adb,"exec-out","run-as",package,"cat",slot],timeout=12))


stage([4.5,0.08,-7.1],575.0)
control("desk","desk-interaction.png",(.77,.83,1,1))
control("Market","workstation.png",(0,0,.31,.62))
control("Add","wholesale.png",(.38,.20,.77,.96))
control("Household","mixed-order.png",(0,.12,.72,.53))
control("Add","soap-order.png",(.38,.20,.77,.96))
control("Review","supplier-cart.png",(.62,.60,1,1))
control("Place","purchase-review.png",(.05,.25,.75,.96))
control("Ledger","supplier-paid.png",(0,0,.52,.18),False)
order = background()
assert order["cash"] == 29 and order["goods"]["tea"]["back"]==5 and order["goods"]["soap"]["back"]==6, order
assert order["last_order"] == {"tea":1,"soap":1} and not order["cart"], order

stage([-4.1,0.08,7.1],1180.0)
control("estate","estate-door.png",(.75,.83,1,1))
x,y=control("Drive","drive-estate.png",(.80,.72,1,1),False)
shell("input","swipe",str(x),str(y),str(x),str(y),"1950")
vehicle=background()
assert vehicle["driving"] and vehicle["van"][0] > -3.4, vehicle
(out/"vehicle-save.json").write_text(json.dumps(vehicle))
shell("am","force-stop",package)
launch()
screen("Continue","drive-relaunch.png",True)
control("out","drive-restored.png",(.79,.59,1,.82))
assert not background()["driving"]

stage([2.17,0.08,0.9],1259.5)
control("sign","evening-sign.png",(.75,.82,1,1))
control("Review","closing-time.png",(.61,.20,.99,.93))
control("Start","daily-report.png",(.07,.26,.91,1))
screen("Pause","next-morning.png")
morning=background()
assert morning["day"]==2 and morning["clock"]==480 and not morning["open"] and morning["cash"]==67, morning
print("Verified mixed-cart delivery, touch driving and reload, and day-end settlement on Android.")
