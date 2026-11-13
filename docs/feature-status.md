# Feature-status report

How to read this: **Implemented** means the code exists and automated, *simulated* tests pass (see
`testing.md`). **Nothing in this report has been verified on a real phone**, so "implemented" never means
"known to work over real Bluetooth". **Partial** means part of the requirement is missing, limited or
unverifiable. **Deferred** means it was not done, on purpose, with the reason.

Summary: the messaging, storage, security, deletion/edit/pin/reply/forward, selection, search, public-chat
cleanup, relay opt-out, notification policy and storage-management features are implemented and tested in
simulation. **Background reception, background relaying and notifications while the app is closed are
implemented only as far as the platforms' APIs allow and are completely untested on devices. iOS is not
built, has no native code and no background mode.** Video is limited to very small clips. Voice calling is a
design document only. There is no export/backup and no encryption of the local database. The app speaks
**Kurdish (Sorani, the main language), Arabic and English**, right to left where needed; the wording of the
two Arabic-script languages is **not reviewed by a native speaker** and has never been seen on a phone
(`localization.md`).

## Deviations from the specification (and why)

| Specification | What was done | Reason |
| --- | --- | --- |
| The app is called **GhostChat**, with a cute classic ghost theme, a ghost icon | The app is called **دەمەتەقێ** (Damatqe) - the name the owner chose in October 2026 - with a Telegram-inspired look in a dark and a light appearance (see `ui-design.md`) and its glass-bubble icon, and **has a drawn ghost** (a small mascot in four moods) for empty pages, the first page of a chat and the public room | The owner asked for this look and this name. **Open question**: a ghost launcher icon? (only the icon changes; no logic) |
| SQLite with **Drift** | SQLite with **sqflite** | Preserves a complete, tested data layer; same schema, constraints, migrations. See `database.md` |
| Kotlin and **Swift** native code for Bluetooth and background services | Bluetooth through the `bluetooth_low_energy` plugin; one small Kotlin foreground service; **no Swift** | A plugin gives both BLE roles on both platforms. Custom native Bluetooth code could not be verified without devices. iOS cannot be built on the development machine |
| Two notification display settings | Three (name and message / name only / nothing) | A middle option is the most useful default; the two required are included |
| Message states saved, queued, relayed, delivered, failed | queued ("Pending"), sent, delivered, failed, plus received / undecryptable | "Saved" and "queued" are the same stored state; "relayed" = "sent" (handed to a neighbour; the app cannot tell a relay from the recipient). Mapping and honesty rules in `delivery-and-routing.md` |
| Pins "personal or shared" (to be defined) | **Personal**: never sent | Simplest honest model; needs no permissions and cannot be forged |
| Videos "where practical" in public chat | Videos only in private chats and groups | A video flooded through a public room would have to be carried by every phone in range |
| (Not in the specification) | The user later asked for **Kurdish and Arabic, with Kurdish the main language**. Kurdish is Central Kurdish (Sorani, Arabic script); Arabic and English are kept; digits stay Western | The request. Dialect, script and digit choices are open questions in `localization.md` |

## Feature by feature

| § | Requirement | Status | Notes and evidence |
| --- | --- | --- | --- |
| 1 | Flutter/Dart UI and logic | Implemented | |
| 1 | Kotlin for Android-specific services | Partial | `KeepAliveService.kt` (foreground service) and a method channel. Compiles; **untested on a phone** |
| 1 | Swift for iOS | **Deferred** | No Swift. iOS has never been built |
| 1 | SQLite with Drift | **Deviation** | sqflite, see above |
| 1 | App-private file storage | Implemented | Pictures, voice and videos in `media/` in the private folder |
| 1 | Local notifications | Implemented (untested on devices) | `flutter_local_notifications`; fake sink in tests |
| 1 | Established crypto libraries; Keystore/Keychain | Implemented (not reviewed) | `cryptography`, HPKE per RFC 9180 with its test vector, `flutter_secure_storage` |
| 1 | No Firebase / cloud / push | Met | None used; no INTERNET permission in release |
| 2 | Fully offline operation (identity, chats, queue, resume) | Implemented | Every feature works with no internet; `ui/message_extras_ui_test.dart` for the indicator; `app/damataqe_scenarios_test.dart` (10) |
| 2 | Clear distinction between offline operation and reachability | Implemented | The list headers show a one-word "Offline" badge (its tooltip and Help explain that no internet is needed) and, separately, how many phones are reachable; "Pending" is "saved but not delivered" |
| 3 | Discover devices, connections, encrypted exchange, relays | Implemented (simulated) | Real BLE behavior **unknown** |
| 3 | Stable ids, dedupe, persistent queues, acks, retry, hop limit, resume, validation | Implemented (simulated) | `docs/protocol.md`, `delivery-and-routing.md` |
| 3 | Bluetooth disabled, permissions denied | Implemented (simulated) | Banner, queue, settings shortcuts |
| 3 | Chunks for larger payloads | Implemented | 1536-byte chunks; up to 342 per video |
| 3 | Networking separate from UI | Met | `architecture.md` |
| 3 | No guaranteed range or delivery | Stated | In the UI, the README and these documents |
| 4 | Normalised schema with the listed concepts | Implemented | Different table names for some; mapping in `database.md` |
| 4 | Migrations, indexes, constraints, diagrams | Implemented | v1 -> v2 -> v3 tested from real old databases |
| 4 | Save before sending; save before notifying; survive restart; queue while BT off; retry; no duplicates | Implemented | Real SQLite file closed and reopened in tests; the phone restart itself untested |
| 4 | Interrupted operations and database errors | Partial | Transactions and atomic file writes; disk-full and corruption on a phone not tested |
| 4 | Backup or export through an explicit, secure user action | **Deferred** | No export exists |
| 4 | Message states | Implemented with different names | See above |
| 5 | Private chats: identity, keys, authentication, E2EE, history | Implemented (not independently reviewed) | |
| 5 | Text, images, **videos** | Implemented; video limited | 512 KB cap, no transcoding |
| 5 | Replay and injection protection | Implemented | Signatures, seen-set, expiry |
| 5 | Threat model, key management, verification, limitations | Documented | `security.md` |
| 6 | Public chat, kept separate from private, relayed | Implemented | `#mesh` plus created rooms |
| 6 | Text, images, videos | Text, pictures, voice. **No video** | See deviations |
| 6 | Selection, pin, forward, delete in public chat | Implemented | Delete for everyone only for your own messages |
| 6 | Six-hour cleanup: public only, never private; UI, search, previews and pins updated; no reappearance; at start and resume; idempotent; defined handling of queued messages and incomplete media; clock policy | Implemented (fake clock) | `services/public_chat_cleanup_test.dart`, `app/background_notifications_test.dart` (coming back to the app removes what ran out of time); policy in `PublicChatCleanup` and `delivery-and-routing.md` (section 5). It runs at start, when the app returns to the screen, and about once a minute |
| 6 | Remove public attachments only if unreferenced | Met | A file belongs to one message; a forward is a separate file |
| 7 | Select, send, receive images and videos; view images; **play videos** | Implemented; **video playback itself untested** | Picking, sending, receiving, verifying, the card and saving are tested. The full-screen player (`video_player`) needs a platform plugin and has **never been run**, in tests or on a phone |
| 7 | **Thumbnails** for videos | **Partial** | A card with size and play button; no preview frame (would need a decoder per message) |
| 7 | Progress, resume, retry, delete media | Implemented | Resume: private chats per chunk; groups rely on flooding; "Send again" for failed media; storage screen deletes media |
| 7 | App-private storage; metadata in SQLite; chunking; hashes; incomplete/corrupted detection; correct linking | Implemented | |
| 7 | **Avoid loading entire videos into memory** | **Partial** | Bounded by the 512 KB cap, but a video is held in memory to send/assemble |
| 7 | **Explicit chunk re-request** | **Deferred** | Per-chunk acks and retries in private chats only |
| 7 | Configurable size limits | Partial | Video sending limit 128/256/512 KB; pictures and voice fixed at 64 KB |
| 7 | Gallery-export permissions and restrictions explained | Implemented | In-app explanation before saving; `build-and-debug.md` for the permissions |
| 8 | Android: notifications from locally received data; permissions; save before notify; recipient only; no duplicates | Implemented (simulated) | |
| 8 | Android: foreground service; BLE handling across screen lock, activity closure, background, reconnection | **Partial, untested** | A foreground service exists and is switchable; what Android does with it is unverified |
| 8 | Explain battery restrictions and termination behavior; do not promise after force-stop | Documented | `delivery-and-routing.md` section 6, Settings text |
| 8 | **iOS**: background modes, state restoration, notification permission | **Deferred / not started** | No background mode, no Swift; notification permission prompt exists but the app cannot be built here |
| 8 | Two notification privacy settings | Implemented (three) | |
| 8 | (Polish) Say so when notifications are on here but the phone does not allow them | Implemented | A note with an "Allow" button under the switch in Settings > Notifications; gone once allowed |
| 8 | Real-device notification tests | **Not done** | `real-device-test-plan.md` |
| 8 | A notification for a message that is later deleted or expired | Implemented | The conversation's notification (one per chat) is taken back when the message it was about is deleted here, deleted at its author's request, or expires; it is also cleared when the chat is read |
| 9 | Relay opt in/out | Implemented | Settings switch, persisted, applied at start; activity shown |
| 9 | Forward without decrypting; queues; resume | Implemented (simulated) | |
| 9 | Background relaying on Android/iOS | **Partial, untested / not started** | Same as section 8; not promised |
| 10 | Delete for me / for everyone, authenticated, queued, honest status, groups define who | Implemented | Author, or group admin; 48 h |
| 10 | Telegram-style clean deletion; data-layer removal | Implemented | No placeholder in list, search, previews, pins; only the minimal id record remains |
| 10 | Configured deletion time limits | Partial | 48 h, a code constant (`MessagePolicy`), not a setting |
| 10 | (Hardening) Big selections, floods | Implemented | A delete-for-everyone of more than 16 messages goes out batch by batch and each batch is removed here right after it was queued; edits that arrived early (500) and memos of other phones' deletion requests (5,000) are capped, oldest first; a selection with a video is refused as a whole before anything is sent to a public room, and the forward list greys the rooms out |
| 11 | Pin/unpin, banner, navigation, list, text and media, removal on delete/expire | Implemented | Personal pins |
| 12 | Selection mode, indicator, count, select all, bulk delete/forward/copy/save/share/pin, cancel, no accidental activation | Implemented | Taps only select; media does not open or play while selecting |
| 13 | Context menu: reply, copy, forward, pin/unpin, select, delete for me/everyone, share, save, edit, details, retry, cancel | Implemented | "Delete" opens the dialog with both choices |
| 14 | Reply with preview and navigation; forward with attribution; safe when the original is gone | Implemented | A deleted original leaves no content in any quote |
| 15 | Edit own text; versions; offline conflicts; previews and search updated; documented limit | Implemented | 48 h; newest version wins; no history shown |
| 16 | Search in a conversation; filter by kind; saved media | Implemented | Text and captions; pictures, videos, voice, "from me" |
| 16 | Filter by any sender | **Partial** | Only "from me" |
| 16 | Search across all conversations | **Partial** | The home search finds chats, groups, rooms and people by name, not message text |
| 16 | Details: sent time, local save time, status, only what is known | Implemented | Their clock and this phone's time are separate rows |
| 17 | Cute classic **ghost** theme, ghost icon | **Partial** | A drawn ghost (`widgets/ghost_mark.dart`: sleepy, curious, happy, sheepish; floats gently, still with "remove animations") is on every empty list, a search with nothing found, an empty security log, the first page of a private chat or group ("Say hello to Bob") and beside the public room's six-hour note. The name is now دەمەتەقێ and the colours are the Telegram-inspired palette, dark or light ([ui-design.md](ui-design.md)). **Not done:** a ghost launcher icon (still the glass bubble) |
| 17 | (Polish) Movement, touch targets | Implemented (simulated) | One set of motion rules (`theme/motion.dart`: fast start, quicker exit, nothing animated that people do all day, everything off with "remove animations"); the reply/edit bar, the pinned message and the delete-request note open and close instead of jumping; a selected message's tick fills in; public lines in their last hour fade towards one half; every round button is at least 44 points (`test/ui/touch_targets_test.dart`). How it feels on a phone is not judged |
| 17 | (Added by request) Light and dark appearance, or follow the phone; a sun / moon button with a circular reveal; the choice kept | Implemented (simulated, never on a phone) | `animated_theme_switcher` and `shared_preferences`; `theme/app_palette.dart`; `test/ui/theme_switch_ui_test.dart`, `test/ui/palette_test.dart`, `test/theme/`; screenshots of about twenty screens in both appearances were looked at. The reveal's speed on a phone is unmeasured; `ui-design.md` section 3a |
| 17 | (Added by request) Kurdish (main), Arabic and English; right-to-left layouts; a language picker on the first page and in Settings | Implemented (simulated, wording unreviewed) | 829 messages in each language kept in step by `test/l10n`; `test/ui/rtl_tour_test.dart` walks nearly every screen in Kurdish and Arabic at 320 px and 150 % text with no overflow; `docs/localization.md`. Not seen on a real phone; no native-speaker review |
| 17 | Rounded bubbles, sections, list and search, discovery, indicators, statuses, previews, progress, pinned banner, selection, menus, confirmations, relay and notification settings, storage, permission status, offline indicator | Implemented | Screenshots from tests in `build/shots/` |
| 17 | Responsive Android and iOS layouts | Partial | Checked on simulated phone sizes (320 to tablet) with large text; no iOS |
| 18 | E2EE, integrity, key management, replay/duplicates, file integrity, validation, relay control, permission explanations, no analytics | Implemented | |
| 18 | **Encryption of sensitive local data** | **Deferred** | The database and files are plaintext at rest (SQLCipher not adopted); see `security.md` |
| 18 | Configurable file-size limits | Partial | See section 7 |
| 19 | Offline voice calling: design | Documented only | `voice-calls-design.md`; **not implemented** (allowed by the specification) |
| 20 | Automated tests | Implemented (simulated) | `testing.md` |
| 20 | Real-device testing plan | Documented | **Not executed** |
| 21 | Modular structure | Met | `architecture.md` section 2 |
| 22 | Phases 1 to 10 | Partial | Everything that can be done without devices was done; the phases that require three physical devices (3, 4, 7, 9 on hardware) were **not** run |
| 23 | Deliverables: architecture and DB diagrams, schema and migrations, protocol, routing, security, structure, source, permissions, tests, real-device instructions, README, build instructions, this report | Delivered | `docs/` and `README.md`. Swift sources: none |

## Known limitations (also stated in the app)

* Range, speed and delivery over real Bluetooth are **not measured**. A connected chain of phones within radio
  range is needed; no range such as "one or two kilometres" is promised.
* Background reception and relaying depend on the operating system and are **not guaranteed**; they are not
  possible after a force-stop, and not on iPhone in this version.
* Videos are not shrunk by the app: only very short, low-quality clips fit; a 512 KB clip can take minutes per hop.
* A delete request cannot reach a phone that is out of range, or remove a screenshot or a saved copy.
* Plaintext local storage; trust on first use until a safety number is compared; metadata is visible to nearby
  phones and relays.
* No independent security review.
* The Kurdish and Arabic text was written without a native-speaker review; some terms (for example "relay",
  "safety number", "public room") are choices a fluent reader may want to change. How a phone's own fonts draw
  the Sorani letters is unverified. Technical details inside error messages (the self-test's reasons, the
  security log's detail lines) stay English.
* The app has never run on an iPhone, and the Android parts have never run on a phone.

## Changes of 2026-11-09

A review found, and this round fixed (all tested in simulation; the Kotlin and Swift parts could not be
compiled on the machine that made them, which has no Android SDK and is not a Mac):

* Leftovers of an unfinished attempt at Windows and web builds were removed (`windows/`, `web/`, an empty
  `lib/core/database_init*.dart`, Flutter's counter-app `test/widget_test.dart`, which broke `flutter analyze`
  and `flutter test`); `sqflite_common_ffi` is a test-only dependency again. The app targets Android and iOS.
* "Keep the mesh running in the background": the Flutter engine is now kept for the life of the process
  (`MainActivity.provideFlutterEngine`), so swiping the app away no longer stops the mesh while the notification
  says it runs; Back on the first screen moves the app to the background instead of closing it; the switch
  turns itself off when the service did not really start (`isRunning` is now asked).
* Settings > Chats and Bluetooth shows whether Android's battery optimisation applies, with a button to the
  phone's page for it.
* A phone that speaks another protocol version is recognised from the first byte of its HELLO, turned away
  once, not called again for ten minutes, written to the security log once, and a dismissible notice says
  which phone needs an update. Rule for future versions: see `protocol.md`.
* "Delete all local data" no longer loses the chosen language at the next start.
* A voice recording also ends when its file nears the 64 KB cap (for encoders that overshoot 16 kbit/s).
* iOS: notification taps reach the app (`AppDelegate` sets the notification delegate); the database and media
  are excluded from backups; `CFBundleLocalizations` and Kurdish/Arabic permission texts were added.
* Release signing reads `android/key.properties` when it exists; `integration_test/` checks the plugins on a
  real phone; `.github/workflows/ci.yml` analyzes, tests and builds the APK once the project is on GitHub.

Still open and needing the owner: the application id (`com.example...`), a real signing key, a licence, Git.

### The appearance and the interface (second round, 2026-11-09)

* **Light appearance and a switch.** The colours moved from constants into a `ThemeExtension`
  (`AppPalette`, read as `context.palette`), with a dark and a light palette; the sun / moon button (Settings,
  first run), Settings > Appearance (System default, Light, Dark), the circular reveal from
  `animated_theme_switcher`, and the choice kept in `SharedPreferences`. How it works, where to change the
  colours and how to add the button elsewhere: `ui-design.md` section 3a.
* **Found while doing it:** the media views assumed a dark page (white waveform, translucent-black
  placeholders and video card, the play button on the blue bubble), and the message text relied on the default
  colour being white on the blue bubble; fixed (`onBlue`, three palette tokens). The dark appearance looks as
  it did, except that the play button on a voice message you sent is now a white disc.
* **Smoother to use:** dragging a conversation (room, private chat, group), the search results, the lists
  under the search field, the forward sheet, the new-group page and the first-run page puts the keyboard
  away; the settings are read in one query and the database and media folder open side by side when the app
  starts (less to wait for before the first screen; not measured on a phone).
* **Pages open and close in 300 ms on Android**, not Flutter's 450 ms (`theme/page_transitions.dart`: the
  platform's own motion, predictive back included, only quicker; iPhone keeps its native slide and swipe
  back). How it feels on a phone has not been judged.
* **Not done, on purpose:** no haptics beyond the switch, no change to how lists or tabs animate.
* **Not verified:** everything on a real phone (the reveal's smoothness, the status-bar colours), and the
  Kurdish and Arabic words of the ten new messages.

## What to do next (in order)

1. Run `real-device-test-plan.md` on three Android phones and record the results here.
2. Decide the GhostChat naming and theme question (a design task).
3. Build and test on an iPhone; add background modes and Core Bluetooth state restoration only if tests show
   they help.
4. Have a fluent Kurdish reader and a fluent Arabic reader go through the translations (the `.arb` files;
   start with Settings and the warnings), and look at the app on a real phone in both languages.
5. Optional: chunk re-request for groups, video thumbnails, database encryption, an explicit encrypted
   export, a per-sender search filter, message-text search across all chats.
