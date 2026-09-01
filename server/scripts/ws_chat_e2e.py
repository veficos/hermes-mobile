"""End-to-end test of the Hermes Mobile Server WebSocket gateway proxy.

Connects like the mobile app will, creates a session, submits a prompt and
prints the streamed events until the turn completes.
"""

import asyncio
import json
import os
import sys

import websockets

KEY = os.environ["HM_API_KEY"]
URL = os.environ.get("HM_WS_URL", "ws://127.0.0.1:8877/api/v1/ws")
PROMPT = os.environ.get("HM_PROMPT", "Reply with exactly: PONG")


async def main() -> int:
    next_id = 1

    def request(method: str, params: dict) -> dict:
        nonlocal next_id
        frame = {"jsonrpc": "2.0", "id": next_id, "method": method, "params": params}
        next_id += 1
        return frame

    async with websockets.connect(f"{URL}?token={KEY}", max_size=None) as ws:
        # 1. wait for gateway.ready
        ready = json.loads(await ws.recv())
        print("READY:", json.dumps(ready.get("params", {}).get("payload", {}))[:200])

        # 2. create session
        await ws.send(json.dumps(request("session.create", {"cols": 80, "source": "mobile"})))
        resp = json.loads(await ws.recv())
        if "error" in resp:
            print("session.create ERROR:", resp["error"])
            return 1
        session_id = resp["result"]["session_id"]
        print(f"session.create -> {session_id} stored={resp['result'].get('stored_session_id')}")
        print("info:", json.dumps(resp["result"].get("info", {}))[:300])

        # 3. submit prompt
        await ws.send(json.dumps(request("prompt.submit", {"session_id": session_id, "text": PROMPT})))
        resp = json.loads(await ws.recv())
        print("prompt.submit ->", resp.get("result", resp.get("error")))

        # 4. collect events until message.complete
        print("--- events ---")
        text_parts: list[str] = []
        tool_started = 0
        while True:
            frame = json.loads(await asyncio.wait_for(ws.recv(), timeout=300))
            if frame.get("method") != "event":
                print("non-event frame:", json.dumps(frame)[:200])
                continue
            params = frame["params"]
            etype = params["type"]
            payload = params.get("payload") or {}
            if etype == "message.delta":
                text_parts.append(str(payload.get("text", "")))
            elif etype == "tool.start":
                tool_started += 1
                print(f"[tool.start] {payload.get('name')} args={str(payload.get('args_text'))[:120]}")
            elif etype == "tool.complete":
                print(f"[tool.complete] {payload.get('name')} summary={str(payload.get('summary'))[:100]}")
            elif etype in ("reasoning.delta", "thinking.delta"):
                pass
            elif etype in ("status.update", "session.info", "session.title"):
                print(f"[{etype}] {json.dumps(payload)[:150]}")
            elif etype in ("approval.request", "clarify.request"):
                print(f"[{etype}] {json.dumps(payload)[:200]}")
            elif etype == "message.complete":
                status = payload.get("status")
                usage = payload.get("usage") or {}
                print(f"[message.complete] status={status} usage={usage}")
                break
            elif etype in ("message.start", "message.interim", "reasoning.available"):
                continue
            else:
                print(f"[{etype}] {json.dumps(payload)[:150]}")

        print("--- final text ---")
        print("".join(text_parts))
        print(f"tools started: {tool_started}")
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
