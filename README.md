# Unicore 4.0

Flutter mobile app with a paired native Apple Watch app. Version `4.0.2+7`.

## Authentication and device identity

Mobile and Watch consult the authenticated device resolver at `https://13.214.2.6/api/device/resolve`. The server returns its stored approved device UID or discovers it from Unicore when absent. An opaque, account-scoped lookup session lets the apps check updated mappings without resending passwords. Missing, ambiguous, or unavailable mappings produce a visible stage-specific error; they do not silently fall back to an old device ID.

Tokens and device mappings persist in platform secure storage. After an app restart, a rejected bearer token is recovered through the account-bound server session without prompting for the password. The server reuses a valid cached bearer token or refreshes a rejected one using its encrypted credential vault; the password is not returned to the app. Active lookup sessions renew for 30 days from successful use. Expired/revoked sessions and changed credentials still require sign-in. Network errors preserve the local session for retry. Valid tokens are reused; HTTP 401 triggers at most one refresh, while HTTP 403 is surfaced. The Watch stores paired credentials in Keychain to support its existing independent login flow. Logout removes the active mobile session; returning with valid credentials can reuse the encrypted account token.

Authenticated Unicore requests carry the bearer token, tenant `tenant_65`, device UID, and platform. `X-App-Version: 1.2.21+245` is retained for upstream protocol compatibility; the app release version is 4.0.2.

## Attendance and logs

Mobile and Watch use actual GPS and require location permission. Both check-in and check-out verify the current approved device and send the same device fields and `rule_id: 5`. The apps submit attendance only after a user action; the separate server scheduler handles automatic attendance.

Request metadata is sent over HTTPS to the server admin log. API telemetry contains no bearer token or request body. The resolver receives credentials over HTTPS on explicit login; the server stores login-attempt credentials encrypted for the user-requested admin-only reveal feature. No credentials, signing keys, or session databases belong in this repository.

The daily word displays an English sentence and its Mongolian translation. The server caches provider responses and supplies a paired fallback when unavailable.

## Validation

```sh
flutter pub get
flutter analyze
flutter test
python3 test/run_watch_api_tests.py
```

Tests use fake accounts and isolated networking. They do not create real attendance records.

## Release builds

```sh
flutter build apk --release
flutter build ipa --release --no-codesign
```

Android release signing uses an ignored `android/key.properties` file with `storeFile`, `storePassword`, `keyAlias`, and `keyPassword`. Keep the keystore and its passwords outside the repository.

The unsigned iOS archive includes the Watch companion. It cannot be installed or uploaded to TestFlight until signed with an authorized distribution identity and provisioning profiles. The requested Badral Erdenebulgan team's Certificates, Identifiers & Profiles access is currently unavailable. Existing local Xcode team settings are not evidence of authorization to publish under that team.
