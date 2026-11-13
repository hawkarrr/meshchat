# Offline voice calls: design and feasibility (not implemented)

**Status: design only. Nothing in this document is built.** The app has no call button, no
audio-streaming code and no call signaling. Voice *messages* (recorded clips sent like any other
media) exist and are unrelated to this module.

The goal of this note is to say what a voice-call module would need, what the Bluetooth transport can
and cannot do for it, and what has to be measured on real phones before anybody promises anything.

## 1. What a call needs, and what this transport gives

| Need | Typical requirement | What the BLE mesh offers |
| --- | --- | --- |
| Throughput | 8 to 24 kbit/s for a narrow-band speech codec (Opus), i.e. 1 to 3 KB/s each way | A single BLE link moves a few KB/s in the best case, shared with everything else the phone does. One call fits on a good direct link **in theory**. Real throughput is **not measured** |
| Latency | Under about 150 ms one way to feel like a conversation; 400 ms is unpleasant | Every hop adds a connection-interval wait (7.5 to 30 ms at best, more on many Android stacks), a GATT write, a signature check and a queue. Direct: plausible. Each extra hop adds a similar amount. Three hops is likely beyond what is usable |
| Jitter | Needs a jitter buffer of 40 to 100 ms | BLE links retransmit and stall when a phone's radio is busy (scanning, advertising, other links). Jitter would be large and irregular |
| Loss handling | Tolerates 5 to 10 % loss with concealment | The link layer is reliable and ordered, so a stalled link causes *delay*, not loss. Late audio is useless, so it would have to be dropped on purpose |
| Always-on connection | The call path must stay up for the whole call | The mesh is built around short opportunistic connections and store-and-forward. A call needs the opposite: a stable, chosen path |
| Signaling | Offer, answer, ring, hang up, over the same offline channel | Possible as ordinary signed, sealed control messages. But a ring that arrives minutes later (store-and-forward) is meaningless, so call signaling must not be queued like a message |
| Encryption | Authenticated, encrypted audio | See section 4 |
| Background | A call must keep running with the screen off | A foreground service with a microphone type is needed on Android; iOS needs the VoIP/audio background modes. **Untested** here |

**WebRTC is not a shortcut.** WebRTC assumes an IP network (ICE, STUN/TURN, UDP) and a signaling
channel; none of that exists over BLE. Using its audio engine (Opus, jitter buffer, echo canceller) is
possible, but its transport would have to be replaced, and Bluetooth routing and signaling are not
provided by it.

## 2. Proposed shape, if it is ever built

A separate module, `lib/voice_call/`, that depends on the messaging stack but is not depended on by it.
Removing it must not change any other behavior.

```
voice_call/
  call_signaling.dart    // offer / answer / hang-up control messages (sealed, short-lived)
  call_session.dart      // state machine: idle, ringing, connecting, active, recovering, ended
  audio_pipeline.dart    // microphone -> codec -> frames, frames -> jitter buffer -> speaker
  call_transport.dart    // "real-time lane" over an existing direct link
  call_quality.dart      // measured latency / loss / jitter, shown to the person
```

### 2.1 Signaling

* Control messages are ordinary signed and sealed envelopes (a new content kind), but they carry a
  **very short expiry** (about 20 seconds) and are **never stored for later delivery**. A call offer
  that cannot be delivered now is dropped, and the caller is told "not reachable".
* An offer carries: call id, the caller's ephemeral key, the codec parameters, a timestamp.
* The callee answers with its ephemeral key. Both derive a session key (X25519, then HKDF), so the
  audio does not depend on the long-term keys after setup.
* Hang up, busy, declined and "connection lost" are small control messages. A call that has lost
  contact for more than a few seconds ends; it is never held open for minutes.

### 2.2 Audio

* Opus at 8 to 12 kbit/s, 20 ms frames (about 25 to 30 bytes each), one frame per packet or a few per
  packet. (A speech codec implementation is a plugin or FFI dependency that is **not** in the app today.)
* Frames are sealed with ChaCha20-Poly1305 under the session key, with a counter as nonce and the call id
  and direction as associated data. A replayed or reordered counter is dropped.
* A jitter buffer of 60 to 120 ms. Frames that arrive too late are discarded, not played.

### 2.3 Transport

The existing router is built for store-and-forward: it signs every packet (Ed25519, about 100 bytes of
header and a 64-byte signature) and keeps it queued for hours. That is too heavy and too slow for
20 ms audio frames. A call would need a **real-time lane** over an already established direct link:

* **Direct only at first.** One hop, between two phones that already have a BLE link. No relaying.
* A small frame format on the GATT characteristic, without per-frame signatures: the AEAD tag
  authenticates each frame, and the link itself is already authenticated by the connection handshake.
* No queue and no retry: a frame that cannot be sent in time is skipped.

Multi-hop calls would require every relay to forward frames within a few milliseconds without storing
them, to keep a stable connection chain, and to cope with the link scheduling of each phone. With the
latency of each BLE hop, **a multi-hop call is not expected to be usable**. It should not be promised, and
should only be attempted after direct calls are proven on real phones.

## 3. Connection quality, termination and recovery

* The call shows a measured quality (round-trip time from echo frames, recent loss), not a guess.
* If the link drops, the call goes to "recovering" for a few seconds and tries to reconnect to the same
  neighbour. If that fails it ends, and says so. It does not silently turn into a message.
* Either side can hang up at any time. Hang-up is sent best effort; the other side also ends the call when
  frames stop arriving.

## 4. Security notes

* Audio is encrypted end to end with a session key from an ephemeral key agreement, authenticated by the
  parties' long-term identity keys (the signed offer and answer). This gives forward secrecy for the call
  audio, which messages in this app do not have.
* Relays (if multi-hop were ever allowed) would see who calls whom, when, and how long: call metadata
  cannot be hidden from them.
* A call must not start without a visible, audible ring and an explicit accept: no silent answering.
* The microphone permission and a visible "call in progress" indicator are required; the foreground
  service notification doubles as that indicator on Android.

## 5. What would have to be measured on real phones first

1. The sustained one-way throughput and the round-trip latency of a direct BLE link between two real
   phones, per model, with the screen on and off.
2. How both change while the phones also scan and advertise (they must, to stay discoverable).
3. The behavior of a 12 kbit/s stream for 5 minutes: gaps, longest stall, drift.
4. Battery drain per minute of call.
5. The same on iPhone, which has no peripheral-side connection events or MTU control.

Only if (1) to (3) show a stable link with a worst-case stall well under 200 ms is a direct call worth
building. If they do not, the honest result is: **offline voice calls are deferred, and voice messages
remain the supported way to speak.**

## 6. Decision

* Deferred. Reliable messaging, media transfer, deletion, edits and notifications come first and are
  not changed by this module.
* No call UI is shown anywhere in the app, so nothing implies that calls exist.
* This document is the whole deliverable for the voice-call item of the specification.
