# Bluetooth mesh protocol specification (protocol version 3)

This describes what travels between phones. The source of truth is `lib/protocol/` and the tests in
`test/protocol/`. All integers are big-endian.

**Version.** `Protocol.version = 3`. Version 2 added groups, rooms and media; version 3 added replies,
forwards, edits, deletion requests and videos. Version 3 has not been released: a phone that does not know a
content kind rejects it as malformed (and logs it), so mixed versions should not be expected to work.

## 1. Transport: one GATT characteristic

Every phone advertises one GATT service (`7f0c1a2e-5d3b-4c8a-9e61-2b4d8f3a6c10`) with one characteristic
(`...6c11`) that supports write (the connecting side sends) and notify (the hosting side sends). The
advertisement carries only the service UUID. Every phone is both a peripheral (advertises, hosts) and a
central (scans, connects out).

### 1.1 Link frames

A *link frame* never leaves the link. The first byte is the type:

| Type | Code | Meaning |
| --- | --- | --- |
| HELLO | 0x01 | The sender's public keys, a random challenge and its nickname |
| AUTH | 0x02 | Ed25519 signature over both challenges and both identities: proves the sender holds the key it claimed |
| PING / PONG | 0x10 / 0x11 | Keepalive; idle links are dropped after 45 s of silence |
| BYE | 0x1f | Polite close with a reason |
| PACKET | 0x20 | One serialized mesh packet |

**Versions.** The first byte of a HELLO's body is the protocol version (now 3), and it must stay the first
byte in every future version: a phone reads only that byte from a HELLO in a version it does not speak,
answers with BYE (reason `protocolError`; BYE never changes), remembers the other phone for ten minutes (it is
not called again meanwhile) and tells the person which of the two needs an update. A future version that can
still talk to version 3 should keep sending a version-3 HELLO and announce what more it can do in the HELLO's
`capabilities` byte (0 today), switching up only when both phones set the same bit.

Each frame is cut into **fragments** that fit one ATT write (MTU minus 3), with a 6-byte header (frame id,
index, count), and reassembled with size caps (`maxFrameBytes`). Nothing but HELLO and AUTH is accepted on a
link until AUTH succeeded. Handshakes time out after 10 s and the number of unauthenticated links is
capped. If two phones connect to each other at once, the pair keeps one link (the one whose connecting side
has the numerically smaller identity key).

## 2. Mesh packet

```
off  size  field
  0     1  protocolVersion
  1     1  type
  2     1  flags            bit 0 = the payload is a media chunk; other bits must be 0
  3     1  hopLimit         SIGNED   maximum relays the sender allows (never trusted above 7)
  4     1  hops             NOT signed: each relay increments it
  5    16  messageId        random; the duplicate-detection key and the message's stable id
 21     8  timestampMs      sender's clock; advisory only
 29     8  expiresAtMs      sender's clock; every receiver clamps it to its own maximum
 37    32  senderPublicKey  Ed25519 identity key
 69    32  recipient        a person's key (direct, ack); the group id or room id (group, room); zeros for announcements
101     2  payloadLength    at most 2048
103     N  payload          type-specific; sealed for direct and group
103+N  64  signature        Ed25519 over a domain-separated encoding of every field above except hops
```

Total size is at most 103 + 2048 + 64 bytes. A relay can change **only** `hops`.

### 2.1 Packet types

| Type | Code | Payload | Hop limit | Lifetime | Delivery class |
| --- | --- | --- | --- | --- | --- |
| announce | 1 | X25519 key and nickname | 3 | 2 min | Flooded once, never stored |
| direct | 2 | HPKE-sealed envelope, or a sealed media chunk | 5 | 12 h | Directed (one recipient) |
| ack | 4 | up to 16 message ids | 5 | 2 h | Directed back to the sender |
| group | 5 | AEAD-sealed envelope or media chunk | 5 | 12 h | Persistent flood |
| room | 6 | signed plaintext envelope or media chunk | 5 | 2 h | Persistent flood |
| roomAnnounce | 7 | a signed room record | 4 | 5 min | Flooded once when it is news |

A node never keeps any packet longer than 24 h whatever its sender wrote, and carries somebody else's
directed packet for at most 4 h and a flooded packet for at most 12 h.

### 2.2 Acknowledgement payload

`u8 status (0 = delivered) | u8 count | messageId[16] x count`, at most 16 ids. A receipt is signed by the
**recipient** and is the only thing that marks a private message delivered. One receipt can confirm the
many chunk packets of a file.

## 3. Message envelopes (the plaintext inside direct, group and room packets)

The first byte is the *content kind*:

| Kind | Code | Meaning |
| --- | --- | --- |
| text | 1 | A text message |
| image | 2 | Manifest of a picture |
| voice | 3 | Manifest of a voice message |
| video | 4 | Manifest of a video |
| groupInvite / groupUpdate | 10 / 11 | Group snapshot, sent sealed to each member by the admin |
| groupRemoved / groupLeave | 12 / 13 | Group membership notices |
| edit | 20 | "Replace the text of my earlier message" |
| delete | 21 | "Remove these messages" |

```
text:        u8 1   [u8 nickLen nick]  links  u16 len  text
image:       u8 2   [nick] links mediaId[16] u8 mime u32 byteLength u16 chunkCount sha256[32]
                    u8 hasKey [key[32]]  u16 width u16 height  u16 captionLen caption
voice:       u8 3   [nick] links mediaId u8 mime u32 byteLength u16 chunkCount sha256 u8 hasKey [key]
                    u32 durationMs u8 waveformLen waveform  u16 captionLen caption
video:       u8 4   [nick] links mediaId u8 mime u32 byteLength u16 chunkCount sha256 u8 hasKey [key]
                    u16 width u16 height u32 durationMs  u16 captionLen caption
edit:        u8 20  targetId[16] u64 version u16 len text
delete:      u8 21  u8 count targetId[16] x count            (1 to 16 ids)
links:       u8 flags (bit 0 = reply, bit 1 = forwarded) [replyTo[16]] [u8 len forwardedFromName]
```

* `[nick]` is present in group and room messages only (the reader may never have met the author).
* **Replies** carry only the 16-byte id of the original. The reader looks the original up in its own
  database, in the same conversation; nothing of it travels.
* **Forwards** carry the name of the first author. A forward is a new message with a new id.
* **Edits** carry the author's clock in milliseconds as `version`. A receiver applies an edit only if its
  version is greater than the one it has.
* Text is at most 1000 bytes of UTF-8; captions at most 200; nicknames and names at most 32.

Every field that comes from the network is bounds- and range-checked. Trailing bytes other than zero
padding are rejected. Unknown content kinds, invalid UTF-8, flags that are not defined, a forwarded name of
length 0 and similar all raise a format error, never anything else (tested with truncation and random
garbage).

### 3.1 Sealing

* **direct:** RFC 9180 HPKE (Base; DHKEM(X25519, HKDF-SHA256), HKDF-SHA256, ChaCha20-Poly1305) to the
  recipient's X25519 key; the packet header is the associated data.
* **group:** ChaCha20-Poly1305 under the group key of the epoch named in the packet; header bound as
  associated data.
* **room:** not sealed; the Ed25519 signature authenticates author and content.

## 4. Media: manifest and chunks

A picture, voice message or video is a **manifest** (an ordinary message carrying size, chunk count,
SHA-256, and for private chats the key) followed by **chunk packets**.

| Kind | Largest object | Chunks | MIME code |
| --- | --- | --- | --- |
| image (JPEG) | 64 KB | at most 43 | 1 |
| voice (AAC in .m4a) | 64 KB, at most 30 s | at most 43 | 2 |
| video (MP4) | **512 KB** | at most 342 (cap 352) | 3 |

A chunk packet has the chunk flag set and the payload `mediaId[16] | u16 index | u16 count | body`, where
`body` is at most 1536 media bytes plus the nonce and tag when sealed. Private chunks are sealed under a
fresh per-file key that travels inside the sealed manifest; group chunks under a key derived from the group
key and the media id; room chunks are plain but signed. **Videos are never sent to public rooms**: a phone
that receives a video manifest in a room ignores it and logs it.

The receiver keeps a file **only** if its length and SHA-256 match the manifest. Anything else is discarded
and logged. Chunks that arrive before their manifest are held in a bounded number (400). An incomplete file
is abandoned after 12 h, or at once when its message is removed.

**Resuming.** In a private chat every chunk is acknowledged; the sender keeps the unacknowledged chunks
(`outgoing_parts`) and offers them again after each reconnection (the queue is persistent). A transfer cut
by Bluetooth being turned off, a phone going out of range, or the app being closed continues from where it
stopped. In a group the chunks are flooded (persistent) and there is no per-chunk receipt, so a member who
lacks a chunk relies on another phone still carrying it. **There is no explicit "please resend chunk n"
request** in this version.

## 5. Control events

An edit or delete request is a normal envelope in the same conversation, so it is sealed or signed like any
message and reaches the same phones.

* The sender checks permission before sending (author; the group admin for delete; 48 h). One request names
  at most 16 messages; a bigger selection goes out as several requests, **one at a time**: each is queued and
  its messages are removed here right after, so if a later one cannot be queued, what was asked is gone here
  and the rest is still shown.
* The receiver checks again and **ignores** anything not allowed: wrong author, a message of another
  conversation, a non-text message for an edit, an older version. A refusal is written to the security log.
* A delete for a message that has not arrived yet is remembered (with who asked) and applied if the
  message shows up from its author.
* A delete request from a **private** chat is acknowledged by the recipient like any direct message; that
  receipt is what moves it from `sent` to `delivered`. In groups and rooms there is no single recipient, so
  the request stays at `sent` and is reported as expired if its lifetime runs out.

## 6. Other payloads

* **announce:** `agreementKey[32] | u8 nickLen | nick`. The signature binds the X25519 key and the
  nickname to the Ed25519 identity. An all-zero agreement key is rejected.
* **room record:** name, description, creator, creation, expiry and version, signed by the creator. The room
  id is derived from the creator's key, so nobody can claim someone else's room.
* **group snapshot:** group id, epoch, key, name, admin, members (key and nickname). Accepted only from the
  admin and only if the receiver is listed.

## 7. Validation order for a received packet

1. Per-neighbour rate limit. 2. Structural decode (sizes, version, flags, type). 3. Expiry (with a 5-minute
tolerance). 4. Duplicate check against the persistent seen-set. 5. Per-author rate limit. 6. Ed25519
signature. 7. Mark as seen (a forged packet is **not** marked, so it cannot suppress the genuine one).
8. Act: deliver locally and/or carry for others (if relaying is on).

## 8. Limits (enforced on send and on receive)

| Limit | Value |
| --- | --- |
| Payload | 2048 bytes |
| Hop limit accepted | at most 7 (5 for messages, 3 for presence, 4 for room records) |
| Text / caption / nickname / name | 1000 / 200 / 32 bytes |
| Delete batch | 16 ids |
| Group size | 12 including the admin |
| Picture or voice object | 64 KB |
| Video | 512 KB (the sender can lower their own limit to 128 or 256 KB; default 256 KB) |
| Relay allowance per author | 360 packets directed, 400 flooded |
| Receive burst | 400 packets, then 40 per second per link; 400 then 25 per second per author |

These numbers are protocol and queue constants, not measurements. Real throughput over Bluetooth is not
measured; a 512 KB video can take minutes per hop.
