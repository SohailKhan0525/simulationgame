# Official Android updates

Updates are voluntary. Main menu or Pause → Updates → Check for updates calls the public latest-stable-release endpoint for SohailKhan0525/simulationgame. Gameplay can run offline. No update traffic is required at startup.

The client parses three numeric version components, rejects draft/prerelease data, checks the exact GitHub release page and asset path, and validates the APK name and positive size. Responses are size-limited and time out after nine seconds. Status covers rate limiting, no stable release, network failure and malformed data. The UI shows plain-text release notes and offers the official release page when a newer matching APK exists.

The GitHub page and Android's package installer handle download, progress, permissions and final confirmation. The client does not download or hash an APK. Releases include a SHA-256 file to check downloaded bytes. The publishing workflow verifies the APK signature and pins the expected signing certificate. GitHub account/repository control and Android's package-signature verification are the trust boundaries. The APK digest published beside it is an integrity check from the same publisher.

Install stable updates over the existing stable app to retain app-private data. Android requires the same application ID and signing identity. The internal package is isolated and uses an ephemeral test signer in hosted CI. Keep an internal build installed to keep its own save. A stable build starts separately.
