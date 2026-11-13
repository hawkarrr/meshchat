# Security model, threat model and limitations

This document describes what the app does to protect messages, what it deliberately does not do, and
what it cannot do. It is a description of this implementation, **not a certification**: the design and
code have **not been reviewed by an independent cryptographer or security auditor**. Do not describe the
app as "verified end-to-end encrypted", "anonymous", or "secure" without that review.

## 1. What is being protected

| Asset | Where it lives |
| --- | --- |
| Content of private messages, groups and their media | Sealed on the air; plaintext in the phone's SQLite database and media folder |
| Who talks to whom, and when | Visible to relays (see 4) |
| The identity keys (Ed25519 signing, X25519 agreement) | Platform key store (Android Keystore-backed, iOS Keychain) through `flutter_secure_storage` |
| Group keys (one per group and epoch) | The same key store |
| The history, contacts, groups, settings | SQLite file and media folder in the app's private storage |

## 2. Who might attack, and what they can do

| Adversary | Can | Cannot (by design) |
| --- | --- | --- |
| **Passive listener in Bluetooth range** | See that a دەمەتەقێ phone is present, its public key and nickname (sent before the link is authenticated), packet sizes and timing | Read private or group content (sealed). Public-room content is **not** secret |
| **Active nearby attacker** | Inject, alter, drop, replay or re-order packets; connect to a phone | Forge a packet: every packet is Ed25519-signed over its header and payload, and unsigned or badly signed packets are dropped and logged. Replays are discarded by the seen-id filter and by expiry |
| **A relay** (a phone that carries your packet) | See sender key, recipient key, size, time and hop count; refuse to forward; delay it | Read it, alter it undetected, or make it look delivered (only the recipient's signed receipt marks a message delivered) |
| **A group member** | Read everything in the group while they hold the key; write as themselves; forward what they read | Impersonate another member (signatures), delete or edit another member's messages (see 6), read before they joined or after they were removed (a removal rotates the key) |
| **Anyone in a public room** | Read everything, write as any *nickname* | Forge another person's *signing key*; the first characters of the key are shown after the name for that reason |
| **Somebody who has the unlocked phone, or a rooted or malicious app on it** | Read everything | Nothing is protected against this: stored chats and files have no encryption of their own |
| **A flooding phone** | Try to exhaust CPU, storage or the queue | Per-neighbour and per-author rate limits, size and count caps, a bounded queue and a strike system that drops the link |
| **A phone with a wrong clock** | Make its messages look early or expired to others | Order history (ordering uses the receiver's own clock); keep a public message longer than six hours |

## 3. Cryptography

All primitives come from established libraries (`cryptography`); nothing is invented here. HPKE is
implemented in this project from RFC 9180 and is checked against the published test vector.

* **Identity.** On first start the phone creates an Ed25519 signing key (its identity, shown as a short
  id) and an independent X25519 key for receiving. There are no accounts, phone numbers or servers.
* **Every packet** is signed with the sender's Ed25519 key over the header (type, hop-independent fields,
  recipient, timestamps) and the payload. A relay can change only the hop counter, which the signature
  does not cover; everything else is protected.
* **Private chat**: RFC 9180 HPKE, Base mode (DHKEM(X25519, HKDF-SHA256), HKDF-SHA256, ChaCha20-Poly1305)
  to the recipient's X25519 key, with the packet header as associated data. One fresh ephemeral key per
  message.
* **Group**: ChaCha20-Poly1305 under a 256-bit group key per *epoch*, bound to the packet header. A
  membership change creates a new epoch and a new key, sent sealed to each remaining member.
* **Public room**: signed, **not encrypted**.
* **Media**: the manifest (size, chunk count, SHA-256) is an ordinary message; the chunks are sealed
  (private: a per-file key inside the sealed manifest; group: derived from the group key and the file id;
  room: plain but signed). The receiver keeps a file only if its length and SHA-256 match the manifest.
* **Edit and delete requests** are ordinary messages of the conversation, so they get exactly the same
  sealing and signing (see 6).

**Forward secrecy:** none beyond the per-message ephemeral key of HPKE. A stolen long-term X25519 key
decrypts captured private messages; a leaked group key decrypts that epoch. **Deniability:** none (messages
are signed).

## 4. Metadata the design cannot hide

* **Presence.** The advertisement carries only the app's service UUID, but anyone nearby can see that
  a دەمەتەقێ phone is there and connect. The first thing exchanged on a connection, before authentication,
  is the phone's public key and nickname, so a long-lived key lets an observer recognise the same phone
  in different places. "Reset identity" creates a new one.
* **Relays see** sender key, recipient key (or group/room id), approximate size and time, hop count.
* **Relaying is a choice.** Settings > Chats and Bluetooth > "Help relay messages for others" turns carrying other people's
  packets off. Nothing else changes: the phone still receives what is for it and sends its own.
* **Names are not identities.** Anyone can pick any nickname.

## 5. Verifying a contact

The first meeting is "trust on first use": nothing proves that a key belongs to the person. Each contact
page shows a safety number derived from both phones' keys; compare it in person or over a channel you
trust, then mark the contact verified. A changed key revokes the verification and writes a security-log
entry.

## 6. Deleting, editing, pinning, forwarding: who may do what

| Action | Who | Enforced by |
| --- | --- | --- |
| Delete for me | The person, on their own phone | Local only; nobody is told |
| Delete for everyone | The author of the message; in a group also the group's admin. Within 48 hours | Sender: checked before sending. **Receivers check again**, whatever the request says |
| Edit | The author, text messages only, within 48 hours | Same: the receiver accepts an edit only from the message's author, only for text, only if its version is newer |
| Pin | Anyone, for themselves | Pins are personal: never sent, never visible to anybody else |
| Reply | Anyone | The reply carries only the id of the original; what is quoted is looked up locally, so a reply cannot make a phone show content from another conversation |
| Forward | Anyone | A forward is a brand-new message that carries the text/media and the name of the first author. It carries no keys and nothing else from the original conversation |

What a receiver does with a request that is not allowed (a delete for a message the sender did not write,
an edit of somebody else's text, a request naming a message of another conversation): it is **ignored**,
nothing changes, and a **security-log entry** ("Someone tried to change a message that is not theirs") is
written.

**What deletion can and cannot do.** A delete-for-everyone is a *request*. It removes the message (and
its file) from every phone that receives it. It cannot reach a phone that is out of range (it waits, and is
retried for up to its lifetime, then reported as expired), and it cannot erase a screenshot, a photo of the
screen, a saved-to-gallery copy, a forwarded copy somebody else sent on, or a backup. The app says so in
the confirmation, shows "waiting for X's phone" while a request is pending, and shows "X's phone did not
get the request" if it ran out of time. It never claims an offline phone has received it.

**Removed messages do not come back.** The phone keeps, for 48 hours (longer than a packet can live), a
minimal record of every removed message's id and why it went (no text, no media, nobody's name beyond who
asked). A late copy arriving during synchronisation is refused. An edit that arrives before its message is
kept and applied when the message shows up; one for a removed message is refused.

**What other phones can make this phone remember is limited.** Edits that arrive before their message are
kept to the newest 500 (`Protocol.maxPendingEdits`), and the memos of deletions that other phones asked for
(for messages that have not arrived) to the newest 5,000 (`maxRemoteDeletionRecords`); beyond that the oldest
go first. A member of a group could otherwise fill the table with edits and deletion requests for messages
that do not exist. The cost of the limit is that a flood can push out a genuine memo, and a message deleted
for everyone could then arrive and be shown. Deletions made on this phone are never trimmed.

## 7. Public chats and the six-hour rule

Public messages are removed from the phone six hours after *this phone* sent or received them, on this
phone's clock. The rule touches only public-room messages. It is a privacy convenience, **not a security
feature**: anyone who read a public message, or whose phone has not cleaned yet, still has it.

## 8. Notifications

Notifications are made on the phone from messages that were already received, verified and saved. A phone
that only relays a packet never shows one. The person chooses what a notification shows:

1. name and message,
2. name only ("New message") - the default,
3. nothing but "You have a new message".

The lock screen visibility is set to *private*, so the system's own setting for sensitive content also
applies. Public rooms do not notify unless asked. A message that could not be decrypted never produces a
notification. A notification is taken back when the message it was about is deleted or expires. Notifications go through the operating system's local notification service only: no push
server, no internet.

## 9. Local data

* The SQLite database and the media files are in the app's private storage, **without encryption of their
  own**; they rely on the phone's screen lock and disk encryption. Full-database encryption (SQLCipher) was
  **not** adopted: it would need a native dependency that has not been verified with this toolchain, and it
  would not protect against a person who can unlock the phone.
* Android backup and device-to-device transfer are disabled in the manifest. On iPhone the app's folder is in
  Application Support, which `AppDelegate.swift` marks as excluded from iCloud and computer backups at every start
  (written 2026-11-09, never run on an iPhone).
* "Delete all local data" removes messages, files, contacts, groups, rooms, keys and settings after a typed
  confirmation.
* There is **no database export or backup feature**. If one is ever added it must be an explicit action,
  encrypted with a key the person chooses.
* Saving a picture or video to the gallery is an explicit action with an explanation: the copy leaves the
  app's private storage and is visible to other apps.

## 10. Hardening

Low-order and all-zero keys are rejected; incoming sizes, chunk counts, queue lengths, link counts and room
counts are capped; nicknames, group names and room names are stripped of control, zero-width and
bidirectional-override characters; chunks that fail their checksum or claim impossible sizes are discarded;
videos arriving in a public room are ignored and logged; keys, secrets and message text are never written to
the log (the in-app log is memory only); the app declares no internet permission in release builds.

## 11. Known limitations and residual risks

* No independent review. Do not rely on the app for anything where a failure could hurt someone.
* Plaintext at rest (see 9).
* Metadata visible to nearby phones and relays (see 4).
* Trust on first use until a safety number is compared.
* A relay can delay, drop or refuse to carry a message; reaching someone depends on a connected chain of
  phones and on radio conditions. No range or delivery guarantee is made.
* Background operation depends on the operating system (see `docs/delivery-and-routing.md`, section 6).
  The behavior on real phones has **not been tested yet**.

## 12. What the automated tests check (all simulated)

Forged signatures, tampered ciphertext, replays, duplicate delivery, a misdirected or wrong-sender
receipt, group messages by non-members, unauthorized delete and edit requests (private, group and room),
removed messages not returning, public-room cleanup limits, relays that cannot read content, notification
rules (recipient only, privacy levels, public rooms off by default, no notice for unreadable messages),
oversized and malformed envelopes (including random garbage and truncation), corrupted media. None of this
replaces testing on real phones and review by a specialist.
