# Review: the mesh, the Bluetooth link, Android and iOS

A reading of the code and the platform configuration, plus what the automated tests (all simulated)
prove about them, written on 2026-10-20 after the interface redesign. It is a review, not a field
test: **no real phone was used, and iOS cannot be built on the development machine.** Every
statement says which of the two it rests on. What still has to be tried on hardware is the
[real-device test plan](real-device-test-plan.md).

## 1. The mesh topology

### How the phones see each other

Each phone keeps a local view (`lib/mesh/peer_table.dart`), built only from evidence:

* **Neighbours** - phones with an authenticated Bluetooth link right now. Shown as "Directly
  connected".
* **Routes** - "I heard a *signed announcement* from phone X, relayed through neighbour N, k relays
  away". A route is believed for 100 seconds, is dropped at once when N disconnects, keeps at most
  three routes per destination (fewest links first), and is never saved to disk. Shown as "Via relay".
* Everything else is "Offline". Nothing is inferred from history.

Announcements are signed, sent every ~30 s and when a neighbour connects, live 2 minutes, and are
passed on at most 3 relays. So a phone *knows* routes up to about three relays away; phones farther
than that are still reachable, because a message with no known route is flooded.

### How a packet travels (`mesh_router.dart`, `relay_manager.dart`)

| Packet | Where it goes |
| --- | --- |
| Direct message, receipt | The recipient if it is a neighbour; else the next hop of a fresh route; else a flood to at most 4 neighbours |
| Group and public-room message | Every neighbour that does not have it, once each; kept and offered to phones that arrive later (store, carry, forward) |
| Announcement, room announcement | Flooded once to the neighbours connected now; not kept |

Safeguards, each covered by a test: a hop limit signed by the sender (5 for messages, 3 for
announcements, and a hard 7 whatever a packet claims), a persisted duplicate filter that also holds a
phone's own packet ids (a loop cannot re-deliver), never sending a packet back to where it came from
or to its author, signature check *before* a packet is remembered (a forged copy cannot suppress the
real one), per-neighbour and per-author rate limits, strikes that disconnect a neighbour that sends
bad packets, bounded storage per author, packet lifetimes clamped by the receiver, and the option to
stop relaying for others.

### What the tests show

`test/mesh/*`, `test/integration/*` and `test/app/damataqe_scenarios_test.dart` run real routers over
a simulated Bluetooth world. They cover: one link, two, a chain, a ring (no broadcast storm, one
copy per phone), a relay that cannot read what it carries, a relay that tampers (caught), a relay
that drops out mid-transfer, a recipient that arrives later, routes learned and forgotten, and
messages that expire. New in this review, `test/integration/mesh_topology_test.dart`, with every layer
running (discovery, handshake, announcements, routing, encryption):

* **Seven phones in a line** (six links): delivered, five relays, the receipt comes back.
* **Eight phones in a line** (seven links): stopped by the hop limit at the seventh phone; the last
  phone gets nothing, and the sender keeps the message waiting instead of pretending.
* **A star** of four phones that cannot hear each other, through one hub: four conversations at
  once, each message exactly once, the hub reads none of them.
* **A line of five alternating Android and iPhone** (simulated) writing 20 bytes at a time: a
  600-character message arrives intact.

Reading the numbers: a limit of 5 means a packet may be relayed five times, so it reaches a phone
**six links** away; a seventh link is refused. That is a deliberate bound on how far, and how much,
one message can spread. It also means: in a crowd the mesh is a few hops across, not a city.

### Things to know (design choices, not bugs)

* Every phone that relays is a phone that can be seen to be present: the first thing exchanged on a
  connection, before authentication, is the public key and nickname ([security.md](security.md)).
* Group and public-room traffic goes to *every* neighbour: in a dense crowd that is a lot of copies,
  bounded by the duplicate filter, the per-author rate limit, the hop limit and the storage cap - but
  not measured on real radios.
* A message to a far phone is flooded to at most 4 neighbours per attempt, and a phone gives up on a
  directed packet it carries for someone else after 8 attempts. A sender keeps trying until the
  message expires (12 hours) or is acknowledged.

## 2. The Bluetooth link

`bluetooth_service.dart` (the link), `plugin_ble_radio.dart` (the plugin glue), `ble_radio.dart` (the
seam the tests replace).

* **Roles.** Every phone is both central and peripheral at once, with one service and one
  characteristic (WRITE + NOTIFY). Nothing else is advertised, and the adapter is never renamed.
* **Life of a link.** Connect, discover, subscribe, (Android) ask for an MTU of 517, then a
  **handshake**: both sides send HELLO and prove they own their key (AUTH). Until then a link carries
  nothing. Writes are "with response", which gives back-pressure. A frame is cut into chunks of
  `MTU - 3` bytes and reassembled with a size limit.
* **Limits.** 6 links started by this phone, 2 more accepted, 4 in the handshake at once, a 10 s
  handshake timeout, a ping after 15 s of silence, a link declared dead after 45 s, a frame send
  timeout of 30 s, and 5 strikes before a link is dropped.
* **Platform differences the glue handles.** Android's central does not ask for a larger MTU by
  itself (the app does) and settles a moment before the first operation (status 133 avoidance);
  iOS' `connect` never times out (the app times it out after 20 s); several streams exist on
  Android only; the GATT server comes back empty after Bluetooth is toggled (service re-added,
  advertising restarted); a peripheral can drop a central on Android only.
* **Verified by tests** (against a simulation that reproduces the plugin's documented behaviour and
  *records any contract violation*; the topology tests assert there are none): discovery, connect,
  handshake, forged or bad keys refused, MTU and chunking down to 20-byte writes, keepalive, dead
  links, reconnect, duplicate links between two phones, Bluetooth switched off and on, permission
  and power problems, the self-test.
* **Not verified:** everything real. How long phones take to find each other, how many links a
  given phone really sustains, throughput (a picture or a video may take minutes), battery, and what
  different makes do. The in-app **Bluetooth self-test** (Settings > Chats and Bluetooth) is the tool
  for this.

## 3. Android

Checked in the project files, and (APK) in the built packages:

| Item | Finding |
| --- | --- |
| Bluetooth permissions | Android 12+: `BLUETOOTH_SCAN` with `neverForLocation`, `BLUETOOTH_CONNECT`, `BLUETOOTH_ADVERTISE`; Android 11 and older: `BLUETOOTH`, `BLUETOOTH_ADMIN` and location (needed there for scanning; the app never reads the location). `uses-feature` bluetooth_le is required, location not |
| Internet | **None** in the release APK (`aapt2 dump permissions`, checked on the build of 2026-10-20). The debug APK has `INTERNET` from Flutter's own manifest (hot reload). The release APK does hold `ACCESS_NETWORK_STATE`, only to say whether the phone has any connection (the one-word "Offline" badge); it allows no network use |
| SDK | `minSdk` 24 (Android 7.0), `targetSdk` and `compileSdk` 36; ABIs arm64-v8a, armeabi-v7a, x86_64; release APK 63.5 MB |
| Other permissions | `RECORD_AUDIO`, `CAMERA` (asked only when used, after an explanation), `POST_NOTIFICATIONS` (13+), `WRITE_EXTERNAL_STORAGE` up to API 28 (save to gallery), `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_CONNECTED_DEVICE` |
| Background | Optional foreground service of type `connectedDevice`, off by default; the notification is in the app's language. Without it Android may stop Bluetooth work soon after the screen locks |
| Backups | `allowBackup=false`, data-extraction rules set: the database and keys are not backed up |
| Layout | `configChanges` includes locale and layout direction, so a language change does not restart the app; `adjustResize` with Flutter's own inset handling: the room's field rises above the keyboard (tested with the widget tester's keyboard) |
| Label | "دەمەتەقێ" (the launcher label) |
| Signing | The release build is signed with the **debug key** (see `build.gradle.kts`): fine for testing, not for a store |

## 4. iOS

Checked only in the project files; **never built or run**:

| Item | Finding |
| --- | --- |
| `Info.plist` | All five usage texts are present (`NSBluetoothAlwaysUsageDescription`, microphone, camera, photo library, add to photo library); no location, no contacts. Translated into Kurdish and Arabic (`ckb.lproj`, `ar.lproj`), and `CFBundleLocalizations` lists the three languages (2026-11-09) |
| Background | No `UIBackgroundModes`: the app works while it is open and does not pretend otherwise. iOS suspends it soon after it leaves the screen, and a suspended app is neither found nor reached |
| Deployment target | iOS 15.0 in the Xcode project. **Found and fixed in this review:** the Podfile still said 13.0 (it now says 15.0, so the pods are built for the same system as the app); its comment about the compiled-in permissions was out of date and is corrected |
| Permissions compiled in | `permission_handler` for microphone, camera, photos and notifications; Bluetooth goes through `bluetooth_low_energy` (its own prompt, shown when the radio is created) |
| Notifications | Initialised without asking at start-up; asked when the person turns them on |
| Name and label | `CFBundleDisplayName` and `CFBundleName` are "دەمەتەقێ" |
| Known platform limits (not bugs) | iOS lets an app advertise only its service UUIDs (and a name), which is all this app advertises; the other phone finds it by scanning for that UUID; the MTU is negotiated by iOS, not requested; Android and iPhone talking to each other has only ever been simulated |

## 5. What this review found

* **Fixed:** the Podfile's iOS minimum disagreed with the Xcode project (13.0 / 15.0), and its comment
  still said notifications were not compiled in.
* **No defect found** in the routing, duplicate handling, hop limits or link handshake by reading and
  by the new topology tests. That is a statement about the logic and the simulation; real radios are
  the risk that remains.

## 6. What must still be tried on hardware

In this order, with the [test plan](real-device-test-plan.md) for the steps:

1. Two Android phones (one on Android 12+, one on 14): find each other, handshake, a message, a
   picture, Bluetooth off and on. Note the time to find each other.
2. Three Android phones in a line (the middle one between two rooms): relaying, the receipt, the
   "Via relay" label.
3. The same with the screen locked, with and without "Keep the mesh running in the background".
4. An iPhone: only after the app has been built for it on a Mac. Then: Android to iPhone both ways,
   iPhone in the foreground and in the background.
5. Kurdish and Arabic on the real screens: the font, the bar, the keyboard, and a native speaker
   reading the wording.
