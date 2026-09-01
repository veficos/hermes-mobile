"""Verify the session lifecycle the mobile History flow depends on:

1. create a session over WS, run one prompt
2. list sessions over REST (as the History tab does)
3. fetch messages over REST (as the transcript does)
4. resume the stored session over WS
"""

import asyncio
import json
import os
import sys

import httpx
import websockets

KEY = os.environ["HM_API_KEY"]
BASE = os.environ.get("HM_BASE", "http://127.0.0.1:8877")
WS_URL = BASE.replace("http", "ws") + "/api/v1/ws"
HDRS = {"Authorization": f"Bearer {KEY}"}


async def main() -> int:
    next_id = 1

    def request(method: str, params: dict) -> dict:
        nonlocal next_id
        frame = {"jsonrpc": "2.0", "id": next_id, "method": method, "params": params}
        next_id += 1
        return frame

    async def rpc(ws, method: str, params: dict) -> dict:
        """Send a request and wait for the response with the matching id."""
        req = request(method, params)
        await ws.send(json.dumps(req))
        while True:
            frame = json.loads(await asyncio.wait_for(ws.recv(), timeout=120))
            if frame.get("id") == req["id"]:
                return frame
            # otherwise it's a broadcast event; ignore it

    async with websockets.connect(f"{WS_URL}?token={KEY}", max_size=None) as ws:
        await ws.recv()  # gateway.ready
        resp = await rpc(ws, "session.create", {"cols": 48, "source": "mobile"})
        assert "result" in resp, resp
        sid = resp["result"]["session_id"]
        stored = resp["result"]["stored_session_id"]
        print(f"created sid={sid} stored={stored}")

        await rpc(ws, "prompt.submit", {"session_id": sid, "text": "Say the word RESUME-OK and nothing else."})
        print("submit ok")
        while True:
            frame = json.loads(await asyncio.wait_for(ws.recv(), timeout=120))
            if frame.get("method") == "event" and frame["params"]["type"] == "message.complete":
                print("complete status:", frame["params"]["payload"]["status"])
                break

    async with httpx.AsyncClient(base_url=BASE, headers=HDRS) as http:
        # History tab: list sessions
        r = await http.get("/api/v1/sessions?limit=20")
        r.raise_for_status()
        sessions = r.json().get("sessions", [])
        found = next((s for s in sessions if s.get("id") == stored), None)
        assert found, "stored session not in REST list!"
        print(f"REST list ok: {len(sessions)} sessions; found stored one ({found.get('title')!r})")

        # Transcript: fetch messages
        r = await http.get(f"/api/v1/sessions/{stored}/messages")
        r.raise_for_status()
        msgs = r.json().get("messages", [])
        roles = [m.get("role") for m in msgs]
        print(f"REST messages: {len(msgs)} ({roles})")

    # Resume over WS (as the app does when opening History -> chat)
    async with websockets.connect(f"{WS_URL}?token={KEY}", max_size=None) as ws:
        await ws.recv()
        resp = await rpc(ws, "session.resume", {
            "session_id": stored, "cols": 48, "source": "mobile", "omit_messages": True,
        })
        assert "result" in resp, resp
        r = resp["result"]
        print(f"resume ok: sid={r['session_id']} messages={r.get('message_count')} "
              f"running={r.get('running')} status={r.get('status')}")

    print("ALL OK")
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
