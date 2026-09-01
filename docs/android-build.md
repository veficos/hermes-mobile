# Building Hermes Mobile for Android

**English** | [简体中文](android-build.zh-CN.md)

This guide describes how to configure, run, sign, and build the current Hermes Mobile Android project as an APK or Android App Bundle.

## Current Android Configuration

| Setting | Current value |
| --- | --- |
| Application ID / namespace | `com.hermes.mobile` |
| Minimum Android version | Android 7.0, API 24 |
| Compile SDK / Target SDK | API 36 |
| NDK | `28.2.13676358` |
| Java and Kotlin bytecode target | JVM 17 |
| Android Gradle Plugin | 9.0.1 |
| Gradle Wrapper | 9.1.0 |
| Kotlin plugin | 2.3.20 |
| Version source | `version` in `pubspec.yaml` |
| Release signing | Required through `android/key.properties` |

The SDK and NDK values are inherited from the validated Flutter 3.47.1 toolchain. If the project later upgrades Flutter, verify the effective values again before provisioning a build machine.

## Requirements

Android builds can run on Linux, macOS, or Windows. Install:

- Flutter 3.47.1 and Dart 3.13.1, matching the validated project environment
- Android Studio with Android SDK Platform 36 and the Android SDK Command-line Tools
- Android NDK `28.2.13676358`
- A JDK supported by AGP 9; use Android Studio's bundled JDK or JDK 17 or newer
- An Android emulator or a physical device for runtime testing

Check the environment and accept Android SDK licenses:

```bash
flutter doctor -v
flutter doctor --android-licenses
flutter devices
java -version
```

Resolve every error under the Android toolchain section of `flutter doctor` before continuing. `android/local.properties` is generated locally and must point to valid Flutter and Android SDK installations; it is intentionally ignored by version control.

## Prepare the Project

Run from the repository root:

```bash
flutter clean
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
```

`flutter clean` is optional for normal incremental builds. Use it after changing Flutter, Gradle, Android plugins, native resources, or signing configuration when stale output causes failures.

## Run a Debug Build

### Android emulator

Start an emulator in Android Studio's Device Manager, or list and launch one from Flutter:

```bash
flutter emulators
flutter emulators --launch <emulator-id>
flutter devices
flutter run -d <android-device-id>
```

The Android emulator reaches a Server running on the development computer through `10.0.2.2`. For the default ports, enter `http://10.0.2.2:9001` in Hermes Mobile.

### Physical device

Enable Developer options and USB debugging, connect and authorize the device, then run:

```bash
adb devices
flutter devices
flutter run -d <android-device-id>
```

On a physical device, `127.0.0.1` points to the device itself. Use the Mobile Server machine's LAN address, bind the Server to `0.0.0.0`, and allow port `9001` through the host firewall.

### Build a debug APK

```bash
flutter build apk --debug
```

The output is:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

Install or update it with:

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

## Network Security Behavior

Debug and profile manifests allow cleartext HTTP for local development. The release manifest is intentionally stricter:

- Cleartext HTTP is denied by default.
- `localhost`, `127.0.0.1`, `10.0.2.2`, and `.local` hostnames are explicitly allowed.
- An arbitrary LAN IP such as `192.168.x.x` is not allowed over HTTP in a Release build.

Use HTTPS/WSS with a valid certificate for production Mobile Server access. Do not weaken `android/app/src/main/res/xml/network_security_config.xml` to expose an unencrypted public endpoint.

## Configure Release Signing

Every Release task fails intentionally until `android/key.properties` exists. Use a long-lived upload key and keep it backed up securely. Losing the key can prevent future updates outside Play App Signing recovery flows.

### 1. Generate an upload keystore

Use an explicit secure path outside the repository:

```bash
keytool -genkeypair -v \
  -keystore /Users/your-name/Keys/hermes-mobile-upload.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias hermes-mobile
```

On Linux or Windows, replace the example path with an absolute path appropriate for that machine.

### 2. Create the signing configuration

Copy the committed template:

```bash
cp android/key.properties.example android/key.properties
```

Edit `android/key.properties`:

```properties
storeFile=/Users/your-name/Keys/hermes-mobile-upload.jks
storePassword=your-keystore-password
keyAlias=hermes-mobile
keyPassword=your-key-password
```

`storeFile` should be an absolute path. Both `android/key.properties` and `*.jks` are ignored by the repository, but verify they are never committed. Restrict local file access:

```bash
chmod 600 android/key.properties
chmod 600 /Users/your-name/Keys/hermes-mobile-upload.jks
```

Store the keystore and passwords in an encrypted backup or CI secret manager. Do not encode the keystore directly into a tracked file.

## Version the Release

The default version comes from `pubspec.yaml`:

```yaml
version: 1.0.0+1
```

The part before `+` becomes Android `versionName`; the integer after `+` becomes `versionCode`. Google Play requires every uploaded `versionCode` to be greater than all previous uploads.

Override both values for a build without editing `pubspec.yaml`:

```bash
flutter build appbundle --release \
  --build-name 1.0.0 \
  --build-number 1
```

## Build Release Artifacts

### Universal APK

```bash
flutter build apk --release \
  --build-name 1.0.0 \
  --build-number 1
```

Output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

### Split APKs by ABI

For smaller direct-download packages:

```bash
flutter build apk --release --split-per-abi \
  --build-name 1.0.0 \
  --build-number 1
```

Flutter normally generates separate APKs for `armeabi-v7a`, `arm64-v8a`, and `x86_64`. Install the APK matching the device architecture.

### Android App Bundle

Google Play distribution should normally use an AAB:

```bash
flutter build appbundle --release \
  --build-name 1.0.0 \
  --build-number 1
```

Output:

```text
build/app/outputs/bundle/release/app-release.aab
```

Upload the AAB to an internal testing track before production. With Play App Signing, the local key is normally the upload key and Google manages the final app-signing key.

## Configure Firebase Cloud Messaging

The Android client initializes Firebase from Gradle properties or environment variables. It does not require a committed `google-services.json`. Supply all four public Firebase app values when push notifications are needed:

```bash
export HERMES_FCM_APP_ID='<firebase-android-app-id>'
export HERMES_FCM_API_KEY='<firebase-web-api-key>'
export HERMES_FCM_PROJECT_ID='<firebase-project-id>'
export HERMES_FCM_SENDER_ID='<firebase-sender-id>'
```

Then build or run in the same shell:

```bash
flutter run -d <android-device-id>
flutter build appbundle --release
```

If any value is absent, the app still builds, but Android push registration is disabled and no FCM token is returned.

The Mobile Server also needs a Firebase service account with Firebase Messaging permission:

```bash
export HERMES_MOBILE_FCM_SERVICE_ACCOUNT_FILE='/secure/path/firebase-service-account.json'
```

The service-account JSON is a private credential. Keep it on the Server only and never include it in the app or repository.

Android 13 and newer require runtime notification permission. The manifest already declares `POST_NOTIFICATIONS`; grant the prompt during device testing.

## Verify the Artifacts

Inspect a signed APK with Android SDK Build Tools:

```bash
apksigner verify --verbose --print-certs \
  build/app/outputs/flutter-apk/app-release.apk
```

Inspect the AAB signature:

```bash
jarsigner -verify -verbose -certs \
  build/app/outputs/bundle/release/app-release.aab
```

You can also run the Android lint task after signing is configured:

```bash
cd android
./gradlew lintRelease
```

## Pre-release Checklist

- `flutter analyze` and `flutter test` pass.
- The application ID matches the Google Play application record.
- `versionCode` is greater than every previously uploaded build.
- The upload keystore, alias, and passwords are backed up and available to CI.
- The Release APK or AAB signature has been verified.
- FCM app values are present when push notifications are required.
- The Mobile Server has the correct Firebase service account.
- Notification, microphone, and local-network workflows have been tested on a physical device.
- Release Server URLs use HTTPS/WSS; arbitrary cleartext LAN IPs are blocked by design.
- The AAB has passed Google Play internal-track testing before wider rollout.

## Troubleshooting

### Android SDK or licenses are missing

Install Platform 36, Command-line Tools, and NDK `28.2.13676358` through Android Studio's SDK Manager. Then run `flutter doctor --android-licenses` and `flutter doctor -v` again.

### Gradle uses the wrong JDK

Use Android Studio's bundled JDK or set Flutter to a compatible JDK installation:

```bash
flutter config --jdk-dir /absolute/path/to/jdk
flutter doctor -v
```

The project compiles Java and Kotlin source for JVM 17. Remove stale Gradle daemons after changing JDKs:

```bash
cd android
./gradlew --stop
```

### Release signing is not configured

If Gradle reports `Release signing is not configured`, create `android/key.properties` from the provided example and verify that `storeFile` is an absolute path to an existing keystore.

### Keystore was tampered with or the password is incorrect

Confirm the alias and credentials without exposing them in logs:

```bash
keytool -list -keystore /Users/your-name/Keys/hermes-mobile-upload.jks
```

Do not generate a replacement key for an existing non-Play distribution unless update-key rotation is supported; users cannot install an update signed by an unrelated key.

### Dependency or Gradle cache errors

Start with the least destructive reset:

```bash
flutter clean
flutter pub get
cd android
./gradlew clean
```

Do not delete shared Gradle caches unless the error proves they are corrupted, because dependencies will need to be downloaded again.

### The emulator cannot connect to the Mobile Server

Use `http://10.0.2.2:9001`, not `127.0.0.1`. Confirm that the Server is running and that `http://127.0.0.1:9001/api/v1/health` works on the host.

### A physical device cannot connect to the Mobile Server

For Debug builds, use the Server machine's LAN IP, bind the Server to `0.0.0.0`, and check the firewall. For Release builds, use HTTPS/WSS or a permitted `.local` hostname because arbitrary cleartext IP traffic is intentionally blocked.

### FCM returns no token

Confirm all four `HERMES_FCM_*` values were supplied to the same shell that launched the build. Reinstall the app after changing embedded Firebase configuration, ensure Google Play services are available, and grant notification permission on Android 13 or newer.
