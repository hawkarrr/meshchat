# Message routing and delivery states

## 1. Delivery states

The specification names five states: `saved`, `queued`, `relayed`, `delivered`, `failed`. This app stores
**what is actually known**, and the names it shows are close to those, with one honest difference.

| Specification | Stored as `messages.status` | Shown as | Meaning here | What it does **not** mean |
| --- | --- | --- | --- | --- |
| saved | `queued` (row written, nothing sent yet) | **Pending** (clock icon) | The message is in the database and in the outgoing queue. It survives a restart. No neighbour has it yet | Nothing was transmitted |
| queued | `queued` | **Pending** | Waiting for a route: nobody that can carry it is in range | Not "on its way" |
| relayed | `sent` | **Sent** (one tick) | Handed to at least one neighbour. That neighbour may be the recipient or a relay: the app cannot tell which, because it learns only from receipts | **Not** delivered. The neighbour may carry it for hours, or never reach the recipient |
| delivered | `delivered` | **Delivered** (two ticks), with the number of hops the receipt travelled | The recipient's **signed receipt** arrived. In a group: every other member's | A relay having it, or the message being saved anywhere else, never marks it delivered |
| failed | `failed` | **Not delivered**, with a reason and a "Send again" action | Its lifetime (12 h; 2 h for public rooms) ran out, or retries were exhausted, without a receipt | It may still have reached the recipient: if the receipt was lost, a "send again" can create a duplicate that the recipient's duplicate filter refuses |

Incoming messages are `received`, or `undecryptable` (correctly signed and addressed to us, but it could not
be opened: tampered, corrupted or for another key; it is **never shown as chat text**, and goes to the
security log). A public room has no receipts, so a post is **Sent** at most.

Transitions only move forward (`queued -> sent -> delivered`; `queued | sent -> failed`; `failed -> queued`
when sent again), so a late "sent" event can never overwrite "delivered" (tested).

### Pictures, voice messages and videos

A media message is `delivered` only when **every part** (manifest and all chunks) has been acknowledged by
the recipient, i.e. when the recipient has assembled and verified the whole file. The receiver's copy is
marked ready only after the length and SHA-256 check passes and the file is saved.

### Delete requests ("delete for everyone") of this phone's own messages

| `deletion_events.state` | Shown (private chats) | Means |
| --- | --- | --- |
| `queued` | "Waiting for X's phone to confirm..." | The request is queued; no neighbour has it |
| `sent` | the same | Handed to a neighbour; no confirmation yet |
| `delivered` | nothing (it is done) | X's phone confirmed with a signed receipt |
| `expired` | "X's phone did not get N delete requests in time; they may still be there" | The request's lifetime ran out |

In groups and rooms there is no single recipient to confirm, so the request stays `sent` until it expires;
the app says "Deleted here. Other phones remove it when they receive the request." and never claims more.

## 2. Routing

There is no routing protocol in BLE. The mesh builds one from signed announcements.

* Each phone **announces** itself every ~30 s (key, nickname) and on changes, hop limit 3, lifetime 2 min.
  A phone that receives an announcement through a connected neighbour records "destination D is reachable
  through neighbour N, k relays away". That entry is believed for **about 100 seconds** and is not persisted.
* A peer is shown as **Directly connected** only with an authenticated link, as **Via relay (n hops)** only
  with such a fresh route, and otherwise as **Offline**.
* Packets are **directed** or **persistently flooded**.

### Directed (private messages and receipts)

Order of preference for each attempt: the direct link to the recipient; else the learned route through the
neighbour that announced them; else up to 4 neighbours. A neighbour is not sent the same packet again within
a cool-down (30 s for own packets, 5 min for relayed ones), and at most 3 times in all. Retries back off
exponentially from 10 s to 15 min with jitter; a changed route or a new neighbour nudges the queue at once.

### Persistent flood (group and room packets)

There is no single recipient, so each packet is offered **once to every neighbour** and then **kept until it
expires**. A phone that was away receives the packets when it next meets any phone that still has them
(store, carry and forward). These packets have their own storage quotas (per author and in total) and eviction, so
they cannot push private messages out of the queue.

### Safeguards

* **Duplicates:** every packet's id goes into a persistent seen-set (until its expiry); a duplicate never
  creates a second chat entry, however many paths it took.
* **Loops:** hop limit (at most 5 for messages; the receiver accepts at most 7 whatever is claimed) and the
  seen-set.
* **Expiry:** every packet has a lifetime; a node clamps what the sender wrote (maximum 24 h, 4 h or 12 h for
  carried packets).
* **Floods:** per-link and per-author token buckets; a flood is dropped and logged; a neighbour that sends
  too many invalid packets within a minute is disconnected.
* **Order of sending:** receipts, then private messages, then group and room messages, then media chunks.

## 3. Relay participation

Settings > Chats and Bluetooth > **"Help relay messages for others"** (on by default).

* **On:** the phone carries sealed packets for other people. It never opens them and never shows a
  notification for them.
* **Off:** the phone still *receives* everything addressed to it, to its groups and to the rooms it has
  joined, and still sends its own messages. It carries **nothing** for anybody else: no directed packets,
  no group or room packets for others, no forwarding of announcements. People who relied on it to reach
  each other will not get through; the settings say so.

The switch is stored and applied from start-up (`MeshRouter.relayForOthers`). A counter of refused packets
is kept for the diagnostics screen. This is tested with simulated phones (a line of three: with relaying off
in the middle, nothing passes; its own messages and those for it still work; switching it back on lets the next
message through).

## 4. Offline operation versus reachability

The app never needs the internet. The header shows two separate facts: **"Offline / Internet on, not used"**
(about the internet) and **how many phones are reachable** over Bluetooth (about the mesh). A message can be
**saved locally without being delivered**: that is exactly the "Pending" state, and the chat says so
("Not reachable right now. Messages wait on this phone and are sent as soon as this person, or a phone that
can reach them, comes into range, for up to 12 hours").

No range, speed or delivery guarantee is made. Delivery depends on a connected chain of phones within radio
range of each other at the same time, and on how busy each phone's radio is.

## 5. Time and clocks

* **Order** of messages in a chat uses the *receiving* phone's own time (`sort_time`). The sender's clock
  (`claimed_time`) is advisory; if it differs by more than 10 minutes the details page says so.
* **Expiry** uses each phone's own clock. A phone whose clock is wrong can see a packet as already expired or
  too early; a tolerance of 5 minutes is applied. The six-hour cleanup of public chats is counted from when
  *this* phone sent or received the message, so another phone's clock cannot extend or shorten it.
* **Edits** use the author's clock in milliseconds as a version; a newer version wins, an older or repeated
  one is ignored.
* A phone that stayed **offline for a long time** removes everything overdue (public messages, deletion
  records, old pending edits) the first time the app starts, before showing anything; it never shows an
  expired public message after the first screen.

## 6. Background behavior (what the platforms allow)

These are the cases the specification asks to be told apart. **None of them has been verified on a real
phone yet**; the descriptions come from platform documentation and the code. See
`real-device-test-plan.md`.

| Situation | What happens | Can the app receive and notify? |
| --- | --- | --- |
| **Chat screen closed**, app still on the home screen of the app | Networking is app-wide, not per screen. Nothing changes | Yes |
| **App in the background**, screen on or off | The process is alive for a while. Android limits what background apps may do (Doze, App Standby, background scan limits, OEM battery managers); BLE connections and the GATT server may keep working for some time and may be stopped at any time. **With "Keep the mesh running in the background" on (Android only), a foreground service with a visible notification asks Android to keep the process alive** | Possibly, for a while. With the service: more likely. Not guaranteed |
| **Process suspended / frozen** (cached app) | Android 11+ can freeze cached processes; a foreground service is exempt | Not without the service |
| **Swiped away from Recents, process still alive** (the background service is on) | Since 2026-11-09 the Flutter engine outlives the screen, so the mesh keeps running and the notification is true. **Untested on a phone** | Expected yes |
| **Process terminated** (swiped away on phones that kill the process, killed for memory) | Nothing runs. The foreground service is not restarted by the system (`START_NOT_STICKY`): the person must open the app again | **No** |
| **Android force-stop** (Settings > Force stop) | The system stops every component of the app and will not start any of them until the person opens the app | **No**. The app does not promise it |
| **Bluetooth turned off** | The radio is gone. Messages stay queued; the screen says "Bluetooth off" | No; resumes when Bluetooth is back |
| **Permission denied** (Bluetooth, notifications) | Without Bluetooth permission nothing can start (the app explains and offers the settings). Without notification permission messages still arrive and are counted, but no notification is shown | See left |
| **iPhone** | The app has **no background Bluetooth mode configured** and no iOS native code. iOS suspends it soon after it leaves the screen, and then it neither receives nor relays, and cannot notify. iOS gives no guarantee of continuous background BLE even when the modes are declared | **No** (not attempted) |

What the app does about it: a message **received** while the app runs is saved first and then notified (if the
app is not on screen). A message that **cannot be received** while the app is not running is not lost: the
sender keeps it queued (up to 12 h) and offers it again when the phones meet again.

The app does not ask Android to exempt it from battery optimisation (it would be a store-policy risk, and a
person should choose that); the settings explain that some phones stop background Bluetooth work aggressively.
