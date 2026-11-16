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
        for mode in ("7","11"):
            try:
                ocr = subprocess.run(["tesseract","stdin","stdout","--psm",mode,"tsv"],
                                     input=stream.getvalue(),capture_output=True,timeout=15,check=True)
            except subprocess.TimeoutExpired:
                continue
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
             log=[{"n": 1, "id": "tea", "paid": 8, "lines": [{"id": "tea", "price": 8}]}])
for goods in shift["goods"].values():
    goods.update(back=0, shelf=0, sold=0)
shift["goods"]["tea"].update(back=0, shelf=4, sold=1, price=8)
shift["goods"]["soap"].update(shelf=1)
shell("run-as", package, "tee", slot, input=json.dumps(shift).encode(), stdout=subprocess.DEVNULL)
launch()
screen("Continue", "queue-continue.png", True)
screen("full-line", "queue-floor.png", True)
screen("Scan", "queue-first-basket.png")
# Use a finger on the first grocery in the native register camera. The second
# grocery uses the fixed Scan button. Both paths must reach the same receipt.
with Image.open(out / "queue-first-basket.png") as counter:
    shell("input","tap",str(round(counter.width*0.333)),str(round(counter.height*0.49)))
screen("Scan", "queue-partial-scan.png", True)
control("Add","queue-cash-change.png",(.829,.645,.902,.728))
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
assert (paid["cash"], paid["revenue"], paid["receipt"]) == (73, 30, 3), paid
assert (paid["goods"]["tea"]["shelf"], paid["goods"]["tea"]["sold"]) == (2, 3), paid
assert paid["goods"]["soap"]["shelf"] == 0 and paid["goods"]["soap"]["sold"] == 1, paid
assert paid["log"][1]["paid"] == 14 and len(paid["log"][1]["lines"]) == 2, paid
assert [row["n"] for row in paid["log"]] == [3, 2, 1], paid
(out / "queue-paid-save.json").write_bytes(raw)
print("Android till recorded two touch payments, $73 cash and two remaining tea units.")

# Separate staged views of the installed APK using the same private QA slot.
# The seed is confined to the emulator. Nothing is added to the shipping game.
for name, pos, yaw, clock in [
        ("waterfront-street", [-0.4,0.08,13.35], 0.68,565.0),
        ("pantry-display", [-4.42,0.08,-5.13], 0.0,565.0),
        ("quay-sunset",[-7.1,0.08,15.9],-0.35,1078.0),
        ("quay-night",[-7.1,0.08,15.9],-0.35,1250.0)]:
    shell("am", "force-stop", package)
    scene = json.loads(raw)
    scene.update(pos=pos, yaw=yaw, open=False, clock=clock)
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
control("desk","desk-interaction.png",(.79,.878,.981,.956))
control("Market","workstation.png",(.028,.195,.15,.266))
control("Add","wholesale.png",(.57,.352,.68,.445))
control("Household","mixed-order.png",(.174,.245,.282,.32))
control("Add","soap-order.png",(.57,.352,.68,.445))
control("Review","supplier-cart.png",(.72,.869,.955,.946))
control("Place","purchase-review.png",(.132,.477,.245,.555))
control("Ledger","supplier-paid.png",(.131,.04,.35,.126),False)
order = background()
assert order["cash"] == 35 and order["goods"]["tea"]["back"]==5 and order["goods"]["soap"]["back"]==6, order
assert order["last_order"] == {"tea":1,"soap":1} and not order["cart"], order

stage([-4.1,0.08,7.1],1180.0)
control("estate","estate-door.png",(.79,.878,.981,.956))
x,y=control("Drive","drive-estate.png",(.885,.835,.979,.918),False)
shell("input","swipe",str(x),str(y),str(x),str(y),"1950")
vehicle=background()
assert vehicle["driving"] and vehicle["van"][0] > -3.4, vehicle
(out/"vehicle-save.json").write_text(json.dumps(vehicle))
shell("am","force-stop",package)
launch()
screen("Continue","drive-relaunch.png",True)
control("out","drive-restored.png",(.86,.681,.98,.766))
control("Run","drive-exited.png",(.904,.781,.976,.845),False)
assert not background()["driving"]

stage([2.17,0.08,0.9],1259.5)
control("sign","evening-sign.png",(.79,.878,.981,.956))
control("Review","closing-time.png",(.64,.442,.96,.521))
control("Start","daily-report.png",(.12,.552,.88,.634))
screen("Pause","next-morning.png")
morning=background()
assert morning["day"]==2 and morning["clock"]==480 and not morning["open"] and morning["cash"]==73, morning
print("Verified mixed-cart delivery, touch driving and reload, and day-end settlement on Android.")
