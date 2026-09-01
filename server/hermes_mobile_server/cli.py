"""Command-line entry point for Hermes Mobile Server.

Usage::

    hermes-mobile-server [--host 0.0.0.0] [--port 8877]

Environment variables (all optional):

* ``HERMES_MOBILE_API_KEY``          — API key; generated & persisted if unset
* ``HERMES_MOBILE_HOST``             — bind host (default 127.0.0.1)
* ``HERMES_MOBILE_PORT``             — bind port (default 8877)
* ``HERMES_MOBILE_SERVE_HOST``       — backend bind host (default 127.0.0.1)
* ``HERMES_MOBILE_SERVE_PORT``       — backend port, 0 = OS-assigned
* ``HERMES_DESKTOP_HERMES_ROOT``     — force a specific hermes-agent checkout
* ``HERMES_HOME``                    — where hermes-agent lives / keeps state
* ``HERMES_MOBILE_ALLOW_PATHS``      — comma-separated allow-list of
                                       filesystem roots the local file API
                                       may touch (default: unrestricted)
"""

from __future__ import annotations

import argparse
import logging
import sys

from .app import create_app
from .config import load_settings


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="hermes-mobile-server",
        description="API server that drives a local Hermes Agent for mobile apps.",
    )
    parser.add_argument("--host", default=None, help="bind host (default from HERMES_MOBILE_HOST)")
    parser.add_argument("--port", type=int, default=None, help="bind port (default from HERMES_MOBILE_PORT)")
    parser.add_argument("--api-key", default=None, help="API key (default from HERMES_MOBILE_API_KEY)")
    parser.add_argument("--print-api-key", action="store_true", help="print the API key and exit")
    args = parser.parse_args(argv)

    settings = load_settings()
    if args.host:
        settings.host = args.host
    if args.port:
        settings.port = args.port
    if args.api_key:
        settings.api_key = args.api_key

    if args.print_api_key:
        print(settings.api_key)
        return 0

    logging.basicConfig(
        level=getattr(logging, settings.log_level.upper(), logging.INFO),
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )

    import uvicorn

    app = create_app(settings)

    print("=" * 64)
    print("  Hermes Mobile Server")
    print(f"  Listening on  http://{settings.host}:{settings.port}")
    print(f"  API key:      {settings.api_key}")
    print(f"  REST API:     http://{settings.host}:{settings.port}/api/v1 (see /api/v1/methods)")
    print(f"  Gateway WS:   ws://{settings.host}:{settings.port}/api/v1/ws?token=<key>")
    print("  Docs:         http://127.0.0.1:%d/api/v1/docs" % settings.port)
    print("=" * 64)

    uvicorn.run(
        app,
        host=settings.host,
        port=settings.port,
        log_level=settings.log_level,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
