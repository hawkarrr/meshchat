# دەمەتەقێ (Damatqe)

An offline, peer-to-peer messenger for Android and iOS, written in Flutter/Dart. Phones that are near
each other find each other over Bluetooth Low Energy (BLE) and exchange **private chats, group chats
and public rooms**, with **pictures, voice messages and very short videos**, and pass messages along
through other phones to reach people who are out of direct range. You can reply to, edit, forward, pin,
search and delete messages (also for everyone, as a request that waits for phones that are out of
range), and public rooms clean themselves every six hours. There is no internet use, no account, no
server and no extra hardware. The only native code is one small Android foreground service in Kotlin
(optional, off by default); there is no Swift, and everything else comes from Flutter plugins.

**Languages: Kurdish (Central Kurdish / Sorani, the main one), Arabic and English.** The app opens in
Kurdish, right to left; the first-run page and Settings have a language picker. See
[docs/localization.md](docs/localization.md), including what has not been checked (the wording has not
been reviewed by a native speaker; nothing has been seen on a real phone).

**The name is دەمەتەقێ** (Damatqe in Latin letters, `AppInfo.name` / `AppInfo.latinName`). It is the launcher
label on Android and iOS, the title of every notification, and the name inside every sentence of the
app, also the English ones. The Dart package is still called `offline_mesh_chat`, and so is the Android
application id, so nothing about installs or builds had to change with the name. The specification an
earlier version followed calls the app "GhostChat" with a ghost theme; the app kept its own name and
gained a drawn ghost. See [docs/feature-status.md](docs/feature-status.md).

The look was redone in October 2026: a Telegram-inspired interface (dark or, since November 2026, light: a sun / moon button and Settings > Appearance switch it) with a floating bottom bar,
the public room as the first place, a Settings menu with a page for each subject, and Kurdish and
Arabic set in a bundled font. [docs/ui-design.md](docs/ui-design.md) describes it and what was and was
not checked.

> **Read this first: what has and has not been verified.**
> Everything below the radio (protocol, encryption, database, routing, relaying, groups, public
> rooms, pictures, voice and video, deletion, editing, notifications policy, cleanup, and every
> screen) is covered by **1,295 automated tests** (in the last complete run, 1,293 passed; the two that did not are named under "Automated tests"). **All of them
> are simulated:** the Bluetooth radio, the clocks, the notification service, the permissions, the
> camera, the gallery and the background service are replaced by test doubles. **No test in this
> repository has run on real Bluetooth hardware or on a real phone.**
> Whether two real phones connect, how fast pictures, voice messages and videos cross a real link,
> how well relaying works, and whether **notifications and background relaying work with the screen
> locked or the app closed**, has to be confirmed with the in-app **Bluetooth self-test** and
> [docs/real-device-test-plan.md](docs/real-device-test-plan.md). Treat multi-hop relaying, media
> transfer and everything in the background as experimental until you have run it on three phones.
> **iPhone is not supported yet**: the app has never been built for iOS, has no background mode and no
> Swift code. The encryption has not been independently audited, and the database and files are not
> encrypted at rest. [What the transport and the platforms limit](#what-bluetooth-and-the-platforms-limit)
> and the [feature-status report](docs/feature-status.md) list every known limit in one place.

## Contents

1. [What the app does](#what-the-app-does)
2. [Status](#status)
3. [Quick start](#quick-start)
4. [Permissions: what is asked, when, and why](#permissions-what-is-asked-when-and-why)
5. [Dependencies and why](#dependencies-and-why)
6. [How it works](#how-it-works)
7. [Local storage: what is kept on the phone](#local-storage-what-is-kept-on-the-phone)
8. [Security model](#security-model)
9. [Privacy defaults and their limits](#privacy-defaults-and-their-limits)
10. [What Bluetooth and the platforms limit](#what-bluetooth-and-the-platforms-limit)
11. [Automated tests](#automated-tests)
12. [Testing on real phones](#testing-on-real-phones)
13. [Troubleshooting](#troubleshooting)
14. [Look and feel, icon, screenshots](#look-and-feel-icon-screenshots)
15. [Project layout](#project-layout)
16. [Documentation](#documentation)

## What the app does

A floating bar at the bottom with four places, each an icon and a word: **Public** (a globe), **Private**
(a lock), **Groups** (people) and **Settings** (a gear). The app opens on **Public**: the built-in `#mesh`
room as a chat, with its messages as bubbles and a field. In Kurdish and Arabic, which read right to
left, Public is the rightmost item. The three chat items show the number of unread messages. The
private and group lists have a header with a line that says how many phones are nearby and how many are
only reachable through other phones, and a one-word "Offline" badge. There are no stories and no calls
(calls exist only as a [design document](docs/voice-calls-design.md)), so the bar has no items for them.

| | Private | Groups | Public |
| --- | --- | --- | --- |
| For | One person | Up to 12 people you invite | Everybody nearby |
| Text, pictures, voice | yes | yes | yes |
| Short videos | yes | yes | no (every phone in range would have to carry it) |
| Who can read it | Only the recipient | Only the members | **Anyone** who receives it. Not private |
| Delivery state shown | Pending, Sent, Delivered | Sent n/m, then Delivered once every member confirmed | Sent (nobody can confirm receipt) |
| Created by | Tapping a nearby person | The "New group" button: name, pick people, they get an invitation | The built-in **#mesh**, or the "New public room" button. Nearby phones discover rooms by themselves |

**Message actions** (press and hold a message): reply (with a quote that jumps to the original), copy,
forward (with the name of the first author; forwarding a private message into a public room asks
first), **edit** your own text for 48 hours, **pin** (a personal pin with a banner and a list), **select**
several messages (select all, copy, forward, pin, share, save, delete), share, save a picture or video
to the gallery (after saying what that means), message details (who, their clock and this phone's time,
status, route, expiry) and **delete**. *Delete for me* removes it from this phone only. *Delete for
everyone* (your own messages, or any message if you are a group's admin, for 48 hours) removes it here
at once and sends a request that every other phone obeys when it receives it: a phone that is out of
range gets it later, the chat says "waiting for Bob's phone" until it is confirmed, and says plainly
that screenshots and saved copies cannot be reached. A deleted message leaves **no placeholder** anywhere,
and a reply that quoted it shows no content. Search inside a chat finds text and captions and can be
narrowed to pictures, videos, voice or your own messages. Public-room messages disappear from the phone
**six hours after they arrive** (a note says so on the room); private chats and groups are never touched.

Also: search across private chats, groups and people (and inside any chat or room); unread counts on every tab and row; invitations
you can accept or decline; a group admin who adds and removes people (every change gives the group a
new key); contact verification with safety numbers; image previews with captions; voice messages with
a waveform, play/pause, seeking and speed control; a public room laid out like a group chat (the room's
name at the top, which opens the list of rooms; how the phone is connected and how many phones are
around; the messages as bubbles with the writer's name and the first characters of their id; a skeleton
while they load, the ghost when there are none, an error with a Try again button if they cannot be
read; a field with a paperclip and a microphone); empty states that say what to do; and plain-language explanations when Bluetooth or a permission is the
problem.

## Status

| Area | State |
| --- | --- |
| Message format, framing, fragmentation, size limits | Implemented, unit tested |
| Private messages: HPKE (RFC 9180) + Ed25519 signatures | Implemented, tested (HPKE checked against the RFC vectors). **Not audited** |
| Groups: random group key, key change on every membership change, sealed invitations, admin-only changes | Implemented, tested in simulation |
| Public rooms: discovery by signed announcements, signed messages, expiry | Implemented, tested in simulation |
| Pictures and voice: chunked, checksummed, per-conversation keys | Implemented, tested in simulation. **Throughput on real links unknown** |
| Identity, safety numbers, contact verification | Implemented, tested |
| SQLite storage (schema v3, migrations from v1 and v2), persistent outbox, duplicate filter, expiry, retries, rate limits | Implemented, tested, including restart persistence and both migrations |
| Mesh routing: route learning, flooding fan-out, store-carry-forward for group/room traffic, hop limits, batched acks | Implemented. Tested on in-memory and simulated-BLE networks. **Not yet tested on real phones** |
| BLE link layer: discovery, connect, handshake, keepalive, reconnect, duplicate-link handling | Implemented. Tested against a strict simulation of the plugin. **Not yet tested on real phones** |
| Plugin glue (`PluginBleRadio`) | Implemented around the real `bluetooth_low_energy` API. Tested against a simulation that reproduces the plugin's documented quirks and records any contract violation. **Not yet tested on real phones** |
| Permissions: in-app explanation first, then the system prompt | Implemented, widget tested with fake permission services (granted, refused, switched off for good, restricted) |
| UI: the four places of the bar (public room, private chats, groups, the settings menu and its pages), chats, groups, rooms, people, nearby, self-test, security log, first run | Implemented, widget tested on phone, smallest-phone, tablet and large-text sizes. Keyboard responsiveness has a regression test |
| Languages: Kurdish (Sorani, main), Arabic, English; right-to-left layouts; language picker on the first page and in Settings | Implemented. The three message files are kept in step by tests, and nearly every screen is walked through in Kurdish and Arabic at 320 px and large text. **The Kurdish and Arabic wording is not reviewed by a native speaker, and no real phone has shown it** (fonts, keyboard): [docs/localization.md](docs/localization.md) |
| Appearance: light, dark or follow the phone; the circular reveal; the choice kept | Implemented. Widget tested (the reveal, both directions, the phone going light or dark, the open page and a typed draft surviving a switch, Kurdish and Arabic) and screenshot-checked in both appearances. **Not seen on a real phone** ([docs/ui-design.md](docs/ui-design.md), section 3a) |
| Android build | Debug and release APKs build (see [Quick start](#quick-start)); the release APK has no `INTERNET` permission, checked with `aapt2` |
| iOS | Configured (Info.plist usage text, Podfile permission switches), **never built or run**: it cannot be built on Windows. No Swift code and no background mode |
| Replies, forwards, edits, deletion (for me / for everyone), pins, selection, search, details | Implemented, tested in simulation (data layer, services and screens) |
| Public-room six-hour cleanup | Implemented, tested with a fake clock; private data is never touched |
| Videos (up to 512 KB, private chats and groups) | Implemented, tested in simulation. No thumbnails; very small clips only |
| Message notifications (three privacy levels), tap to open, retraction | Implemented with `flutter_local_notifications`; **never run on a phone** |
| "Help relay messages for others" on/off | Implemented, tested in simulation |
| "Keep the mesh running in the background" (Android foreground service) | Implemented; the switch turns itself off if the service does not really start; the Flutter engine now outlives the screen (Back and swiping the app away no longer stop the mesh). **Never run on a phone; the Kotlin changes of 2026-11-09 were not compiled on the machine that made them.** Not available on iPhone |
| Background operation without that service | **Not guaranteed.** Android may stop Bluetooth work when the app is in the background; nothing works after a force-stop; see [docs/delivery-and-routing.md](docs/delivery-and-routing.md) |
| Storage screen, size limits, save to gallery, share | Implemented, tested with fakes |
| Offline voice calls | **Design document only** ([docs/voice-calls-design.md](docs/voice-calls-design.md)) |
| Database export / backup, encryption of the local database | **Not implemented** |
| Cross-platform Android <-> iPhone interoperability | **Unknown**, never tried |
| Battery use | **Not measured** |

"Tested against a simulation" means: the code that talks to the plugin was run against a test double
that implements the plugin's own `CentralManager` / `PeripheralManager` interfaces and enforces the
behaviours that tend to break real BLE apps (one GATT operation at a time, notifying only after the
other side subscribed, MTU limits, Android-only vs iOS-only members, Bluetooth being switched off and
on, permission changes, connection failures such as status 133). It cannot prove that a particular
phone model behaves.

## Quick start

### Prerequisites

* Flutter 3.47.x (Dart 3.13.x). Check with `flutter --version`.
* A **full JDK 17 or newer** for Android builds. A JDK without `jlink` makes the Gradle build fail.
  Eclipse Temurin 21 works: <https://adoptium.net>. Point `JAVA_HOME` at it.
* Android SDK with platform 36 (Flutter installs what Gradle asks for when you accept the licences:
  `flutter doctor --android-licenses`).
* For iPhones: macOS with Xcode. iOS cannot be built on Windows or Linux.

### Install, check, test, build

Run these from the project folder (`offline_mesh_chat`). On Windows PowerShell:

```powershell
$env:JAVA_HOME = "C:\Path\To\jdk-21"          # a full JDK
$env:Path = "$env:JAVA_HOME\bin;$env:Path"

flutter pub get                               # install dependencies
flutter analyze                               # static analysis, expected: "No issues found!"
flutter test                                  # all 1,295 automated tests (about four minutes; add --concurrency=2 on a busy machine)
flutter build apk --debug                     # build/app/outputs/flutter-apk/app-debug.apk
flutter build apk --release                   # build/app/outputs/flutter-apk/app-release.apk
```

On macOS/Linux use `export JAVA_HOME=/path/to/jdk-21` and the same `flutter` commands.

Do not run `flutter test` while a Gradle build is running, or several test runs at once: the
simulated-radio tests use millisecond-scale timeouts on purpose and can fail on an overloaded machine
without anything being wrong.

### Run on phones

Enable developer options and USB debugging on each Android phone, plug it in, then:

```powershell
flutter devices                               # note the device ids
flutter run --release -d <device-id>          # phone A
flutter run --release -d <other-device-id>    # phone B (second terminal)
```

Use `--release` (or `--profile`) for any Bluetooth test. Debug builds run the cryptography an order
of magnitude slower and can distort timing. Release builds are signed with the debug key unless `android/key.properties` exists (see docs/build-and-debug.md), which
is fine for testing and not for distribution.

To install an APK without a cable: copy `build/app/outputs/flutter-apk/app-release.apk` to the phone,
or run `adb install -r <apk>`.

iPhone (macOS only, not verified): open `ios/Runner.xcworkspace` in Xcode, choose a signing team, then
`flutter run --release -d <iphone-id>`. The `ios/Podfile` already switches on the microphone, camera
and photos parts of `permission_handler` (and leaves every other permission compiled out).

**Before distributing to anyone else:** the Android application id is still the Flutter template's
placeholder (`com.example.offline_mesh_chat`, in `android/app/build.gradle.kts`), as is the iOS bundle
identifier (in Xcode). Change both, create a real signing key, and answer the App Store / Play Store
encryption and data-safety questions yourself (the app uses end-to-end encryption and collects no
data). The release APK built here is about 64 MB (63.5 MB on 2026-10-20), is labelled "دەمەتەقێ" with the glass-bubble
adaptive icon, and needs Android 7.0 (API 24) or newer (checked with `aapt2 dump badging`).

## Permissions: what is asked, when, and why

Nothing is requested when the app starts. Every permission is asked for at the moment a feature needs
it, and **before the system's own prompt appears, the app explains in plain words what the
permission is for and what happens to the data**, with a "Not now" button. Only "Continue" shows the
system prompt, and an answer of "no" is respected (the app does not ask again straight away). If a
permission was switched off for good, the app says so and offers **Open settings**. Settings >
Permissions lists them all with their state.

| Permission | When it is asked | Why | If it is refused |
| --- | --- | --- | --- |
| Bluetooth (Android 12+: Nearby devices; Android 11 and older: Location, which Bluetooth scanning needs there; iOS: Bluetooth) | When you press the button on the first-run page, after the page explained it | To find and talk to nearby phones. The location is never read | The app shows a banner that explains what is missing and has **Allow Bluetooth** / **Open settings** buttons. Nothing else works without it |
| Microphone | The first time you tap the microphone to record a voice message | Recording, only while you hold a recording open | No recording is made; the chat says why; the rest of the app is unaffected |
| Camera | The first time you choose "Take a photo" or "Record a short video" | Taking the picture or video you want to send | Nothing is taken |
| Photos | iOS: the first time you choose a picture or video from the library. **Android: never** (see below) | Opening the one you choose | None is chosen |
| Notifications (Android 13+, iOS) | When you turn "Message notifications" on in Settings | To tell you a message arrived while the app is not on screen | Messages still arrive and are counted; no notification is shown |
| Foreground service (Android) | Only when you turn on "Keep the mesh running in the background" | A visible notification while the app keeps Bluetooth work alive with the screen off | The switch stays off and says so |
| Saving to the gallery (Android 9 and older; iOS) | Only when you choose "Save to gallery" on a picture or video, after an explanation | A copy in your gallery, visible to other apps | Nothing is saved |

On Android the app uses the system photo picker, which hands the app only the file you select and
needs no storage permission at all. Pictures, recordings and videos are kept in the app's private
storage, **never in your gallery unless you choose "Save to gallery"**, and are never uploaded anywhere:
there is no network code.

Declared in `android/app/src/main/AndroidManifest.xml`: `BLUETOOTH_SCAN` (marked
`neverForLocation`), `BLUETOOTH_CONNECT`, `BLUETOOTH_ADVERTISE`, `RECORD_AUDIO`, `CAMERA`,
`POST_NOTIFICATIONS`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_CONNECTED_DEVICE`, `WRITE_EXTERNAL_STORAGE`
(Android 9 and older only) and, for Android 11 and older only, `BLUETOOTH`, `BLUETOOTH_ADMIN`,
`ACCESS_COARSE_LOCATION` and `ACCESS_FINE_LOCATION`. Microphone and camera hardware are declared
optional so the Play Store does not hide the app from phones without them. **There is no `INTERNET`
permission** in a release build (the debug and profile manifests add one because the Flutter tool needs
it for hot reload). Plugins add a few more to the built release APK: `ACCESS_NETWORK_STATE` (the
display-only connectivity plugin), `VIBRATE` and `WAKE_LOCK` (the notification plugin) and, for Android 9
and older, an implied `READ_EXTERNAL_STORAGE` that comes with `WRITE_EXTERNAL_STORAGE`. This was checked on the
built `app-release.apk` with `aapt2 dump permissions` (minimum Android 7.0, API 24; target API 36); the
service is declared `foregroundServiceType="connectedDevice"` and not exported. iOS usage texts
are in `ios/Runner/Info.plist`. The full table, with the iOS notes, is in
[docs/build-and-debug.md](docs/build-and-debug.md). The built release APK's permissions should be
re-checked with `aapt2 dump permissions` after any dependency change.

## Dependencies and why

Versions were checked against pub.dev and the plugin sources.

| Package | Version | Used for | Notes |
| --- | --- | --- | --- |
| `bluetooth_low_energy` | ^6.2.1 | BLE central **and** peripheral on Android and iOS | The only maintained plugin found that offers both roles. MIT licence. Young and lightly used; this is the biggest technical risk in the project |
| `sqflite` | ^2.4.4+2 | SQLite | Tests use `sqflite_common_ffi` on the host |
| `path`, `path_provider` | ^1.9.1, ^2.1.6 | Database and media location (private app-support folder) | |
| `cryptography` | ^2.9.0 | Ed25519, X25519, ChaCha20-Poly1305, HKDF, SHA-256 | Pure Dart. HPKE is assembled from these primitives in `lib/crypto/hpke.dart` |
| `flutter_secure_storage` | ^11.2.0 | Identity keys and group keys in the Android Keystore / iOS Keychain | |
| `permission_handler` | ^12.0.2 | Microphone, camera, photos and notification prompts | Kept below 13: 13.x hard-codes `compileSdk 37`, which fails with this toolchain. Bluetooth permission does **not** go through it; the Bluetooth plugin asks for exactly the set it needs on each Android version |
| `record` | ^7.1.2 | Voice message recording (AAC in an .m4a container) | |
| `audioplayers` | ^6.8.1 | Voice message playback | |
| `image_picker` | ^1.1.2 | Taking a photo, choosing a photo | |
| `image` | ^4.12.0 | Pure-Dart JPEG decoding and re-encoding, so a photo is shrunk to a few dozen kilobytes (about 640 pixels) on the phone | Runs in a background isolate |
| `video_player` | ^2.14.1 | Playing a received video from its private file | |
| `flutter_local_notifications` | ^22.3.2 | Local notifications (no push server) | Needs Java library desugaring, enabled in `android/app/build.gradle.kts` |
| `gal` | ^2.3.3 | "Save to gallery" | |
| `share_plus` | ^13.3.1 | The system share sheet | |
| `animated_theme_switcher` | ^2.0.10 | The circular reveal when switching between light and dark | Wrapped in `lib/theme/theme_host.dart`. It cannot set a theme without a reveal, and calls `ui.window`, which Flutter deprecates but still has (3.47): see docs/ui-design.md, section 3a |
| `shared_preferences` | ^2.5.6 | Remembering the light / dark choice | Read before the database opens, so the first frame is already in the right appearance; every other setting stays in SQLite |
| `connectivity_plus` | >=7.3.1 <7.3.2 | **Display only**: shows whether Wi-Fi/mobile data are on | Never a transport. Pinned because 7.3.2 conflicts with a transitive dependency of the BLE plugin |
| `device_info_plus` | ^13.3.0 | Phone model/OS in the self-test report | Reads local properties only |
| `flutter_launcher_icons` (dev) | ^0.14.4 | Builds the launcher icons from `assets/icon/` | |

Evaluated and **not used**:

* `flutter_blue_plus`: central role only (cannot advertise or host a GATT server, so two phones could
  not reliably find each other), a paid licence for commercial use, and its Android build sends the
  app id, name and version to a Google Apps Script URL during the Gradle build.
* `cryptography_flutter`: optional native acceleration. Not adopted, so that all cryptography is
  deterministic pure Dart and testable on a desktop. Revisit if profiling on a slow phone shows a need.

Known build warning: Gradle prints a Kotlin Gradle Plugin deprecation message that comes from the BLE
plugin's own build script. It is harmless to the build today; a future Flutter version will require that
plugin to migrate. All of the plugins above **compile** into a debug APK; none has been run on a phone.

## How it works

```
 Flutter UI (screens, widgets)                      lib/screens, lib/widgets, lib/theme
        |
 AppController (small ValueNotifier slices)         lib/app_controller.dart
        |
 MessageService ---- EncryptionService              lib/services/message_service.dart, encryption_service.dart
   |  GroupService  RoomService  MediaService       lib/services/*
        |                  |
        |             SQLite repositories           lib/database/*
        v
 MeshRouter --- duplicate filter, rate limiter, store-and-forward queue, relay decisions, peer table
        |                                           lib/mesh/*
 BluetoothService (links, handshake, framing)       lib/services/bluetooth_service.dart
 DiscoveryService (scan policy, who to connect to)  lib/services/discovery_service.dart
        |
 BleRadio interface  ->  PluginBleRadio             lib/transport/ble_radio.dart, lib/services/plugin_ble_radio.dart
        |
 bluetooth_low_energy plugin  ->  phone's Bluetooth stack

 Phone features (permissions, photo picker, image shrinker, recorder, player)   lib/device/*
```

**Two roles at once.** Every phone advertises one GATT service and also scans and connects out to
others. The service has one characteristic that supports both write (from the connecting side) and
notify (from the hosting side), so a link carries data both ways. If two phones connect to each other
at the same moment, the pair keeps one link (the one where the numerically smaller identity key is the
connecting side) and silently drops the other.

**Link layer.** BLE writes are small (as little as 20 bytes, typically 100 to 500 depending on the
negotiated MTU), so every frame is cut into chunks with a 6-byte header (frame id, index, count) and
reassembled on the other side, with size caps. A chunk never exceeds what one ATT packet carries (MTU
minus 3) on either platform. Right after connecting, each side sends HELLO (its public keys, a random
challenge and its nickname) and then AUTH (an Ed25519 signature over both challenges and both
identities), so a link only carries traffic after the other phone proved it holds the private key it
claimed. Idle links are probed with PING/PONG and dropped after 45 s of silence. Handshakes time out
after 10 s, and the number of unauthenticated links is capped.

**Mesh packets (protocol version 3).** Everything that travels is a signed `MeshPacket`: version,
type, flags, hop limit and hop count, a random 16-byte message id, timestamps, the sender's key, the
recipient (a person's key for private messages; a random group id or room id for group and room
packets), a payload of at most 2048 bytes, and an Ed25519 signature that covers everything except the
hop counter, so a relay can count hops but cannot change the recipient, expiry, hop limit or payload.

| Type | Carries | Hop limit | Lifetime |
| --- | --- | --- | --- |
| announce | Presence and encryption key | 3 | 2 min |
| direct | Private text, picture/voice manifests and chunks, group invitations and key updates | 5 | 12 h |
| ack | Signed delivery receipts, up to 16 ids per packet | 5 | 2 h |
| group | Group messages, manifests and chunks | 5 | 12 h |
| room | Public-room messages, manifests and chunks | 5 | 2 h |
| roomAnnounce | A signed public-room record, so nearby phones can discover the room | 4 | 5 min |

The hard cap on any received hop limit is 7, and a node never keeps anything longer than 24 h
whatever the sender wrote.

**Routing.** There is no routing protocol in BLE itself. Each phone floods small signed announcements
a few hops; a phone learns "C is reachable through neighbour B" only from a valid announcement
received through a currently connected neighbour, and that fact expires after about 100 seconds. A
peer is shown as *Directly connected* only with an authenticated link, as *Via relay (n hops)* only
with such a fresh route, and otherwise as *Offline*. There are two delivery classes:

* **Directed** traffic (private messages, receipts) goes over the direct link if there is one, else
  along the learned route, else floods to up to 4 neighbours. Receipts stop retries.
* **Persistent flood** traffic (group and room packets) has no single recipient, so each packet is
  offered **once to every neighbour** and then **kept until it expires**. A phone that was away gets
  the packets when it is next in range of anyone who still has them (store, carry and forward). These
  packets have their own storage quotas and eviction, so they cannot push private messages out.

Every phone keeps a persistent list of message ids it has seen (duplicates are dropped and never
create chat entries, which is why a public message shows once however many paths it took), enforces
hop limits and expiry, rate-limits inbound traffic per link and per sender (a flood is dropped and
written to the security log), and sends acknowledgements ahead of messages and messages ahead of media
chunks. Unsent messages are stored in SQLite and survive restarts.

**Groups.** Creating a group makes a random 256-bit key. Each invited person gets a sealed invitation
(a private message, encrypted to their key) holding the group's name, members and key; they accept or
decline. Only the admin (the creator) can add or remove people, and **every membership change makes a
new key** (a new "epoch") that is sent, sealed, to the people who remain: a removed person cannot read
what is sent afterwards. Invitations and updates are accepted only from the admin and only if the
receiver is listed. Every group message is checked against the member list; a message from someone who
is not a member is dropped and goes to the security log. Nothing about a group (name, members, that it
exists) is ever broadcast.

**Public rooms.** A room is a signed record (name, description, expiry) whose id is derived from its
creator's key, so nobody can claim someone else's room id. The record is flooded once to nearby phones
(hop limit 4) and passed on only if it is news; the creator's phone renews it while the app runs, and
it disappears after 24 hours without renewal. A phone remembers at most 100 discovered rooms (10 per
creator). Messages in a room are signed but **not encrypted**. The built-in `#mesh` room exists on every
phone and needs no discovery.

**Pictures, voice messages and videos.** A picture is shrunk on the phone to about 640 pixels and a few
dozen kilobytes; a voice message is a recording of at most 30 seconds; a **video is not shrunk**, so only
a very short, low-quality clip fits (at most 512 KB, by default 256 KB, chosen in Settings > Privacy and security > Storage; private
chats and groups only). A picture or voice object is at most 64 KB, a video at most 512 KB, cut into
chunks of 1536 bytes (at most 342), and sent as an ordinary mesh packet for the manifest followed by
chunk packets. The receiver reassembles the chunks and checks the whole file against its SHA-256
before showing or playing anything; a file that does not match is discarded and logged. The key for
the chunks is: private chat, a fresh key inside the sealed manifest; group, derived from the group key
and the media id; public room, none (signed plaintext).

**Editing, deleting and replying** are messages too: an edit or a delete request travels sealed (private
chats and groups) or signed (public rooms) like any message, and the receiver obeys it only if it comes
from the message's author (or, for deleting, the group's admin). A request that is not allowed is ignored
and written to the security log. A removed message leaves a minimal record (its id and why it is gone, no
content) for 48 hours so a late copy cannot bring it back; an edit that arrives before its message waits
for it. A reply carries only the id of the original: what is quoted is looked up on the reading phone, so
a deleted original leaves nothing to quote. Details in [docs/protocol.md](docs/protocol.md) and
[docs/security.md](docs/security.md).

**Notifications and relaying.** A notification is made on the phone from a message that was already
received, verified and saved, only for the person it is addressed to, and only while the app is not on
screen. A phone that merely relays never shows one. The person chooses what it shows (name and message,
name only, or nothing), and public rooms are silent unless asked for. "Help relay messages for others"
turns the carrying of other people's sealed packets off; the phone then still receives and sends its own.
What happens when the app is in the background, suspended, terminated or force-stopped is set out honestly
in [docs/delivery-and-routing.md](docs/delivery-and-routing.md); **none of it is verified on a phone**.

**Delivery states shown to the user.** Pending (queued, no route), Sent (handed to a neighbour),
Delivered (a signed receipt arrived; in a group, from every other member; for a picture or a voice
message, only once the whole file has been assembled), Not delivered (expired or retries exhausted,
with a "send again" button), and "could not be decrypted or verified" for incoming messages that fail
authentication. A public room has no receipts, so it shows Sent at most.

**Keyboard and list performance.** The message box keeps its own state, so typing rebuilds only the
small send/microphone button next to it; the message list is not rebuilt when the keyboard appears or
a letter is typed; each bubble is its own repaint layer; real blur is used only on dialogs and sheets,
never on lists. A widget test counts bubble builds while the keyboard slides up and while a whole sentence
is typed, and fails if any bubble is rebuilt.

## Local storage: what is kept on the phone

Everything the app keeps lives on the phone, in the app's own private area (other apps cannot read
it, and Android backup is switched off). Nothing is sent anywhere.

| What | Where | Kept after the app is closed or restarted? | Removed when |
| --- | --- | --- | --- |
| Chats and messages, delivery states, contacts, groups and their members, public rooms, receipts, the queue of messages still waiting to be sent, the list of messages already seen, the security log, and settings (nickname, "How hard to look for people", "Keep messages", first run done) | One SQLite file, `offline_mesh_chat.db`, in the app's support folder (`getApplicationSupportDirectory()`). Schema version 3; a database from either earlier version is migrated, not discarded | **Yes.** Messages still waiting to be sent are sent after a restart | You delete a chat, group, room or contact; the **Keep messages** setting (Forever, 1, 7 or 30 days) deletes older ones; **Delete all local data** |
| The finished pictures and voice messages | One file each in `media/` inside the same private folder, named `<id>.jpg`, `<id>.m4a` or `<id>.mp4`. **Never in the phone's gallery unless you choose "Save to gallery"** | **Yes** | Together with their chat, **at once** (including when you leave a room or delete a group); by the **Keep messages** setting; **Delete all local data**. A half-received file is given up after 12 hours |
| Identity keys and group keys | The Android Keystore / iOS Keychain (through `flutter_secure_storage`), not the database | **Yes** | **Reset identity**; **Delete all local data**; uninstalling the app |

A file is written to a temporary name and renamed, so an interrupted write never leaves a half-written
picture under its real name; leftovers are removed on the next start. A file is deleted as soon as no
chat refers to it, except for the moment between writing it and recording it. Nothing leaves the app's
folder unless you choose **Save to gallery** or **Share** on a message (each says what it does first), and
there is no database export or backup. Settings > Privacy and security > Storage shows what is kept and lets you clean public
chats now or delete every picture, voice message and video. The database and the files are **not
encrypted** by the app: they rely on the phone's screen lock and disk encryption.

This was tested on a real disk (a real SQLite file and real media files in a temporary folder, with the
phone's Bluetooth simulated): chats, pictures, recordings, settings and the identity survive closing
and reopening the app; deleting a chat, a group or a room removes its files at once; **Delete all local
data** empties the media folder. What was **not** tested is the plugin layer on a real phone
(`sqflite`, `path_provider` and `flutter_secure_storage` on Android and iOS), because no test here has
run on a phone.

## Security model

* **Identity.** Each phone generates, on first start, an Ed25519 signing key (its identity, shown as a
  short id) and an independent X25519 key for receiving encrypted messages, stored in the platform key
  store. There are no accounts, phone numbers or servers.
* **Private messages** (and pictures and voice messages in a private chat). RFC 9180 HPKE in Base mode
  (DHKEM X25519 / HKDF-SHA256 / ChaCha20-Poly1305) to the recipient's X25519 key, with the packet
  header as associated data, and the whole packet signed with the sender's Ed25519 key. Relays carry
  only ciphertext. Tampering with the payload, recipient or hop limit invalidates the signature;
  tampered or misdirected ciphertext fails authentication and is recorded in the security log instead
  of being shown.
* **Groups.** ChaCha20-Poly1305 under the group's key (per epoch), bound to the packet header, plus the
  packet signature. Only holders of the current key can read; a relay or a nearby phone that is not a
  member sees ciphertext. Relays can see the group's random id, the sender's key, the time and the
  approximate size, but not the name or the members.
* **Public rooms.** Signed, not encrypted: a relay cannot alter a word or forge an author, but anyone
  who receives it can read it. The screens say so wherever a room is created, joined or written in.
* **Verifying a contact.** The first time two phones meet, nothing proves that a key really belongs to
  the person ("trust on first use"). Each contact page shows a *safety number* (derived from both
  phones' keys, the same on both screens). Compare it in person or on a call you trust, then mark the
  contact verified. If a contact's key changes, the verification is revoked and an entry is added to
  the security log.
* **Hardening.** Low-order / all-zero Ed25519 keys are rejected. Incoming sizes, fragment counts, chunk
  counts, numbers of unauthenticated links and numbers of discovered rooms are capped. Nicknames,
  group names and room names are stripped of control, zero-width and bidirectional-override
  characters. Chunks that fail their checksum, or that claim impossible sizes, are discarded.
* **No secrets in logs.** Keys, shared secrets and message text are never logged. The in-app log lives
  in memory only.

**Not claimed:** the combination of these pieces and this implementation have **not** been reviewed by
an independent cryptographer, so do not describe the app as having verified end-to-end encryption. The
primitives come from the `cryptography` package; HPKE is implemented here and is checked against the
published RFC test vector. There is no forward secrecy beyond HPKE's per-message ephemeral key (a
stolen long-term X25519 key decrypts captured private messages; a leaked group key decrypts that
epoch), no deniability, and no protection against someone who has your unlocked phone.

## Privacy defaults and their limits

Defaults: no account server, no cloud storage, no analytics or tracking, no plaintext forwarding of
private content, no private-key logging, no hardcoded secrets, no custom cryptographic algorithms,
and local data is cleared only after an explicit, typed confirmation. Bluetooth is not touched, and no
permission is requested, until the person presses the button on the first-run page. Private and group
content is never broadcast: only signed announcements (presence, public-room records) are.

What the design cannot hide:

* **Presence.** The advertisement carries only the app's service UUID (no name or key), but anyone
  nearby can see that a دەمەتەقێ phone is present, and can connect to it. The first thing exchanged on
  a connection (before authentication) is the phone's **public key and nickname**, so a nearby
  observer can learn them, and because the key is long-lived, can recognise the same phone at
  different places and times. "Reset identity" creates a new one, and contacts must verify it again.
* **Relays see metadata.** A phone that forwards a private message sees the sender's and recipient's
  public keys, the approximate time and approximate size, but not the content.
* **Stored data.** Chat history is stored in SQLite and pictures and recordings as files in the app's
  private folder, **without encryption of their own**; they rely on the phone's lock screen and disk
  encryption. Android backup and device-transfer are disabled in the manifest. On iPhone the files are
  in Application Support, which the app excludes from iCloud and computer backups at every start (code written, never run on an iPhone). **Settings > Privacy and security > Delete all local
  data** removes the messages, pictures, contacts, groups and keys.
* **Names are not identities.** Anyone can choose any nickname; two people can choose the same one. In
  public rooms the first characters of the sender's id are shown after the name for that reason.
* **Public rooms are public.** Anyone can join one, read it and write in it; the app has no moderation.

## What Bluetooth and the platforms limit

These are the features that are limited by the Bluetooth transport or by the target platform, as
opposed to the logic (which the automated tests cover). Numbers that depend on real radios are
**not measured**.

| Feature | The limit | Because |
| --- | --- | --- |
| Range | Roughly 10 to 30 m per hop, less through walls | Bluetooth Low Energy |
| Speed of pictures, voice and video | Pictures and voice are capped at 64 KB (pictures about 640 px, voice 30 s), videos at 512 KB (default send limit 256 KB, not shrunk by the app). Each hop takes seconds for a picture and **minutes for a video**, more with several hops or a weak signal. **Real speeds are not measured** | A BLE link moves a few kilobytes a second; every chunk is a signed packet |
| Larger files, long or high-quality video, live calls | Not possible. A normal phone video is refused before sending, with its size and the limit | Same |
| Videos in public rooms | Not allowed | Every phone in range would have to carry them |
| Incomplete media in groups and rooms | A picture, recording or video can stay incomplete if one of its pieces is lost on **every** path; it then shows "could not be received". There is no request-it-again step yet. In a private chat every piece is acknowledged and resent until it arrives | Flooded traffic is offered once per neighbour; reliable re-requests are not implemented |
| Messages right after a group key change | Messages sent right after a member was added or removed can be missed by a member whose key update arrives later | The new key travels as a sealed private message, which can be slower than the group's own traffic |
| Background use | **Not guaranteed.** With the app on screen everything works. In the background Android may stop Bluetooth work; an optional foreground service asks it not to (**untested**); after a force-stop or on an iPhone nothing is received or relayed and no notification can be shown | Android and iOS restrict Bluetooth for background apps; the app does not try to defeat that. See [docs/delivery-and-routing.md](docs/delivery-and-routing.md) |
| Deleting for everyone | A request: it works only on phones that receive it (it waits for the rest, up to its lifetime) and cannot remove a screenshot or a saved copy | No server, and copies outside the app are out of its reach |
| Waiting for a route | Private and group messages are kept and retried for up to 12 h, public-room messages for 2 h, then marked not delivered. A phone that is closed during that time cannot carry them | No server to hold messages |
| Relay depth | At most 5 hops for messages (7 as an absolute cap); presence 3; room announcements 4 | Flooding does not scale; bounded on purpose |
| Group size | At most 12 people (the member list must fit one packet) | Packet size |
| Public rooms | Not private; no moderation; a room disappears after 24 h unless its creator's phone renews it; a phone remembers at most 100 rooms | Open by design |
| Public-room delivery | No delivery receipts, so "Sent" is the furthest state | Nobody is the recipient |
| Phones that cannot advertise | Can find others but cannot be found; two such phones cannot connect | Some Android phones cannot act as a BLE peripheral; the app says so |
| Number of links | About 6 to 7 simultaneous connections on Android | Android Bluetooth stack |
| Android 11 and older | Scanning needs the Location permission **and** the phone's Location switch on; the app never reads the location | Android |
| Android scan rate | Scans are duty-cycled (Android allows 5 starts per 30 s) | Android; adjustable under Settings > Chats and Bluetooth > "How hard to look for people" |
| iPhone | **Never built or run.** The code is written around known differences (no MAC addresses, no connect/disconnect events or MTU on the peripheral side, cannot drop a connected central) | iOS CoreBluetooth |
| Android <-> iPhone | **Untested.** The protocol is platform-neutral, so it may work | |
| Clocks | Expiry uses each phone's own clock; the sender's is clamped and only advisory; clocks more than a few minutes apart can make a message look expired or early | No time server |
| Photos on Android | Uses the system photo picker (no permission); on iOS the Photos permission is asked | Platform behaviour |

## Automated tests

```powershell
flutter test                                    # everything: 1295 tests
flutter test test/ui                            # widget tests of every screen (217)
flutter test test/app                           # the whole app on simulated radios, incl. the ten scenarios
flutter test test/app/damataqe_scenarios_test.dart   # just the ten scenarios
flutter test test/visual                        # draws the screens to PNG files in build/shots (see below)
```

**Result of the last full run (2026-11-09, `--concurrency=2`): 1293 passed, 2 failed, 0 skipped** (the analyzer reports no issues). The two are timing-sensitive tests of the simulated Bluetooth link with tiny 20-byte writes: `services/ble_self_test_test.dart` ("the 20-byte minimum write size is flagged as slow") fails every time on this machine today, and fails the same way on a copy of the code from before the appearance work, so it does not come from it; `integration/ble_mesh_integration_test.dart` ("a full-size message crosses two hops with tiny 20-byte writes") passes when run alone and fails only in some full runs. Both passed on this machine on an earlier day; the cause (probably the machine's timer resolution) is not established. With the default parallelism, other timing-sensitive tests also fail now and then and pass alone. A run during which the machine was busy with something else once failed two of the timing-sensitive Bluetooth link tests; both pass alone and in the next clean run. **All
of them are simulated**: nothing here has run on a real radio or phone. By area:

| Area | Tests | Where |
| --- | --- | --- |
| Protocol: packet layout, envelopes (text, media, video, replies, forwards, edits, deletes), media chunks, room records, fragmentation, link frames | 155 | `test/protocol` |
| Cryptography: AEAD, HPKE (RFC 9180 vectors), HKDF, weak keys | 39 | `test/crypto` |
| Database: schema, migrations from v1 and v2, messages, removal and tombstones, edits, pins, search, expiry, groups, rooms, media, outbox | 144 | `test/database` |
| Mesh: duplicate filter, rate limits, queue, relay decisions, router | 126 | `test/mesh` |
| Services: encryption, messages, **delete / edit / reply / forward / pin**, **public-chat cleanup**, **notification rules**, **relay opt-out**, groups, rooms, media and video, Bluetooth link, discovery, plugin glue, self-test | 386 | `test/services` |
| Phone features: permissions, image shrinking, recorder/player contracts | 12 | `test/device` |
| The whole app on simulated radios: controller, the ten scenarios, local storage on a real disk, **notifications, relay and background settings**, the language setting, **what a conversation screen reads and marks as read** | 70 | `test/app` |
| Multi-phone BLE meshes, **including lines of seven and eight phones, a star and an Android / iPhone line** | 15 | `test/integration` |
| UI: navigation and the **floating bar, where the app opens, the Settings menu and its pages**, private chat, pictures, voice, permissions, groups, public room, people and settings, **message actions (menu, selection, reply, edit, delete, pin, forward, details, search)**, **settings and storage**, **video, gallery and share**, **Kurdish and Arabic (a walk through nearly every screen at 320 px and large text)**, **the ghost, movement and 44-point touch targets**, **the colour palette, the bundled font and contrast** | 217 | `test/ui` |
| The three languages: the .arb files kept in step, text direction, byte limits, stored previews and problems, plurals | 38 | `test/l10n` |
| Visual check (screenshots of the home screen and every settings page in the three languages, the ghost, the message actions) | 24 | `test/visual` |

The specification's 24 test areas, each marked simulated or real-device, are mapped to these tests in
[docs/testing.md](docs/testing.md). Real-device testing is **not done**: see
[docs/real-device-test-plan.md](docs/real-device-test-plan.md).

**The ten scenarios of the product plan, on simulated Bluetooth** (the whole app stack on every
phone; only the Bluetooth plugin is simulated):

| # | Scenario | Result in simulation | On real phones |
| --- | --- | --- | --- |
| 1 | Private chat: text, picture and voice between two phones | Passed (arrives byte for byte, shown as Delivered, no security events) | Not run |
| 2 | Relay: a private message and picture cross a phone that cannot read them | Passed (the relay keeps no chat, no file, no key) | Not run |
| 3 | A group of three: create, invite, accept, text, picture, voice, who received it | Passed | Not run |
| 4 | A member who was away catches up when back in range of anyone | Passed | Not run |
| 5 | A public room is discovered through a relay by someone who never met its creator | Passed | Not run |
| 6 | A public message is shown once whatever path it takes (a ring of phones) | Passed | Not run |
| 7 | Pictures and voice in private chat, group and public room | Passed | Not run |
| 8 | A phone that is not part of a conversation cannot read it; a removed member reads nothing sent afterwards | Passed (two tests) | Not run |
| 9 | The relay drops out (Bluetooth off and on) during a picture transfer | Passed (the picture still arrives complete) | Not run |
| 10 | Fully offline operation | Passed (nothing needs a network; the release APK has no `INTERNET` permission) | Not run |

Other behaviour covered by the UI tests: the bottom bar (its four places and icons, Public first and
current, right-to-left order, the rounded pill's size and place, instant page change, the moving
highlight and its interruption, press feedback, unread badges, Back, reduced motion, high contrast,
large text, tablets, the keyboard), where the app opens, the Settings menu and each of its pages, the
public room's loading, empty and error states, every place's empty state, search, unread badges,
creating a group, accepting and declining an invitation, the admin adding and removing people,
leaving, a removed member, creating, discovering and joining a public room, nickname changes, the
built-in room, pictures (preview with a caption, send, arrive, open full screen, unreadable file,
back out), voice (record, timer, discard, too short, limit reached, microphone refused, play, speed),
every permission path (explained first; "not now"; refused by the system; switched off for good, with
the settings button; unavailable), the keyboard not rebuilding the conversation, and every main screen
at 320 x 568 and with large system text (no overflow), and on a tablet.

Beyond coverage, the tests were used to look for real defects, and found some that were then fixed:
an all-zero-key signature forgery; a handshake race when a remote starts talking before the link is
announced; a Bluetooth off-then-on toggle that finished before the radio handled the first event; a
chunk header that left the flags out of the authenticated data; a conversation that notified on every
read (a reload loop); dialogs that used a text controller after disposing it; a text-and-status row
under message bubbles that overflowed at large text sizes; a public-room header that overflowed with
a long room name; and the public composer's hint being cut off.

**What the simulation does not tell you:** real radio range and interference, real MTU and
connection-interval behaviour per phone model, throughput (and so how long a picture really takes),
battery, timing under a loaded phone, OS-specific bugs in the plugin, and cross-platform behaviour.

## Testing on real phones

**Not done yet.** The detailed plan for three Android phones, including notifications and background
behavior, is [docs/real-device-test-plan.md](docs/real-device-test-plan.md). The older checklist below
covers discovery, messaging, pictures, groups and relaying.

Use two Android phones for steps 1 to 8, three for steps 9 to 11, and iPhones where you have them.
Install a **release** build on each (see [Run on phones](#run-on-phones)). Keep the screens on.

The app includes a guided check: **tap the connection pill at the top of the home screen** (or
Settings > Chats and Bluetooth > Bluetooth self-test). It checks Bluetooth support, permission, power, advertising,
scanning, finding another phone, connecting and proving identity, sending small and large (fragmented)
payloads both ways, relaying (if a third phone is in the mesh) and offline operation. A failed step
says what to try. **Copy report** puts a plain-text report on the clipboard (no keys or message text;
the log section can contain nearby Bluetooth addresses, so read it before sharing).

| # | Test | Do | Expected |
| --- | --- | --- | --- |
| 1 | Alone | Open the app on one phone, finish the first-run page, allow the Bluetooth permission, run the self-test | Support, permission, power, advertising and scanning pass; "Finding another phone" is a warning, not a failure |
| 2 | Two phones, offline | Turn **Wi-Fi and mobile data off** on both (airplane mode, then Bluetooth on). Open the app on both, side by side | Each shows the other under "Available now" within about 30 s. Self-test passes on both |
| 3 | Private messages | Send a few messages each way, one long (close to 1000 bytes) | Pending, then Sent, then Delivered. Text arrives intact |
| 4 | Picture | Send a picture ("Take a photo" and "Choose from your photos") | The app explains the permission first. The picture arrives complete and opens full screen. **Note how long it takes**: this is the number the simulation cannot give you |
| 5 | Voice | Record and send a 10-second voice message | The app explains the microphone permission first. The other phone plays it. Note the time to arrive |
| 6 | Restart | Force-close and reopen the app on both | Chats are still there; the phones reconnect without any action |
| 7 | Delayed delivery | Turn Bluetooth off on B, send from A, wait a minute, turn it on | The message stays Pending on A, then arrives and turns Delivered, once (no duplicate) |
| 8 | Permissions | Say "Not now", then "Continue" and refuse, then switch the permission off for good in the system settings and try again | Each path ends with a clear message; "Open settings" opens the right page; nothing is recorded or taken without permission |
| 9 | Group | On A create a group with B and C; accept on both; chat, send a picture; move C away and send more; bring C back | Invitations arrive; messages and the picture arrive for both; C catches up when back in range of anyone who kept the messages. Note how long |
| 10 | Three phones in a line | Put A and C out of each other's range with B between. Wait a minute | On A, C appears as "Via relay (2 hops)". A to C delivers; the chat on B contains nothing. Repeat with a picture |
| 11 | Public room | On A create a room; on C (out of A's range, in B's) wait for it to appear under "Nearby rooms"; join and post | The room appears (through B); posts show once on every phone |
| 12 | Verification | On two phones open the contact page and compare safety numbers | Numbers are identical; verified status is remembered |
| 13 | Background | Lock a phone for a minute, then unlock | Links drop while locked and come back after unlock (record what you see) |
| 14 | Battery | Note the battery percentage after an hour in each discovery mode | Record the numbers; none are claimed in this repository |
| 15 | iPhone to iPhone, iPhone to Android | Repeat 2 to 5 and 10 | Unknown. Record what happens; add the self-test reports |

Write down phone models and Android/iOS versions with every result: BLE behaviour varies a lot.
Please keep failed self-test reports; they show where in the connection sequence a problem occurs.

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| `flutter doctor`: "No Java Development Kit (JDK) found", or Gradle: "JAVA_HOME is not set" | No JDK is installed or Flutter cannot see it. Install a full JDK 17+ (for example Temurin 21), set the user environment variable `JAVA_HOME` to its folder, and open a new terminal. To make an already-open terminal work too: `flutter config --jdk-dir="C:\path\to\jdk"` (undo with `flutter config "--jdk-dir="`) |
| `flutter doctor`: "`flutter` on your path resolves to C:\src\flutter\bin\flutter, which is not inside your current Flutter SDK checkout at C:\flutter" | `C:\flutter` is a junction (a folder alias) to `C:\src\flutter`. Flutter resolves the alias, compares it with the unresolved path and warns, although it is the same folder. Put the real folder (`C:\src\flutter\bin`) on PATH instead of the alias |
| Gradle fails with `jlink` or `Error: could not open ... jvm.cfg` | `JAVA_HOME` points at a JRE or an incomplete JDK. Use a full JDK 17+ |
| Gradle: `Failed to find target with hash string 'android-37'` | `permission_handler` 13.x (or another plugin that hard-codes compileSdk 37) was added. Stay on 12.x |
| "Permission needed" banner stays | Tap **Allow Bluetooth**; if the system no longer asks, use **Open settings**. On Android 11 and older also switch the phone's Location on |
| The microphone / camera says it is "switched off" | You refused it with "don't ask again" earlier. Tap **Open settings** and turn it on for دەمەتەقێ |
| Phones never find each other | Check both are open and in the foreground; Bluetooth on; within a few metres; on Android 11 and older the Location switch; some phones cannot advertise (the app says so) |
| Connects, then drops, "status 133" | Common on some Android phones. Toggle Bluetooth on both, move closer; the app retries by itself |
| Messages stay Pending | There is no route yet (the other phone is not connected or reachable); they are sent when one appears |
| A picture shows "Receiving... n %" for a long time, or "could not be received" | Bluetooth is slow, a hop is weak, or a piece was lost on every path (see the limits table). Ask the sender to send it again |
| "Could not decrypt or verify" | Tampered or corrupted data, or encrypted for a different key (for example after the other person reset their identity). See the security log |
| A flutter test fails on its own but passes again | The simulated-radio tests use millisecond-scale timeouts; do not run them while a build or another test run is going |

## Look and feel, icon, screenshots

The look is a Telegram-inspired interface in two appearances, **dark** and **light** (chosen with the sun / moon button or under Settings > Appearance; a new install follows the phone). The dark one: a near-black page (`#0E0E0E`), flat charcoal layers
(`#1A1A1C`, `#242427`), one blue (`#3390EC`, a deeper `#2874C8` where white text sits on it), white and
grey text, rounded bubbles, almost no borders and no shadows except under the bottom bar. No Telegram
name, logo or asset is used. The light one is a pale page (`#F1F3F6`) with white layers and the same blue. Every colour comes from `lib/theme/app_palette.dart`, read from the theme as `context.palette` (a test fails if a
screen writes one of its own); the flat surfaces, buttons, sheets and dialogs are in
`lib/theme/surfaces.dart`. [docs/ui-design.md](docs/ui-design.md) has the whole design: the bar, the
tokens, the Kurdish and Arabic type, what was removed from the screens, the Settings menu, and what has
not been checked.

**Fonts.** Kurdish and Arabic are drawn with **Noto Sans Arabic**, bundled in `assets/fonts/` (four
weights, SIL Open Font License, shown under Settings > About > Open-source licences), so every phone
shows the same letters instead of whatever it has. It is the first font of the Kurdish and Arabic
themes and the fallback of the English one; a test checks it has every letter of every message. The
right-to-left layouts follow the language (never forced), a message and the text field keep the
direction of what is written, and the arrows turn with the language.

**The bottom bar** (`lib/widgets/nav_bar.dart`) is a rounded pill that floats clear of the screen's
edges and of the system bar. It was built with the craft rules of the design skills in use here,
translated to Flutter:

* It answers the finger at once: an item shrinks the moment it is touched (before the tap ends), and
  is chosen when the finger lifts. Sliding away cancels.
* People switch places all day, so the page changes at once (with a short fade-in); only the
  highlight moves. It moves on a critically damped spring (no bounce, about a third of a second) that
  starts from where it is, at the speed it has, so choosing another item in mid-move never jumps. Each
  icon's colour and size follow the highlight's position, so they cannot disagree, and no item changes
  size when it is chosen.
* With "remove animations" the highlight jumps; with high contrast the bar gets an outline; the words
  under the icons stay small however large the system text is (the rest of the app scales fully);
  every item is at least 44 points and is read out with its unread count ("Private, 2 unread").
* Back closes the search, then goes to the first place, and only then leaves the app.
* When the keyboard opens the page resizes, so the room's field sits right above it and the bar stays
  under it.

**The ghost and the movement.** Where there is nothing yet, a small drawn ghost keeps company
(`lib/widgets/ghost_mark.dart`): asleep on an empty list, curious while something is searched for,
sheepish when nothing is found, pleased when the security log is empty, and smiling on the first page of
a new chat ("Say hello to Bob"). A tiny one sits beside the public room's note that messages disappear
after six hours, and the lines of that room grow fainter over their last hour. Movement follows a few
rules (`lib/theme/motion.dart`): what appears starts fast and settles, what goes is quicker than what
came, nothing people do all day long is animated, and **everything stops with the phone's "remove
animations"** setting. The reply bar, the pinned message and the note about delete requests open and close
instead of jumping; a selected message's tick fills in. Every round button is at least 44 points.

**Launcher icon:** a glass bubble with a smiling face on dark navy. To rebuild the icon files from
`assets/icon/source.png`:

```powershell
dart run tool/make_icons.dart            # writes icon_full.png, icon_foreground.png, assets/branding/logo.png
dart run flutter_launcher_icons          # writes the Android and iOS icons
```

**Screenshots.** `flutter test test/visual/` draws the real screens (with the bundled font, the
Roboto of the Flutter SDK for Latin letters and the Material icons, on a 390 x 844 phone) to
`build/shots/*.png`. `test/visual/redesign_shots_test.dart` draws the public room (empty, alive, the
list of rooms), the lists and every page of the settings in Kurdish, Arabic and English
(`home_*.png`); `screenshots_test.dart` draws:
first-run page, the home screen on each of its places (with the bar), private chat with picture and voice bubbles, attach sheet,
permission explanation, recording bar, group chat, group details, new group, public room with lines,
the empty room with the radar, the rooms sheet, create-room dialog, people, settings and Nearby. They
are a visual check only; the test never compares images. Others draw the Kurdish and Arabic screens
(`test/visual/localization_shots_test.dart`, `ckb_*.png` and `ar_*.png`), the message actions and the
ghost's pages.

## Project layout

```
lib/
  main.dart, app.dart            entry point, app shell, first-run gate
  app_controller.dart            builds and owns every service; publishes small state slices
  core/                          app info, clock, formatting, logging, byte helpers, text direction
                                 (bidi), the byte limit of names
  l10n/                          the three languages: app_en / app_ckb / app_ar .arb (the text), the
                                 generated app_localizations*.dart, Kurdish framework words, labels
  models/                        message, peer, conversation, group, room, media (+ message_preview and
                                 delivery_problem: stored as structure/codes, worded when shown)
  screens/                       home (+ tabs), chat, room (the public room, as a tab and as a page),
                                 groups (create, details), people, settings (the menu, its pages, help,
                                 about), nearby, peer detail, self-test, security log, first run
  widgets/                       composer, message bubble, voice/image views, prompts, permission
                                 explanations, connection indicator, status pills, radar, banners,
                                 the ghost (ghost_mark, empty_state), reveal (open/close), language picker
  theme/                         app_palette (the colours of the light and dark appearances), app_theme (sizes,
                                 the fonts per language, the themes), theme_controller (the choice, kept in
                                 SharedPreferences), theme_host (the circular reveal),
                                 surfaces (flat panels, buttons, sheets, dialogs), motion (how things
                                 move), app_icons
  device/                        permissions, photo and video picker, image shrinker, voice recorder/player,
                                 notifications, gallery saver, share sheet, background keep-alive
  services/                      bluetooth_service, discovery_service, message_service,
                                 message_actions (delete / edit requests), public_chat_cleanup,
                                 notification_coordinator, group_service, room_service, media_service,
                                 encryption_service, plugin_ble_radio, ble_self_test, ...
  transport/                     the BleRadio / MeshTransport interfaces (the plugin seam)
  mesh/                          mesh_router, message_queue, duplicate_filter, relay_manager,
                                 peer_table, rate_limiter
  protocol/                      packet, envelope, media chunk, room record and link-frame formats,
                                 fragmentation, constants
  crypto/                        HPKE, AEAD, HKDF, signatures, fingerprints, key store
  database/                      schema and migration, message / group / room / media / outbox repositories
test/                            see "Automated tests"; test/support has the BLE simulation and the UI harness
tool/make_icons.dart             builds the icon files
assets/icon, assets/branding     the glass-bubble icon sources and the in-app logo
assets/fonts                     Noto Sans Arabic (four weights) and its licence
docs/                            architecture, database, protocol, routing, security, testing, build, status
android/, ios/                   generated by Flutter; manifests, Info.plist, Podfile and icons changed;
                                 android/.../KeepAliveService.kt and MainActivity.kt are the only native
                                 code (no Swift)
```

## Documentation

The `docs/` folder goes deeper than this README: the [feature-status report](docs/feature-status.md)
(implemented, partial and deferred, and the deviations from the specification), the
[architecture](docs/architecture.md), the [database](docs/database.md) (diagram, schema, migrations), the
[protocol](docs/protocol.md), [routing and delivery states](docs/delivery-and-routing.md) (including what
Android and iOS allow in the background), the [security model and threat model](docs/security.md), the
[test coverage](docs/testing.md), the [interface design](docs/ui-design.md), the
[real-device test plan](docs/real-device-test-plan.md), the
[voice-call design](docs/voice-calls-design.md), the [languages](docs/localization.md) (Kurdish, Arabic,
English; right-to-left) and [build and debug instructions](docs/build-and-debug.md).
Start from [docs/README.md](docs/README.md).
