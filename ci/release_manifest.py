"""Record verified package metadata. Reject release version/signing regressions."""
import hashlib
import json
from pathlib import Path
import re
import sys
import urllib.error
import urllib.request

mode = sys.argv[1]
root = Path("build")
apk, = root.glob("*-internal.apk" if mode == "debug" else "Qofeno-Simulation-[0-9]*.apk")
badging = (root / "package.txt").read_text()
package, code, version = re.search(r"package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'", badging).groups()
cert = re.search(r"Signer #1 certificate SHA-256 digest: ([0-9a-fA-F]{64})", (root / "signature.txt").read_text()).group(1).lower()
repo = "SohailKhan0525/simulationgame"
tag = f"v{version}"
with apk.open("rb") as stream:
    checksum = hashlib.file_digest(stream, "sha256").hexdigest()
manifest = {"version": version, "versionCode": int(code), "package": package,
            "channel": "stable" if mode == "release" else "internal", "apk": apk.name,
            "minSdk": int(re.search(r"sdkVersion:'(\d+)'", badging).group(1)),
            "targetSdk": int(re.search(r"targetSdkVersion:'(\d+)'", badging).group(1)),
            "size": apk.stat().st_size, "sha256": checksum, "signerSha256": cert,
            "commit": (root / "commit.txt").read_text().strip()}
if mode == "release":
    page = f"https://github.com/{repo}/releases"
    manifest.update(notes=f"{page}/tag/{tag}", download=f"{page}/download/{tag}/{apk.name}")
    try:
        with urllib.request.urlopen(f"https://api.github.com/repos/{repo}/releases/latest", timeout=15) as response:
            prior = json.load(response)
    except urllib.error.HTTPError as exc:
        if exc.code != 404:
            raise
    else:
        previous_tag = prior.get("tag_name", "")
        if not re.fullmatch(r"v\d+\.\d+\.\d+", previous_tag):
            sys.exit("Unexpected previous stable release tag")
        with urllib.request.urlopen(f"{page}/download/{previous_tag}/manifest.json", timeout=15) as response:
            previous = json.load(response)
        old_version = tuple(map(int, previous_tag[1:].split(".")))
        new_version = tuple(map(int, version.split(".")))
        if new_version <= old_version or manifest["versionCode"] <= previous["versionCode"] or cert != previous["signerSha256"]:
            sys.exit("Stable APK requires increasing versionCode and the original signer")
(root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
