"""Live probe: terminal WS start -> write -> read echo -> dispose."""
import asyncio
import json
import os

import websockets

KEY = os.environ.get("HERMES_MOBILE_API_KEY", "").strip()
BASE_URL = os.environ.get("HM_TERMINAL_WS_URL", "ws://127.0.0.1:8877/api/v1/terminal/ws")
WORKSPACE = os.environ.get("HM_TEST_CWD", os.getcwd())


async def main() -> None:
    if not KEY:
        raise SystemExit("HERMES_MOBILE_API_KEY is required")
    separator = "&" if "?" in BASE_URL else "?"
    url = f"{BASE_URL}{separator}token={KEY}"
    async with websockets.connect(url) as ws:
        # 1. start
        await ws.send(json.dumps({"op": "start", "request_id": 1,
                                  "cwd": WORKSPACE,
                                  "cols": 100, "rows": 30}))
        session_id = None
        deadline = asyncio.get_event_loop().time() + 20
        while asyncio.get_event_loop().time() < deadline:
            frame = json.loads(await asyncio.wait_for(ws.recv(), 20))
            if frame.get("request_id") == 1 and frame.get("event") == "started":
                session_id = frame["id"]
                print(f"STARTED id={session_id} shell={frame.get('shell')} cwd={frame.get('cwd')}")
                break
        if not session_id:
            print("FAIL: no started frame")
            return

        # 2. wait for the shell prompt to settle, then write a command
        await asyncio.sleep(3)
        await ws.send(json.dumps({"op": "write", "request_id": 2,
                                  "id": session_id, "data": "echo __PTY_INPUT_OK__\r"}))
        print("WRITE sent: echo __PTY_INPUT_OK__")

        # 3. collect output, look for the echo marker
        collected = ""
        deadline = asyncio.get_event_loop().time() + 20
        while asyncio.get_event_loop().time() < deadline:
            try:
                frame = json.loads(await asyncio.wait_for(ws.recv(), 20))
            except asyncio.TimeoutError:
                break
            if frame.get("event") == "data":
                collected += frame.get("data", "")
                if "__PTY_INPUT_OK__" in collected.replace("\r", "").replace("\n", ""):
                    # marker appears twice (echo + output); one is enough
                    print("ECHO OK: input reached the PTY and output came back")
                    break
            elif frame.get("event") == "error":
                print(f"ERROR frame: {frame.get('message')}")
                break

        # 4. ack check for write
        # 5. dispose
        await ws.send(json.dumps({"op": "dispose", "request_id": 3, "id": session_id}))
        deadline = asyncio.get_event_loop().time() + 10
        while asyncio.get_event_loop().time() < deadline:
            frame = json.loads(await asyncio.wait_for(ws.recv(), 10))
            if frame.get("request_id") == 3:
                print(f"DISPOSE ack ok={frame.get('ok')}")
                break
        if "__PTY_INPUT_OK__" not in collected:
            print(f"FAIL: marker not found. Collected tail: {collected[-300:]!r}")


asyncio.run(main())
