# Hermes Mobile iOS 编译教程

[English](ios-build.md) | **简体中文**

本文档说明如何编译、运行、签名、归档和导出当前 Hermes Mobile iOS 工程。

## 当前 iOS 配置

| 配置项 | 当前值 |
| --- | --- |
| 最低系统版本 | iOS 13.0 |
| 支持设备 | iPhone 和 iPad |
| 默认 Bundle ID | `com.hermes.mobile` |
| 应用显示名称 | Hermes Mobile |
| 版本来源 | `pubspec.yaml` 中的 `version` |
| 默认签名方式 | 自动签名 |
| Xcode 工作区 | `ios/Runner.xcworkspace` |
| 原生插件集成 | Flutter 生成的 Swift Package Manager 本地包 |
| 推送环境 | Debug 使用 development，Release 使用 production |

工程声明了麦克风、局域网和远程通知能力。因此，Release 签名所使用的 App ID 与描述文件必须支持 Push Notifications。

## 环境要求

iOS 只能在 macOS 上编译。需要安装：

- 当前 Flutter SDK 支持的较新稳定版 Xcode
- Xcode Command Line Tools
- Flutter 3.47.1 和 Dart 3.13.1，与项目当前验证环境保持一致
- 模拟器和无签名编译不需要 Apple 账号；本地真机签名需要 Apple ID，TestFlight、App Store 和推送分发需要 Apple Developer Program 会员
- 仅当 `flutter doctor` 或插件集成明确要求时才需要 CocoaPods

选择 Xcode 并完成首次初始化：

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo xcodebuild -license accept
```

检查环境：

```bash
flutter doctor -v
xcodebuild -version
flutter devices
```

继续之前，应解决 `flutter doctor` 中 Xcode/iOS 部分报告的所有错误。

## 准备项目

在项目根目录执行：

```bash
flutter clean
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
```

普通增量编译不必每次运行 `flutter clean`。切换 Flutter/Xcode 版本、修改插件或原生工程配置后出现缓存问题时再使用它。

当前工程使用 Flutter 生成的 Swift Package Manager 本地包集成原生插件，仓库没有提交 `Podfile`。应让 `flutter pub get` 生成该集成；除非当前 Flutter 版本或某个依赖明确要求，否则不要自行添加或执行 CocoaPods 命令。

## 在 iOS 模拟器中运行

启动模拟器并列出设备：

```bash
open -a Simulator
flutter devices
```

使用 `flutter devices` 显示的模拟器 ID 启动应用：

```bash
flutter run -d <simulator-device-id>
```

只编译模拟器应用而不启动：

```bash
flutter build ios --simulator --debug
```

模拟器产物位于 `build/ios/iphonesimulator/`。模拟器不能提供真实 APNs 设备 Token，推送通知必须使用实体设备验证。

## 配置 Apple 签名

打开生成的工作区，不要只打开 `.xcodeproj`：

```bash
open ios/Runner.xcworkspace
```

在 Xcode 中：

1. 选择 **Runner** 项目和 **Runner** Target。
2. 打开 **Signing & Capabilities**。
3. 选择你的 Apple Developer Team。
4. 本地开发保持 **Automatically manage signing** 开启。
5. 如果默认的 `com.hermes.mobile` 不可用，将其替换为注册在自己团队下的 Bundle ID。
6. 确认 Release 构建启用了 **Push Notifications** Capability。
7. 如果 Xcode 没有从工程配置中正确识别，确认 **Background Modes > Remote notifications** 已启用。

最终 Bundle ID 必须与 Mobile Server 的 `HERMES_MOBILE_APNS_BUNDLE_ID` 一致。两者不一致时应用仍可能编译成功，但 APNs 推送会失败。

不要提交个人 Team ID、证书、私钥或描述文件。已被忽略的 `ios/Flutter/Signing.xcconfig` 可用于本机签名配置。

## 在实体设备上运行

连接并解锁 iPhone 或 iPad，信任 Mac，按提示启用开发者模式，然后检查 Flutter 是否识别设备：

```bash
flutter devices
flutter run -d <physical-device-id>
```

首次签名失败时，打开 `ios/Runner.xcworkspace`，选择实体设备并从 Xcode 运行一次，让 Xcode 创建或下载开发描述文件。

Hermes Mobile 需要连接独立的 Mobile Server。在实体设备中，`127.0.0.1` 指向手机自身。可在 Mac 或另一台局域网电脑上启动 Server：

```bash
cd server
HERMES_DASHBOARD_PUBLIC_URL= uv run hermes-mobile-server \
  --host 0.0.0.0 \
  --port 9001
```

在 App 中填写 `http://<server-lan-ip>:9001` 和 Server API key。允许 iOS 的局域网访问请求，并确保主机防火墙放行 `9001` 端口。

## 不签名编译

在 CI 中进行编译检查，或者尚未配置 Apple 账号时验证原生工程是否能编译：

```bash
flutter build ios --release --no-codesign
```

该命令在 `build/ios/iphoneos/` 下生成未签名的 `.app`，不能安装到普通实体设备，也不能上传到 App Store Connect。

## 编译已签名 Release

显式指定公开版本号和单调递增的构建号：

```bash
flutter build ios --release \
  --build-name 1.0.0 \
  --build-number 1
```

Flutter 将 `--build-name` 写入 `CFBundleShortVersionString`，将 `--build-number` 写入 `CFBundleVersion`。同一版本下已经上传过的构建号不能重复使用。

## 创建 IPA

### 自动签名

在 Xcode 中选择有效 Team 后执行：

```bash
flutter build ipa --release \
  --build-name 1.0.0 \
  --build-number 1
```

Archive 位于 `build/ios/archive/`，导出的 IPA 位于 `build/ios/ipa/`。

### 使用 Xcode Organizer

交互式发布到 App Store：

1. 打开 `ios/Runner.xcworkspace`。
2. 将目标设备选择为 **Any iOS Device (arm64)**。
3. 选择 **Product > Archive**。
4. 在 Organizer 中选中 Archive，点击 **Distribute App**。
5. 选择 **App Store Connect**，验证并上传构建。

### 手动导出模板

仓库提供了 `ios/ExportOptions.plist` 作为 App Store Connect 手动导出模板。模板中的占位符不能直接使用，需要替换：

- 将 `HERMES_TEAM_ID` 替换为 Apple Developer Team ID
- 将 `HERMES_PROFILE_NAME` 替换为对应 Bundle ID 的 App Store 描述文件名称

然后执行：

```bash
flutter build ipa --release \
  --build-name 1.0.0 \
  --build-number 1 \
  --export-options-plist=ios/ExportOptions.plist
```

建议生成仅供本机使用的导出配置副本，不要把账号相关值提交到仓库。

## APNs 配置

iOS Target 已包含 `aps-environment` entitlement：

- Debug 构建解析为 `development`。
- Release 构建解析为 `production`。

要启用推送，需在 Mobile Server 配置以下全部变量：

```bash
export HERMES_MOBILE_APNS_TEAM_ID='<apple-team-id>'
export HERMES_MOBILE_APNS_KEY_ID='<apns-key-id>'
export HERMES_MOBILE_APNS_BUNDLE_ID='<signed-app-bundle-id>'
export HERMES_MOBILE_APNS_PRIVATE_KEY_FILE='/secure/path/AuthKey_XXXXXXXXXX.p8'
```

使用开发签名的 Debug 构建时，还需设置：

```bash
export HERMES_MOBILE_APNS_SANDBOX=true
```

TestFlight 与 App Store 构建应使用生产 APNs 环境。不要将 `.p8` 私钥放入仓库。

## 发布前检查

- `flutter analyze` 和 `flutter test` 全部通过。
- 版本号和构建号正确，且构建号没有重复上传。
- 分发证书和描述文件有效。
- 签名 Bundle ID 与 App Store Connect 记录、Server APNs 配置一致。
- Push Notifications 和 remote-notification 后台模式已启用。
- 麦克风和局域网权限说明适用于发布语言。
- App Icon 没有 Alpha 通道，并包含所需尺寸。
- App 连接启用 TLS 的生产 Mobile Server，不要直接向公网暴露无保护的 `9001` 端口。
- Archive 上传前已通过 Xcode Organizer 验证。

## 常见问题

### 找不到 iOS 设备

执行 `flutter doctor -v`，至少启动一次 Xcode，安装 Xcode 请求的平台组件，并确认设备已信任 Mac 且启用了开发者模式。如果配对仍不可用，重启 Xcode 和设备。

### Signing requires a development team

打开 `ios/Runner.xcworkspace`，进入 **Runner > Signing & Capabilities** 并选择 Team。如果 Bundle ID 属于其他账号，将其改成注册在自己团队下的标识符。

### 描述文件不包含 `aps-environment`

在 Apple Developer 后台为 App ID 启用 Push Notifications，然后重新生成或刷新描述文件。免费的 Personal Team 描述文件可能不支持所需的推送能力。

### 插件或生成的原生文件缺失

在项目根目录执行：

```bash
flutter clean
flutter pub get
flutter gen-l10n
```

然后重新打开 `ios/Runner.xcworkspace`。`ios/Flutter/` 下的生成文件和 `Runner/GeneratedPluginRegistrant.*` 已被有意忽略，不应手工修改。

### 实体设备无法连接 Mobile Server

使用 Server 电脑的局域网 IP，不要使用 `127.0.0.1`；让 Server 监听 `0.0.0.0`，允许 iOS 局域网权限，并检查主机防火墙。公网部署应通过正确配置的反向代理提供 HTTPS/WSS。

### 已获得 APNs Token，但收不到推送

确认 APNs 私钥、Team ID、Key ID、Bundle ID 和 sandbox 设置全部属于同一套 Apple Developer 配置。Debug 构建使用 sandbox，TestFlight 和 App Store 构建使用 production。
