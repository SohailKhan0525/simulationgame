# Android builds and distribution

The `Android` workflow uses Ubuntu 24.04, JDK 17 on the runner, the official Godot 4.6.3 standard editor and matching native Android templates. The editor and template downloads are verified against pinned SHA-256 digests. SDK build-tools 35.0.1 inspect and verify the exported APK. The prebuilt native template determines the final manifest SDK levels. `build/package.txt` records the actual minimum, target and ABIs.

| Trigger | Result |
|---|---|
| Push to main, pull request or manual Actions run | Validate, export an internal APK, install it on an Android 15 emulator and retain the APK and evidence for 14 days. |
| Explicit push to a release/internal-* branch | After device checks, also publish a GitHub prerelease tagged with the source SHA prefix. |
| Push a vMAJOR.MINOR.PATCH tag | Check the tag against project/export versions, export using the persistent key, validate package and signer, smoke-test, and publish a stable GitHub Release. |

The internal application ID is `com.qofeno.simulation.internal`. Production uses `com.qofeno.simulation`. Both are landscape native Godot applications. The checkout-lane build uses version 0.2.0 and Android versionCode 2. The earlier 0.1.0 playtest used code 1. Update `project.godot` and `export_presets.cfg` together and increment versionCode for every future stable package.

## Signing setup

Stable publication uses repository Actions secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and repository variable `ANDROID_RELEASE_CERT_SHA256` (64 hex characters, lowercase, no colons). Use one backed-up private keystore with the same key and store password. The tagged job decodes it into the ephemeral runner temp directory, checks the expected certificate and removes the temporary keystore. Debug CI keys are disposable. No production signing secret is stored in source.

## Phone and build diagnostics

The public test download is under Releases → the internal Harbor Market prerelease → Assets. The Actions artifact named Qofeno-Android contains a ZIP with the APK, digest, package manifest, certificate report, and source commit. The Android-device artifact contains emulator evidence. GitHub may require sign-in for Actions artifacts. Use the public release asset for a direct phone download.

When validation fails, inspect the first Godot script/resource error. For Android packaging, check the engine/template versions, the Android tools step, the signer and the metadata report. The emulator step preserves its most recent screenshots and logs in a diagnostics artifact on failure. The debug package must never be published as a stable update.
