# Hermes Mobile Server

REST + WebSocket API server that locates a local [Hermes Agent](https://github.com/NousResearch/hermes-agent)
installation, boots its headless backend (`hermes serve`), and exposes the
full Hermes Desktop feature surface to mobile clients over an API-key
authenticated HTTP/WebSocket interface.

## Features

- **Runtime resolution** — finds a runnable hermes-agent using the same
  precedence ladder as Hermes Desktop: explicit root →
  `$HERMES_HOME/hermes-agent` managed install → `hermes` on PATH →
  system Python. Candidates are probed, not trusted.
- **Backend lifecycle** — spawns `hermes serve --host 127.0.0.1 --port 0`,
  parses the `HERMES_BACKEND_READY` port sentinel, waits for health, and can
  restart the backend on demand.
- **Domain REST API** — the backend feature surface (sessions, config, model,
  skills, tools, files, audio, cron, memory, analytics, mcp, …) is exposed as
  domain resources under `/api/v1/*`; upstream-owned resources are proxied to
  the backend with the session token injected automatically.
- **WebSocket gateway proxy** — `/api/v1/ws` relays newline-delimited
  JSON-RPC 2.0 frames to the `tui_gateway`, giving the client the entire
  gateway surface: streaming chat (`prompt.submit` + `message.delta` /
  `tool.complete` / `message.complete` events), approvals, clarify requests,
  config, projects, cron, pets, and more.
- **API-key auth** — every endpoint requires `Authorization: Bearer <key>`.
  The key comes from `HERMES_MOBILE_API_KEY`, else is generated and persisted
  at `~/.hermes-mobile-server/config.json`.

## Run

```bash
uv sync
uv run hermes-mobile-server --host 0.0.0.0 --port 8877
```

The mobile app needs the server reachable over the network, so bind to
`0.0.0.0` (the LAN) rather than loopback, and make sure the phone and the
machine running hermes are on the same network (or tunnel the port).

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `HERMES_MOBILE_API_KEY` | generated | API key for all endpoints |
| `HERMES_MOBILE_HOST` | `127.0.0.1` | mobile-facing bind host |
| `HERMES_MOBILE_PORT` | `8877` | mobile-facing bind port |
| `HERMES_MOBILE_SERVE_HOST` | `127.0.0.1` | backend bind host |
| `HERMES_MOBILE_SERVE_PORT` | `0` | backend port (`0` = OS-assigned) |
| `HERMES_MOBILE_HERMES_ROOT` | — | force a specific hermes-agent checkout |
| `HERMES_HOME` | `%LOCALAPPDATA%\hermes` / `~/.hermes` | hermes home used by the backend |
| `HERMES_MOBILE_ALLOW_PATHS` | unrestricted | comma-separated allow-list of filesystem roots the local file API may touch |
| `HERMES_MOBILE_FCM_SERVICE_ACCOUNT_FILE` | — | Firebase service-account JSON for FCM HTTP v1 delivery |
| `HERMES_MOBILE_APNS_TEAM_ID` | — | Apple Developer team ID for APNs token authentication |
| `HERMES_MOBILE_APNS_KEY_ID` | — | APNs `.p8` signing key ID |
| `HERMES_MOBILE_APNS_BUNDLE_ID` | — | signed iOS application bundle ID |
| `HERMES_MOBILE_APNS_PRIVATE_KEY_FILE` | — | path to the APNs `.p8` private key |
| `HERMES_MOBILE_APNS_SANDBOX` | `false` | use the APNs sandbox endpoint for development builds |
| `HERMES_MOBILE_WS_MAX_PER_CLIENT` | `12` | maximum WebSockets per source client across gateway, plugin, Kanban and terminal proxies |
| `HERMES_MOBILE_TRUST_FORWARDED_FOR` | `false` | trust the first `X-Forwarded-For` address for connection limiting; enable only behind a trusted proxy |
| `HERMES_MOBILE_PROXY_IDLE_TIMEOUT` | — | configured reverse-proxy WebSocket idle timeout in seconds; values at or below 40 emit a startup warning |

## API surface

- `GET /api/v1/status` — server, runtime and backend status
- `GET /api/v1/health` — liveness (no auth)
- `POST /api/v1/backend/restart` — restart the Hermes backend
- `GET /api/v1/methods` — documentation of the API surface
- `GET /api/v1/network/metrics` — authenticated aggregate WebSocket activity, reconnect, handshake and disconnect metrics
- `/api/v1/push/*` — scoped device registration, provider status, unregister,
  and authenticated test delivery
- `/api/v1/*` — domain REST API (sessions, config, files, git, …); git and
  other upstream-owned resources are proxied to the Hermes backend
- `WS /api/v1/ws?token=<api-key>` — JSON-RPC 2.0 gateway proxy

## Security notes

The backend process itself only listens on loopback and uses an ephemeral
session token that dies with the process. The mobile-facing server is the only
surface exposed to the network; it is gated by the API key. Choose a strong
key (the auto-generated one is) and keep it private. For extra hardening,
set `HERMES_MOBILE_ALLOW_PATHS` to the workspace roots the app needs so the
local file API cannot touch anything outside them.

Push provider credentials remain on the server and are never returned by the
API. Device tokens are kept in `~/.hermes-mobile-server/push_devices.json`
with owner-only permissions; list/status responses expose only token suffixes.
FCM requires a service account with Firebase Messaging permission. APNs
requires all four Apple values above and an app signed with the Push
Notifications entitlement. Android client builds receive their public Firebase
app configuration through Gradle properties or environment variables:
`HERMES_FCM_APP_ID`, `HERMES_FCM_API_KEY`, `HERMES_FCM_PROJECT_ID`, and
`HERMES_FCM_SENDER_ID`.

## Reverse proxies and WebSockets

The server sends WebSocket pings every 20 seconds and treats a missing pong
within another 20 seconds as a dead connection. Configure every public proxy
idle timeout comfortably above that 40-second failure window; **120 seconds or
more is recommended**. Set `HERMES_MOBILE_PROXY_IDLE_TIMEOUT` to the effective
value so the server warns about unsafe deployments at startup.

- Nginx: set `proxy_http_version 1.1`, forward `Upgrade`/`Connection`, and use
  `proxy_read_timeout 120s; proxy_send_timeout 120s;`.
- Caddy: WebSocket proxying works automatically with `reverse_proxy`; do not
  configure `stream_timeout` below 120 seconds.
- Cloudflare: the managed WebSocket idle timeout depends on plan and product.
  Keep application pings enabled, avoid a Worker/Durable Object idle timeout
  below 120 seconds, and verify the current Cloudflare limit for the deployed
  plan rather than assuming it is configurable.

When a trusted reverse proxy terminates client connections, set
`HERMES_MOBILE_TRUST_FORWARDED_FOR=true` and overwrite (do not append untrusted
input to) `X-Forwarded-For`. Otherwise leave it disabled.
