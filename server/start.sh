#!/usr/bin/env bash

set -Eeuo pipefail

# Always run from the project root, even when invoked from another directory.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

if ! command -v uv >/dev/null 2>&1; then
  echo "错误：未找到 uv，请先安装：https://docs.astral.sh/uv/" >&2
  exit 127
fi

# Listen on the LAN by default so mobile devices can reach the service.
# Existing environment variables take precedence over these defaults.
export HERMES_MOBILE_HOST="${HERMES_MOBILE_HOST:-0.0.0.0}"
export HERMES_MOBILE_PORT="${HERMES_MOBILE_PORT:-8877}"
export HERMES_DASHBOARD_PUBLIC_URL=""
echo "正在启动 Hermes Mobile Server：${HERMES_MOBILE_HOST}:${HERMES_MOBILE_PORT}"
exec uv run --locked hermes-mobile-server "$@"
