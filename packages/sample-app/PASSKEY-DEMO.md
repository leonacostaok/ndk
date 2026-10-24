# Passkey Lab

A small browser consumer of `ndk` and `ndk_flutter`, using the local packages in this branch. It runs separately from the sample application's wallet, cache and relay initialization.

```sh
cd packages/sample-app
flutter pub get
flutter run -d web-server --web-hostname localhost --web-port 8767 --target lib/passkey_demo.dart
```

Open `http://localhost:8767` in a browser with a PRF-capable passkey provider. Create a test account, sign a test event, close the session, and reopen the passkey. Reload the page and reopen again: the recovered public key must match the saved public metadata. The event is verified locally and never published.

Parameter 01 follows the proposed default derivation; parameter 02 uses LaWallet's derivation. Selecting 02 does not grant access to a LaWallet-domain passkey. This demo does not implement stored-key or vault recovery, native app associations, or cross-origin access. The underlying proposal is still a draft.

Use test accounts. Only public metadata is saved; signing keys remain in memory. Closing the session does not delete the passkey from your provider. For phone/cross-device testing, serve the build on one stable HTTPS domain authorized for the RP. A phone's localhost is a different machine; exposing this development server on an HTTP LAN address is not a replacement for HTTPS.
