# Bot-to-bot relay: how mobile implements it

Phase 6 of the desktop-parity Bot migration. Superseded: this used to describe
an assumed backend gap. Re-reading desktop's `hermes-bots/plugin.js` in full
showed the gateway already exposes a network-native `bot_relay.*` RPC family
that desktop's own Electron process bridges between the local gateways it
holds sockets to. Mobile's `ConnectionRegistry` plays the exact same bridging
role for the gateways it holds sockets to, so this needed no new backend work
— only a client-side port, now implemented in `lib/core/stores/bot_store.dart`.

## Gateway surface (pre-existing, confirmed via desktop's usage)

- `bot_relay.roster.sync {agents}` — tells one gateway about agents living on
  every *other* connected gateway.
- `bot_relay.outbox.drain {}` — pops pending outbound relay envelopes queued
  by that gateway's agents (via their `message_agent`-style tool).
- `bot_relay.deliver {profile, message}` — delivers into a profile's canonical
  chat, creating it if needed; returns `{reply}`.
- `bot_relay.reply {id, reply?, error?, reason?}` — reports delivery
  outcome back to the sending gateway so the waiting tool call can resolve.
- push event `bot_relay.outbox.pending` — signals a fresh envelope without
  waiting for the next poll.

## Mobile implementation (`BotStore`)

- `_syncRelayRosters()` — piggybacks on the existing 30s roster-refresh cycle
  (`refresh()`) rather than desktop's separate 60s timer, since the agent rows
  are already fetched there. For each connection, pushes the union of every
  *other* connection's bots (`profile`, `handle`, `connection_id`,
  `connection_label`, `title`, `description`). Silently skips a connection
  that rejects the call (older backend without `bot_relay` support).
- `_drainRelayOutboxes()` — runs on a 4s timer (started/stopped alongside the
  roster timer in `startRosterRefresh()`/`setForeground()`) and is also
  triggered immediately (debounced 250ms) when a `bot_relay.outbox.pending`
  push event arrives, via `_onRoomEvent`. Drains every connection's outbox,
  resolves each envelope's target connection, delivers via
  `bot_relay.deliver` on the target's own socket, and posts the outcome back
  via `bot_relay.reply` on the sender's socket.
- Delivery failures are recorded in `_relayFailures` (keyed the same way as
  `BotIdentity.key`) and surface through `botNeedsAttention()`/
  `relayFailureFor()`, so a bot that failed to receive a relayed message gets
  the same red-dot roster badge as any other bot needing attention.

No further backend work is expected for this feature.
