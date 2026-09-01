# Hermes Mobile

[English](README.MD) | **简体中文**

Hermes Mobile 是 [Hermes Agent](https://github.com/NousResearch/hermes-agent) 的跨平台 Flutter 客户端。项目通过独立的 Mobile Server 将 Hermes Agent 的本地能力封装为 HTTP API 和 WebSocket，供 Web、Android、iOS 与 Windows 客户端使用。

> 本项目仍在持续开发中。部分高级能力依赖已安装并正确配置的 Hermes Agent、外部服务或对应平台权限。

## 功能概览

- 流式聊天、会话管理与 Profile 切换
- Skills、Tools、Plugins 与 MCP 管理
- 文件浏览、终端、Git 与项目管理
- Kanban、Cron、Subagents 与自动化任务
- Memory、Knowledge 与 Starmap
- Credentials、Billing、Messaging 与 Webhooks
- Voice、系统通知、Pet、Artifacts 与 Insights
- 中英文界面及运行时主题配置

## 系统架构

```text
Flutter App (Web / Android / iOS / Windows)
                 |
          HTTP + WebSocket
                 |
        Mobile Server (FastAPI)
                 |
          hermes serve / Agent
                 |
      本地文件、终端及外部服务
```

- Flutter 客户端使用 Provider/Store 管理界面状态与业务状态。
- `server/` 提供 FastAPI 服务，并负责启动和连接本地 `hermes serve`。
- REST API 位于 `/api/v1/*`，实时事件与流式响应通过 `/api/v1/ws` 传输。
- 除健康检查外，Mobile Server 接口均要求 API key。

## 环境要求

建议使用与当前项目验证环境一致的版本：

- Flutter 3.47.1
- Dart 3.13.1（`pubspec.yaml` 最低约束为 `^3.12.2`）
- Python 3.11+
- [uv](https://docs.astral.sh/uv/)（Server 依赖与运行管理）
- 已安装并可运行的 Hermes Agent

不同目标平台还需要对应工具链：

- Android：Android Studio、Android SDK 与可用模拟器或设备
- iOS：macOS 与 Xcode；仅当 Flutter 或插件工具链要求时才需要 CocoaPods
- Windows：Visual Studio 的 Desktop development with C++ 工作负载
- Web：Chrome，或任意现代浏览器

## 快速开始

以下示例在项目根目录执行，并使用端口 `9000`（Web）与 `9001`（Server）。

### 1. 启动 Mobile Server

```bash
cd server
uv sync
HERMES_DASHBOARD_PUBLIC_URL= uv run hermes-mobile-server \
  --host 0.0.0.0 \
  --port 9001
```

当前 Hermes Agent 版本若未启用 Dashboard 鉴权，需要将 `HERMES_DASHBOARD_PUBLIC_URL` 显式设为空；否则 Server 自动注入的 Dashboard public URL 可能导致 Hermes 内核拒绝启动。

首次启动时，如果没有设置 `HERMES_MOBILE_API_KEY`，Server 会生成 API key 并保存到：

```text
~/.hermes-mobile-server/config.json
```

可在另一个终端查看 API key：

```bash
cd server
uv run hermes-mobile-server --print-api-key
```

不要将 API key 提交到版本库、日志、截图或公开部署配置中。

### 2. 启动 Web 客户端

打开另一个终端，在项目根目录执行：

```bash
flutter pub get
flutter gen-l10n
flutter run -d web-server \
  --web-hostname 0.0.0.0 \
  --web-port 9000
```

浏览器访问：

```text
http://127.0.0.1:9000
```

在连接页面填写：

- Server URL：`http://127.0.0.1:9001`
- API key：通过 `--print-api-key` 获取的值

如果客户端运行在另一台电脑或实体手机上，请将 `127.0.0.1` 替换为 Server 所在电脑的局域网 IP，并确保防火墙允许访问 `9001` 端口。Android 模拟器访问宿主机时通常使用 `10.0.2.2`。

## Server 配置

常用环境变量：

| 变量 | 用途 |
| --- | --- |
| `HERMES_MOBILE_API_KEY` | 指定 Mobile Server API key；未设置时自动生成并持久化 |
| `HERMES_DASHBOARD_PUBLIC_URL` | Hermes Dashboard public URL；设为空可关闭 Mobile Server 的自动注入 |

生产或局域网部署时应额外注意：

- 使用强随机 API key，并通过环境变量或安全的密钥系统注入。
- `--host 0.0.0.0` 会监听所有网络接口；仅本机使用时可改为 `127.0.0.1`。
- 不要直接将未配置 TLS 和访问控制的 `9001` 端口暴露到公网。
- 反向代理 WebSocket 时需要正确转发 Upgrade 和 Connection 请求头。

完整 Server 说明参见 [server/README.md](server/README.md)，接口定义参见 [server/API.md](server/API.md)，设计说明参见 [server/DESIGN.md](server/DESIGN.md)。

## 运行与构建

### Web

```bash
flutter run -d chrome
flutter build web
```

Web 发布产物位于 `build/web/`。

### Android

```bash
flutter run -d android
flutter build apk --release
# 或构建 Google Play 使用的 App Bundle
flutter build appbundle --release
```

签名、APK/AAB 打包、Google Play、Firebase Cloud Messaging 和设备配置参见[完整 Android 编译教程](docs/android-build.zh-CN.md)。

### iOS

```bash
flutter run -d ios
flutter build ios --release
```

iOS 构建与签名需要在 macOS/Xcode 环境中完成。

签名、真机测试、IPA 导出、App Store Connect 和 APNs 配置参见[完整 iOS 编译教程](docs/ios-build.zh-CN.md)。

### Windows

```bash
flutter run -d windows
flutter build windows --release
```

当前仓库包含 Android、iOS、Web 和 Windows 平台目录，尚未提供 Linux 与 macOS runner。

## 测试与质量检查

Flutter 客户端：

```bash
flutter pub get
flutter gen-l10n
flutter analyze
dart run tool/check_l10n_hardcoding.dart
flutter test
```

Mobile Server：

```bash
cd server
uv sync
uv run pytest -q
```

提交界面改动前，建议同时执行静态分析、本地化硬编码检查和完整 Flutter 测试；修改 Server 路由、协议或鉴权逻辑时应运行 Server 测试。

## 本地化

本地化配置位于 `l10n.yaml`，ARB 资源和相关源码位于 `lib/l10n/`，生成代码位于 `lib/l10n/generated/`。

修改 ARB 文件后重新生成：

```bash
flutter gen-l10n
```

检查界面中可能遗漏的硬编码文案：

```bash
dart run tool/check_l10n_hardcoding.dart
```

## 应用更新清单

根目录 `update.json` 是客户端更新源清单。修改版本或发布地址后可执行：

```bash
dart run tool/validate_update_manifest.dart update.json
```

需要发布签名时使用：

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

签名命令会计算两端安装包的 SHA-256 和文件大小，并输出签名后的清单。签名私钥属于敏感信息，不应放入仓库；示例 URL 和产物路径需替换为实际发布信息。

## 目录结构

```text
.
├── android/             Android runner 与平台配置
├── ios/                 iOS runner 与平台配置
├── lib/                 Flutter 应用源码
│   ├── chat/            聊天时间线、内容渲染与输入组件
│   ├── core/            API、模型、状态存储及核心业务逻辑
│   ├── kanban/          Kanban 数据模型、API 与状态
│   ├── l10n/            本地化资源与生成代码
│   ├── screens/         页面与主要界面
│   ├── theme/           主题、颜色与设计令牌
│   └── widgets/         可复用界面组件
├── server/              FastAPI Mobile Server
├── test/                Flutter 测试
├── third_party/xterm/   项目使用的本地 xterm 补丁版本
├── tool/                本地化与更新清单等维护工具
├── web/                 Web runner 与静态资源
├── windows/             Windows runner
├── l10n.yaml            Flutter 本地化生成配置
├── pubspec.yaml         Flutter 依赖及资源配置
└── update.json          应用更新源清单
```

## 常见问题

### 客户端无法连接 Server

1. 访问 `http://127.0.0.1:9001/api/v1/health` 确认 Server 已启动。
2. 确认客户端填写的 API key 与 Server 当前 key 一致。
3. 检查 URL 的主机名、端口和协议是否正确。
4. 实体设备不要使用 `127.0.0.1` 指向开发电脑。
5. 检查防火墙、反向代理与 WebSocket 转发配置。

### Server 启动后 Hermes 内核退出

先确认 `hermes` 命令可用及其配置完整。若日志提示 Dashboard URL 或鉴权不兼容，按快速开始示例将 `HERMES_DASHBOARD_PUBLIC_URL` 显式设为空后重试。

### Flutter 生成文件缺失

清理项目或首次拉取源码后执行：

```bash
flutter pub get
flutter gen-l10n
```

如仍存在缓存问题，可执行 `flutter clean` 后重新获取依赖。注意该命令会删除本地构建产物。
