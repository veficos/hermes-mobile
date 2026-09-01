# Hermes Mobile Android 编译教程

[English](android-build.md) | **简体中文**

本文档说明如何配置、运行、签名当前 Hermes Mobile Android 工程，并构建 APK 或 Android App Bundle。

## 当前 Android 配置

| 配置项 | 当前值 |
| --- | --- |
| Application ID / namespace | `com.hermes.mobile` |
| 最低 Android 版本 | Android 7.0，API 24 |
| Compile SDK / Target SDK | API 36 |
| NDK | `28.2.13676358` |
| Java 和 Kotlin 字节码目标 | JVM 17 |
| Android Gradle Plugin | 9.0.1 |
| Gradle Wrapper | 9.1.0 |
| Kotlin 插件 | 2.3.20 |
| 版本来源 | `pubspec.yaml` 中的 `version` |
| Release 签名 | 必须通过 `android/key.properties` 配置 |

SDK 和 NDK 版本继承自当前验证使用的 Flutter 3.47.1 工具链。以后升级 Flutter 时，应重新检查实际生效版本，再配置构建机器。

## 环境要求

Android 可以在 Linux、macOS 或 Windows 上编译。需要安装：

- Flutter 3.47.1 和 Dart 3.13.1，与项目当前验证环境一致
- Android Studio、Android SDK Platform 36 和 Android SDK Command-line Tools
- Android NDK `28.2.13676358`
- AGP 9 支持的 JDK；建议使用 Android Studio 内置 JDK，或 JDK 17 及以上兼容版本
- 用于运行测试的 Android 模拟器或实体设备

检查环境并接受 Android SDK 许可：

```bash
flutter doctor -v
flutter doctor --android-licenses
flutter devices
java -version
```

继续之前，应解决 `flutter doctor` 中 Android 工具链部分报告的所有错误。`android/local.properties` 由本机生成，必须指向有效的 Flutter 和 Android SDK；该文件已被版本控制忽略。

## 准备项目

在项目根目录执行：

```bash
flutter clean
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
```

普通增量编译不必每次执行 `flutter clean`。切换 Flutter、Gradle 或 Android 插件版本，或者修改原生资源、签名配置后出现缓存问题时再使用。

## 运行 Debug 构建

### Android 模拟器

可以通过 Android Studio Device Manager 启动模拟器，也可以用 Flutter 列出并启动：

```bash
flutter emulators
flutter emulators --launch <emulator-id>
flutter devices
flutter run -d <android-device-id>
```

Android 模拟器通过 `10.0.2.2` 访问开发电脑上的 Server。使用默认端口时，在 Hermes Mobile 中填写 `http://10.0.2.2:9001`。

### 实体设备

开启开发者选项和 USB 调试，连接并授权设备，然后执行：

```bash
adb devices
flutter devices
flutter run -d <android-device-id>
```

实体设备中的 `127.0.0.1` 指向设备自身。应使用 Mobile Server 电脑的局域网地址，让 Server 监听 `0.0.0.0`，并在主机防火墙中放行 `9001` 端口。

### 构建 Debug APK

```bash
flutter build apk --debug
```

产物路径：

```text
build/app/outputs/flutter-apk/app-debug.apk
```

安装或覆盖更新：

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

## 网络安全行为

Debug 和 Profile Manifest 允许本地开发所需的普通 HTTP。Release Manifest 的限制更严格：

- 默认禁止普通 HTTP。
- 明确允许 `localhost`、`127.0.0.1`、`10.0.2.2` 和 `.local` 主机名。
- Release 构建不允许通过 HTTP 访问 `192.168.x.x` 之类的任意局域网 IP。

生产 Mobile Server 应使用具有有效证书的 HTTPS/WSS。不要为了向公网暴露未加密服务而放宽 `android/app/src/main/res/xml/network_security_config.xml`。

## 配置 Release 签名

在 `android/key.properties` 存在之前，所有 Release 任务都会被工程主动拒绝。应使用长期有效的上传密钥并安全备份；丢失密钥可能导致无法继续更新非 Play App Signing 应用。

### 1. 生成上传密钥库

使用仓库外的明确安全路径：

```bash
keytool -genkeypair -v \
  -keystore /Users/your-name/Keys/hermes-mobile-upload.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias hermes-mobile
```

Linux 或 Windows 用户应将示例路径替换为适合本机的绝对路径。

### 2. 创建签名配置

复制仓库中的模板：

```bash
cp android/key.properties.example android/key.properties
```

编辑 `android/key.properties`：

```properties
storeFile=/Users/your-name/Keys/hermes-mobile-upload.jks
storePassword=your-keystore-password
keyAlias=hermes-mobile
keyPassword=your-key-password
```

`storeFile` 应使用绝对路径。`android/key.properties` 和 `*.jks` 均已被仓库忽略，但仍需确认它们不会被提交。限制本机访问权限：

```bash
chmod 600 android/key.properties
chmod 600 /Users/your-name/Keys/hermes-mobile-upload.jks
```

应将密钥库和密码保存到加密备份或 CI 密钥系统中，不要把密钥库编码到受版本控制的文件。

## 设置发布版本

默认版本来自 `pubspec.yaml`：

```yaml
version: 1.0.0+1
```

`+` 前的部分成为 Android `versionName`，后面的整数成为 `versionCode`。Google Play 要求每次上传的 `versionCode` 大于之前的所有构建。

不修改 `pubspec.yaml`，在编译时覆盖两个值：

```bash
flutter build appbundle --release \
  --build-name 1.0.0 \
  --build-number 1
```

## 构建 Release 产物

### 通用 APK

```bash
flutter build apk --release \
  --build-name 1.0.0 \
  --build-number 1
```

产物路径：

```text
build/app/outputs/flutter-apk/app-release.apk
```

### 按 ABI 拆分 APK

用于提供体积更小的直接下载包：

```bash
flutter build apk --release --split-per-abi \
  --build-name 1.0.0 \
  --build-number 1
```

Flutter 通常会分别生成 `armeabi-v7a`、`arm64-v8a` 和 `x86_64` APK。安装时应选择与设备架构匹配的文件。

### Android App Bundle

Google Play 发布通常应使用 AAB：

```bash
flutter build appbundle --release \
  --build-name 1.0.0 \
  --build-number 1
```

产物路径：

```text
build/app/outputs/bundle/release/app-release.aab
```

正式发布前，先上传到内部测试轨道。启用 Play App Signing 后，本地密钥通常作为上传密钥，最终应用签名密钥由 Google 管理。

## 配置 Firebase Cloud Messaging

Android 客户端通过 Gradle 属性或环境变量初始化 Firebase，不要求提交 `google-services.json`。需要推送通知时，应提供全部四个 Firebase 公共应用配置：

```bash
export HERMES_FCM_APP_ID='<firebase-android-app-id>'
export HERMES_FCM_API_KEY='<firebase-web-api-key>'
export HERMES_FCM_PROJECT_ID='<firebase-project-id>'
export HERMES_FCM_SENDER_ID='<firebase-sender-id>'
```

然后在同一个 Shell 中运行或构建：

```bash
flutter run -d <android-device-id>
flutter build appbundle --release
```

任何一个值缺失时，应用仍可编译，但 Android 推送注册会被禁用，也不会返回 FCM Token。

Mobile Server 还需要具有 Firebase Messaging 权限的服务账号：

```bash
export HERMES_MOBILE_FCM_SERVICE_ACCOUNT_FILE='/secure/path/firebase-service-account.json'
```

服务账号 JSON 是私密凭证，只能保存在 Server，不应放入 App 或仓库。

Android 13 及以上版本需要运行时通知权限。Manifest 已声明 `POST_NOTIFICATIONS`，实体设备测试时还需允许应用弹出的权限请求。

## 验证构建产物

使用 Android SDK Build Tools 检查已签名 APK：

```bash
apksigner verify --verbose --print-certs \
  build/app/outputs/flutter-apk/app-release.apk
```

检查 AAB 签名：

```bash
jarsigner -verify -verbose -certs \
  build/app/outputs/bundle/release/app-release.aab
```

签名配置完成后，还可以运行 Android lint：

```bash
cd android
./gradlew lintRelease
```

## 发布前检查

- `flutter analyze` 和 `flutter test` 全部通过。
- Application ID 与 Google Play 应用记录一致。
- `versionCode` 大于之前上传的所有构建。
- 上传密钥库、Alias 和密码已备份，并可供 CI 安全使用。
- Release APK 或 AAB 签名验证通过。
- 需要推送时，FCM 应用配置已完整提供。
- Mobile Server 配置了正确的 Firebase 服务账号。
- 已在实体设备验证通知、麦克风和局域网工作流。
- Release Server URL 使用 HTTPS/WSS；工程会主动阻止任意局域网 IP 的普通 HTTP。
- AAB 已通过 Google Play 内部测试轨道验证，再扩大发布范围。

## 常见问题

### 缺少 Android SDK 或许可

通过 Android Studio SDK Manager 安装 Platform 36、Command-line Tools 和 NDK `28.2.13676358`，然后重新执行 `flutter doctor --android-licenses` 和 `flutter doctor -v`。

### Gradle 使用了错误的 JDK

使用 Android Studio 内置 JDK，或者让 Flutter 指向兼容的 JDK：

```bash
flutter config --jdk-dir /absolute/path/to/jdk
flutter doctor -v
```

项目将 Java 和 Kotlin 源码编译为 JVM 17。切换 JDK 后停止旧 Gradle Daemon：

```bash
cd android
./gradlew --stop
```

### Release signing is not configured

如果 Gradle 报告 `Release signing is not configured`，请根据模板创建 `android/key.properties`，并确认 `storeFile` 是指向现有密钥库的绝对路径。

### 密钥库损坏或密码错误

检查 Alias 和凭证，同时避免把密码输出到日志：

```bash
keytool -list -keystore /Users/your-name/Keys/hermes-mobile-upload.jks
```

对于已经发布且没有使用 Play App Signing 的应用，不要随意生成替代密钥；用户无法安装由无关密钥签名的更新。

### 依赖或 Gradle 缓存错误

先执行影响范围较小的清理：

```bash
flutter clean
flutter pub get
cd android
./gradlew clean
```

除非错误已证明共享 Gradle 缓存损坏，否则不要删除它们，因为所有依赖都需要重新下载。

### 模拟器无法连接 Mobile Server

使用 `http://10.0.2.2:9001`，不要使用 `127.0.0.1`。确认 Server 已启动，并且宿主机能访问 `http://127.0.0.1:9001/api/v1/health`。

### 实体设备无法连接 Mobile Server

Debug 构建可使用 Server 电脑的局域网 IP，让 Server 监听 `0.0.0.0` 并检查防火墙。Release 构建应使用 HTTPS/WSS 或允许的 `.local` 主机名，因为工程有意阻止任意 IP 的普通 HTTP。

### FCM 没有返回 Token

确认四个 `HERMES_FCM_*` 值都提供给启动构建的同一个 Shell。修改内嵌 Firebase 配置后重新安装 App，确认设备支持 Google Play 服务，并在 Android 13 及以上版本允许通知权限。
