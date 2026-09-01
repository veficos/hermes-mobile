# Building Hermes Mobile for iOS

**English** | [简体中文](ios-build.zh-CN.md)

This guide describes how to build, run, sign, archive, and export the current Hermes Mobile iOS project.

## Current iOS Configuration

| Setting | Current value |
| --- | --- |
| Minimum iOS version | iOS 13.0 |
| Devices | iPhone and iPad |
| Default bundle identifier | `com.hermes.mobile` |
| App display name | Hermes Mobile |
| Version source | `version` in `pubspec.yaml` |
| Signing style | Automatic by default |
| Xcode workspace | `ios/Runner.xcworkspace` |
| Native plugin integration | Flutter-generated Swift Package Manager package |
| Push environment | Development for Debug, production for Release |

The project declares microphone, local-network, and remote-notification capabilities. Release signing must therefore use an App ID and provisioning profile that support Push Notifications.

## Requirements

iOS builds must run on macOS. Install:

- A recent stable Xcode version supported by your Flutter SDK
- Xcode Command Line Tools
- Flutter 3.47.1 and Dart 3.13.1, matching the validated project environment
- No Apple account is required for simulator or unsigned builds; local device signing needs an Apple ID, while TestFlight, App Store, and push distribution require Apple Developer Program membership
- CocoaPods only if `flutter doctor` or a plugin integration explicitly requires it

Select Xcode and complete its first-run setup:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo xcodebuild -license accept
```

Verify the environment:

```bash
flutter doctor -v
xcodebuild -version
flutter devices
```

Resolve every error reported under the Xcode/iOS section of `flutter doctor` before continuing.

## Prepare the Project

Run these commands from the repository root:

```bash
flutter clean
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
```

`flutter clean` is optional for a normal incremental build, but useful after changing Flutter, Xcode, plugins, or native project settings.

The current project uses Flutter's generated local Swift Package Manager package for native plugins and does not commit a `Podfile`. Let `flutter pub get` generate this integration. Do not add or run CocoaPods commands unless the installed Flutter version or a dependency specifically requests them.

## Run in the iOS Simulator

Start Simulator and list available devices:

```bash
open -a Simulator
flutter devices
```

Run the app using the simulator identifier shown by `flutter devices`:

```bash
flutter run -d <simulator-device-id>
```

To compile a simulator app without launching it:

```bash
flutter build ios --simulator --debug
```

Simulator output is written under `build/ios/iphonesimulator/`. The simulator does not provide a real APNs device token; validate push notifications on physical hardware.

## Configure Apple Signing

Open the generated workspace, not only the `.xcodeproj` file:

```bash
open ios/Runner.xcworkspace
```

In Xcode:

1. Select the **Runner** project and the **Runner** target.
2. Open **Signing & Capabilities**.
3. Select your Apple Developer team.
4. Keep **Automatically manage signing** enabled for local development.
5. Replace `com.hermes.mobile` with a bundle identifier registered to your team if the default identifier is unavailable.
6. Confirm that the **Push Notifications** capability is enabled for release builds.
7. Confirm that **Background Modes > Remote notifications** is enabled if Xcode does not infer it from the project.

The chosen bundle identifier must also match `HERMES_MOBILE_APNS_BUNDLE_ID` on the Mobile Server. A mismatch allows the app to compile but causes APNs delivery to fail.

Do not commit personal development-team IDs, certificates, private keys, or provisioning profiles. The ignored `ios/Flutter/Signing.xcconfig` file can be used for machine-local signing configuration.

## Run on a Physical Device

Connect and unlock the iPhone or iPad, trust the Mac, enable Developer Mode when prompted, and verify that Flutter sees the device:

```bash
flutter devices
flutter run -d <physical-device-id>
```

For first-time signing failures, open `ios/Runner.xcworkspace`, select the physical device, and run once from Xcode so it can create or download the development provisioning profile.

Hermes Mobile connects to a separate Mobile Server. On a physical device, `127.0.0.1` points to the device itself. Start the Server on the Mac or another LAN machine:

```bash
cd server
HERMES_DASHBOARD_PUBLIC_URL= uv run hermes-mobile-server \
  --host 0.0.0.0 \
  --port 9001
```

In the app, use `http://<server-lan-ip>:9001` and the Server API key. Accept the iOS local-network permission prompt and allow port `9001` through the host firewall.

## Compile Without Code Signing

For a CI compile check or to validate native compilation before configuring an Apple account:

```bash
flutter build ios --release --no-codesign
```

This produces an unsigned `.app` under `build/ios/iphoneos/`. It cannot be installed on a normal physical device or uploaded to App Store Connect.

## Build a Signed Release

Set an explicit public version and monotonically increasing build number:

```bash
flutter build ios --release \
  --build-name 1.0.0 \
  --build-number 1
```

Flutter uses `--build-name` as `CFBundleShortVersionString` and `--build-number` as `CFBundleVersion`. App Store Connect rejects a build number that was already uploaded for the same version.

## Create an IPA

### Automatic signing

With a valid team selected in Xcode, run:

```bash
flutter build ipa --release \
  --build-name 1.0.0 \
  --build-number 1
```

The archive is created under `build/ios/archive/` and exported IPA files under `build/ios/ipa/`.

### Xcode Organizer

For an interactive App Store release:

1. Open `ios/Runner.xcworkspace`.
2. Select **Any iOS Device (arm64)** as the destination.
3. Choose **Product > Archive**.
4. In Organizer, select the archive and click **Distribute App**.
5. Choose **App Store Connect**, then validate and upload the build.

### Manual export template

The repository includes `ios/ExportOptions.plist` for manual App Store Connect export. It is a template and is not usable unchanged. Replace:

- `HERMES_TEAM_ID` with the Apple Developer Team ID
- `HERMES_PROFILE_NAME` with the installed App Store provisioning profile name for the selected bundle ID

Then run:

```bash
flutter build ipa --release \
  --build-name 1.0.0 \
  --build-number 1 \
  --export-options-plist=ios/ExportOptions.plist
```

Prefer generating a machine-local copy of the export options instead of committing account-specific values.

## APNs Configuration

The iOS target already contains the `aps-environment` entitlement:

- Debug builds resolve it to `development`.
- Release builds resolve it to `production`.

For push delivery, configure all of the following on the Mobile Server:

```bash
export HERMES_MOBILE_APNS_TEAM_ID='<apple-team-id>'
export HERMES_MOBILE_APNS_KEY_ID='<apns-key-id>'
export HERMES_MOBILE_APNS_BUNDLE_ID='<signed-app-bundle-id>'
export HERMES_MOBILE_APNS_PRIVATE_KEY_FILE='/secure/path/AuthKey_XXXXXXXXXX.p8'
```

For a development-signed Debug build, also set:

```bash
export HERMES_MOBILE_APNS_SANDBOX=true
```

Use the production APNs endpoint for TestFlight and App Store builds. Never add the `.p8` private key to this repository.

## Pre-release Checklist

- `flutter analyze` and `flutter test` pass.
- The version and build number are correct and the build number has not been uploaded before.
- The distribution certificate and provisioning profile are valid.
- The signed bundle identifier matches the App Store Connect record and Server APNs configuration.
- Push Notifications and remote-notification background mode are enabled.
- Microphone and local-network permission descriptions are appropriate for the release locale.
- The app icon contains no alpha channel and all required sizes are present.
- The app connects to a TLS-protected production Mobile Server; do not expose an unprotected `9001` endpoint publicly.
- The archive passes Xcode Organizer validation before upload.

## Troubleshooting

### No iOS device appears

Run `flutter doctor -v`, open Xcode once, install any requested platform components, and confirm the device is trusted and in Developer Mode. Restart both Xcode and the device if pairing remains unavailable.

### Signing requires a development team

Open `ios/Runner.xcworkspace`, select **Runner > Signing & Capabilities**, and choose a team. If the bundle identifier belongs to another account, change it to an identifier registered to your team.

### A provisioning profile does not include `aps-environment`

Enable Push Notifications for the App ID in the Apple Developer portal, then regenerate or refresh the provisioning profile. Free Personal Team profiles may not support the required push capability.

### A plugin or generated native file is missing

From the repository root, run:

```bash
flutter clean
flutter pub get
flutter gen-l10n
```

Then reopen `ios/Runner.xcworkspace`. Generated files under `ios/Flutter/` and `Runner/GeneratedPluginRegistrant.*` are intentionally ignored and should not be edited manually.

### The device cannot connect to the Mobile Server

Use the Server machine's LAN address instead of `127.0.0.1`, bind the Server to `0.0.0.0`, accept the local-network permission, and check the host firewall. For public deployment, use HTTPS/WSS through a properly configured reverse proxy.

### APNs registration succeeds but messages do not arrive

Check that the APNs key, Team ID, Key ID, bundle ID, and sandbox setting all refer to the same Apple Developer configuration. Debug builds use the sandbox; TestFlight and App Store builds use production.
