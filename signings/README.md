# Active release signing identity

`qofeno-release.keystore` is the active PKCS12 release key (RSA-3072, alias `qofeno`). Configure its random password as the encrypted `QOFENO_KEYSTORE_PASSWORD` Actions secret; keep the password outside this repository. The private backup contains the key and password; keep it private.

`release-certificate.json` records the public certificate fingerprint and encrypted keystore checksum. The build verifies that the APK certificate matches the selected keystore.

The previous `../signing/qofeno-release.keystore` remains untouched. New-key APKs cannot update old-key installations in place.
