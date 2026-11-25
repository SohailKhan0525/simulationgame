# Android releases

The `Qofeno Drive Android release` workflow builds a signed APK and publishes it on GitHub Releases. It uses Godot **4.5.1**, JDK **17**, Gradle **8.11.1**, Android SDK **35**, and the official export templates verified against their published SHA-512 values. The app package is `com.qofeno.drive`, supporting ARM64 and x86_64 on Android 8 or later.

## Signing identity

`signing/qofeno-release.keystore` contains the persistent, password-protected signing key. Its alias is `qofeno`. Set repository Actions secret `QOFENO_KEYSTORE_PASSWORD` to its private password. Keep a secure independent backup of both the key and password. Do not commit or print the password. Losing the signing identity prevents updates to installed copies; changing it requires uninstalling the old app. The workflow fails before building when the secret is absent and never substitutes debug signing.

## Version and publication

The checked-in upgrade is **1.1.0**, Android version code **1001000**. With no existing stable release tag, the workflow builds and verifies this version, then creates its first real release with the APK, checksum and update manifest. It never creates an empty baseline tag or lets semantic-release downgrade the app to its default initial version of 1.0.0.

After that first release, push Conventional Commits to `main`: `fix:` bumps patch, `feat:` bumps minor, and a breaking-change marker bumps major. Other conventional commit types also bump patch. Nonconventional commit messages may not trigger a release. A workflow retry without new release-worthy commits does not publish another version.

semantic-release calculates the version, stamps the APK and `game/version.json`, builds the native updater and game, verifies the APK, and only then tags and publishes. The Android version code is `major * 1,000,000 + minor * 1,000 + patch`; minor and patch must stay below 1000. Do not manually reuse version codes.

Each release contains `Qofeno-Drive.apk`, its `.sha256` checksum and `update.json`. Release metadata is generated in CI and is not committed back to `main`. No npm package is published and no PAT is required: the workflow's scoped `GITHUB_TOKEN` publishes the release.

## Local release build

Install the same Godot/Android/JDK/Gradle versions, then:

```sh
npm ci --ignore-scripts
npm run test:release
node tools/release.mjs 1.1.0
# Configure ANDROID_HOME, JAVA_HOME, and the private signing password in your shell.
# GODOT_BIN and GRADLE_BIN can select local executables.
bash tools/build-android.sh
```

The password environment variable is `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`. The script supplies the repository keystore path and `qofeno` alias unless overridden with Godot's documented environment variables. Keep secrets out of shell history. Generated Android source templates, AARs, APKs and SDK/editor caches are not source assets.

## In-game update contract

The game fetches `https://github.com/SohailKhan0525/simulationgame/releases/latest/download/update.json`. The manifest supplies `version`, `version_code`, `package`, `url`, `sha256`, `size` and `min_android`. `QofenoUpdater.start_download(url, sha256, version_code)` accepts only this repository's HTTPS release APK URLs. Android DownloadManager owns background downloads and stores the job ID across process restarts. `get_status()` returns JSON with `state`, `progress`, `bytes`, `total` and `error`.

After downloading, the plugin checks SHA-256, package name, newer version code and equality of signing certificates against the installed app. `install_update()` re-verifies before opening Android's installer. Players approve unknown-source access if needed and approve installation; an ordinary app cannot silently replace itself. Updates do not require clearing saved progress. The download can use mobile data, and Android may pause it because of network or operating-system restrictions.

`speak(text)` uses installed Android text-to-speech voices. Speech availability and voice character depend on the device. There is no microphone or voice upload.

This is a sideload release channel. Google Play distribution should use Play's update flow and a separately reviewed manifest rather than `REQUEST_INSTALL_PACKAGES`.

## Validation boundaries

CI tests version arithmetic and saved progression, imports GDScript, compiles native Android code, validates package metadata, checks ZIP integrity and verifies APK signing. Device performance, steering feel, battery/thermal behavior, TTS availability, download recovery and the full upgrade installation flow require Android-device tests. CI completion alone does not prove those behaviors.

References: [Godot Android export](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_android.html), [Godot v2 Android plugins](https://docs.godotengine.org/en/4.5/tutorials/platform/android/android_plugin.html), [Android signing](https://developer.android.com/studio/publish/app-signing), [DownloadManager](https://developer.android.com/reference/android/app/DownloadManager), [semantic-release](https://semantic-release.org/recipes/ci-configurations/github-actions/).
