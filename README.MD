# Hermes Mobile

**English** | [简体中文](README.zh-CN.MD)

Hermes Mobile is a cross-platform Flutter client for [Hermes Agent](https://github.com/NousResearch/hermes-agent). It uses a standalone Mobile Server to expose local Hermes Agent capabilities over HTTP and WebSocket to Web, Android, iOS, and Windows clients.

> This project is under active development. Some advanced features require a correctly installed and configured Hermes Agent, external services, or platform-specific permissions.

## Features

- Streaming chat, session management, and profile switching
- Skills, tools, plugins, and MCP management
- File browser, terminal, Git, and project management
- Kanban, cron jobs, subagents, and task automation
- Memory, knowledge, and Starmap
- Credentials, billing, messaging, and webhooks
- Voice, system notifications, Pet, artifacts, and insights
- English, Simplified Chinese, Traditional Chinese, Japanese, and Arabic localization
- Runtime theme configuration and responsive layouts

## Architecture

```text
Flutter App (Web / Android / iOS / Windows)
                 |
          HTTP + WebSocket
                 |
        Mobile Server (FastAPI)
                 |
          hermes serve / Agent
                 |
   Local files, terminal, and external services
```

- The Flutter client uses Provider/Store patterns for UI and application state.
- `server/` provides the FastAPI service and manages the local `hermes serve` process.
- REST endpoints are exposed under `/api/v1/*`.
- Real-time events and streaming responses use `/api/v1/ws`.
- Every Mobile Server endpoint except the health check requires an API key.

## Requirements

The following versions match the environment currently used to validate the project:

- Flutter 3.47.1
- Dart 3.13.1 (`pubspec.yaml` requires `^3.12.2` or later)
- Python 3.11+
- [uv](https://docs.astral.sh/uv/) for Server dependency management
- A working Hermes Agent installation

Target platforms also require their native toolchains:

- Android: Android Studio, Android SDK, and an emulator or physical device
- iOS: macOS and Xcode; CocoaPods only when required by the Flutter/plugin toolchain
- Windows: Visual Studio with the **Desktop development with C++** workload
- Web: Chrome or another modern browser

## Quick Start

The commands below use port `9000` for the Web client and port `9001` for the Mobile Server.

### 1. Start the Mobile Server

From the project root:

```bash
cd server
uv sync
HERMES_DASHBOARD_PUBLIC_URL= uv run hermes-mobile-server \
  --host 0.0.0.0 \
  --port 9001
```

If the installed Hermes Agent version does not support Dashboard authentication, explicitly setting `HERMES_DASHBOARD_PUBLIC_URL` to an empty value is required. Otherwise, the public URL automatically injected by the Mobile Server may cause the Hermes backend to reject startup.

When `HERMES_MOBILE_API_KEY` is not set, the Server generates an API key on first startup and stores it in:

```text
~/.hermes-mobile-server/config.json
```

Print the current API key from another terminal:

```bash
cd server
uv run hermes-mobile-server --print-api-key
```

Never commit the API key or expose it in logs, screenshots, or public deployment configuration.

### 2. Start the Web Client

Open another terminal and run these commands from the project root:

```bash
flutter pub get
flutter gen-l10n
flutter run -d web-server \
  --web-hostname 0.0.0.0 \
  --web-port 9000
```

Open the client at:

```text
http://127.0.0.1:9000
```

Enter the following values on the connection screen:

- Server URL: `http://127.0.0.1:9001`
- API key: the value returned by `--print-api-key`

When the client runs on another computer or a physical mobile device, replace `127.0.0.1` with the LAN address of the Server machine and allow inbound traffic to port `9001`. An Android emulator normally reaches the host machine through `10.0.2.2`.

## Server Configuration

Common environment variables:

| Variable | Purpose |
| --- | --- |
| `HERMES_MOBILE_API_KEY` | Sets the Mobile Server API key. A key is generated and persisted when this is unset. |
| `HERMES_DASHBOARD_PUBLIC_URL` | Sets the Hermes Dashboard public URL. Use an empty value to disable automatic injection by the Mobile Server. |

For production or LAN deployments:

- Use a strong random API key supplied through environment configuration or a secret manager.
- `--host 0.0.0.0` listens on every network interface. Use `127.0.0.1` for local-only access.
- Do not expose port `9001` directly to the public internet without TLS and additional access controls.
- A WebSocket reverse proxy must forward the `Upgrade` and `Connection` headers correctly.

See [server/README.md](server/README.md) for Server setup, [server/API.md](server/API.md) for the API contract, and [server/DESIGN.md](server/DESIGN.md) for implementation design.

## Run and Build

### Web

```bash
flutter run -d chrome
flutter build web
```

The Web release is generated in `build/web/`.

### Android

```bash
flutter run -d android
flutter build apk --release

# Build an Android App Bundle for Google Play
flutter build appbundle --release
```

For signing, APK/AAB packaging, Google Play, Firebase Cloud Messaging, and device setup, see the [complete Android build guide](docs/android-build.md).

### iOS

```bash
flutter run -d ios
flutter build ios --release
```

iOS builds and signing must be completed on macOS with Xcode.

For signing, physical-device testing, IPA export, App Store Connect, and APNs setup, see the [complete iOS build guide](docs/ios-build.md).

### Windows

```bash
flutter run -d windows
flutter build windows --release
```

The repository currently contains Android, iOS, Web, and Windows platform runners. Linux and macOS runners are not included.

## Tests and Quality Checks

Run the Flutter client checks from the project root:

```bash
flutter pub get
flutter gen-l10n
flutter analyze
dart run tool/check_l10n_hardcoding.dart
flutter test
```

Run the Mobile Server tests separately:

```bash
cd server
uv sync
uv run pytest -q
```

UI changes should pass static analysis, localization hardcoding checks, and the complete Flutter test suite. Changes to Server routes, protocols, or authentication should also pass the Server test suite.

## Localization

Localization generation is configured in `l10n.yaml`. ARB resources and related source files live in `lib/l10n/`, and generated Dart files are written to `lib/l10n/generated/`.

Regenerate localizations after changing an ARB file:

```bash
flutter gen-l10n
```

Check for user-facing strings that may still be hardcoded:

```bash
dart run tool/check_l10n_hardcoding.dart
```

## Update Manifest

The root-level `update.json` is the source manifest for client updates. Validate it after changing versions or release URLs:

```bash
dart run tool/validate_update_manifest.dart update.json
```

To produce a signed release manifest:

```bash
HERMES_MOBILE_UPDATE_PRIVATE_KEY='<base64-private-key>' \
dart run tool/sign_update_manifest.dart \
  --source update.json \
  --output dist/update.json \
  --android-artifact build/app/outputs/flutter-apk/app-release.apk \
  --android-artifact-url 'https://example.com/app-release.apk' \
  --ios-artifact build/ios/ipa/hermes-mobile.ipa \
  --ios-artifact-url 'https://example.com/hermes-mobile.ipa'
```

The signing tool records the SHA-256 digest and file size of both artifacts in the signed manifest. Replace the example URLs and artifact paths with the real release values. Never store the signing private key in the repository.

## Project Structure

```text
.
├── android/             Android runner and platform configuration
├── ios/                 iOS runner and platform configuration
├── lib/                 Flutter application source
│   ├── chat/            Chat timeline, rendering, and composer components
│   ├── core/            API, models, stores, and core application logic
│   ├── kanban/          Kanban models, API, and state
│   ├── l10n/            Localization resources and generated code
│   ├── screens/         Application screens
│   ├── theme/           Theme, color, and design tokens
│   └── widgets/         Reusable UI components
├── server/              FastAPI Mobile Server
├── test/                Flutter tests
├── third_party/xterm/   Locally patched xterm package
├── tool/                Localization and release maintenance tools
├── web/                 Web runner and static assets
├── windows/             Windows runner
├── l10n.yaml            Flutter localization configuration
├── pubspec.yaml         Flutter dependencies and assets
└── update.json          Application update source manifest
```

## Troubleshooting

### The client cannot connect to the Server

1. Open `http://127.0.0.1:9001/api/v1/health` and confirm that the Server is running.
2. Confirm that the API key entered in the client matches the current Server key.
3. Check the hostname, port, and protocol in the Server URL.
4. Do not use `127.0.0.1` on a physical device to address the development computer.
5. Check firewall rules, reverse proxy settings, and WebSocket forwarding.

### The Hermes backend exits after Server startup

First verify that the `hermes` command is available and fully configured. If the logs report an incompatible Dashboard URL or authentication mode, explicitly set `HERMES_DASHBOARD_PUBLIC_URL` to an empty value as shown in Quick Start.

### Generated Flutter files are missing

After a clean or a fresh checkout, run:

```bash
flutter pub get
flutter gen-l10n
```

If cache problems remain, run `flutter clean` and fetch dependencies again. Be aware that this removes local build output.
