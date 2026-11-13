# Testing: what is covered, and what is simulated

**Every automated test in this project is simulated.** The tests run on a development computer. The Bluetooth
radio, the phones' clocks, notifications, permissions, the camera, the microphone, the share sheet, the gallery
and the background service are replaced by fakes (`test/support/`). The simulation is faithful in the logic
(packets, signatures, queues, databases, screens) and says **nothing** about real radios, real Android or
iOS versions, real battery managers or real timing. Where the specification asks for real-device tests, they
are listed in `real-device-test-plan.md` and are **not done**.

Run everything with `flutter test` (1,295 tests, about four minutes; keep the computer awake, a laptop that
sleeps in the middle freezes the run and times tests out).

Legend: **Sim** = covered by automated, simulated tests. **Real** = can only be settled on physical phones.
**Partly** = the logic is simulated; the platform behavior is not.

| # | Specification test area | Status | Where (all under `test/`) |
| --- | --- | --- | --- |
| 1 | Offline messaging between two phones | Sim. Real: pending | `services/message_service_test.dart` (handshake, keys, send, receipt), `app/app_controller_test.dart`, `app/damataqe_scenarios_test.dart` (1), `ui/chat_ui_test.dart` (a message is sent and shows as delivered) |
| 2 | Multi-hop delivery through a relay | Sim. Real: pending (needs 3 phones) | `services/message_service_test.dart` ("through a relay"), `mesh/mesh_router_test.dart`, `app/damataqe_scenarios_test.dart` (2, 5, 9), `integration/ble_mesh_integration_test.dart`, `services/video_service_test.dart` (the largest video crosses a relay), `services/relay_opt_out_test.dart` |
| 3 | Messages persist after Bluetooth is disabled | Sim | `app/app_controller_test.dart` (Bluetooth switched off and on), `app/local_storage_test.dart`, `database/database_helper_test.dart` (queue survives re-opening) |
| 4 | Retrying queued messages after reconnection | Sim | `services/message_service_test.dart` ("queued -> sent -> delivered", expiry and retry), `mesh/mesh_components_test.dart` (back-off, quotas), `services/media_service_test.dart` ("the recipient walks out of range and back: sending resumes") |
| 5 | Recovery after app closure and phone restart | Partly: a real SQLite file and real media files are closed and reopened. Real: a phone restart is not tested | `app/local_storage_test.dart`, `database/database_helper_test.dart` ("persistence across an application restart"), `app/app_controller_test.dart` (settings, identity and history survive restarting), `app/background_notifications_test.dart` (every setting survives) |
| 6 | Image and video transfer without internet | Sim. Real: pending | `services/media_service_test.dart` (pictures, voice), `services/video_service_test.dart` (video, 512 KB, 342 chunks), `app/damataqe_scenarios_test.dart` (7: private, group and room, byte for byte), `ui/chat_ui_test.dart`, `ui/video_gallery_ui_test.dart` |
| 7 | Interrupted transfer recovery | Sim | `services/media_service_test.dart` ("a relay link that drops mid-transfer", "a lost chunk is resent", "the recipient walks out of range and back"), `services/video_service_test.dart` ("cut half way is finished when the phones meet again"), `app/damataqe_scenarios_test.dart` (9). **Not tested:** an explicit chunk re-request (not implemented) |
| 8 | Duplicate-message prevention | Sim | `services/message_service_test.dart` ("a duplicated packet creates exactly one entry"), `mesh/*`, `app/damataqe_scenarios_test.dart` (6), `database/message_repository_test.dart`, `services/media_service_test.dart` ("repeating packets changes nothing") |
| 9 | End-to-end encryption | Sim (not independently reviewed) | `crypto/hpke_test.dart` (RFC 9180 vector), `crypto/aead_test.dart`, `services/encryption_service_test.dart`, `services/media_service_test.dart` ("the bytes never appear on the air in the clear", "a bystander ... can neither read nor keep"), `app/damataqe_scenarios_test.dart` (8) |
| 10 | Recipient-only private notifications | Sim | `app/background_notifications_test.dart` ("a phone that only relays a message never notifies about it"), `services/notification_coordinator_test.dart` |
| 11 | Notifications while the app is in the background | **Partly**: the "app is away" state is a flag the test sets. Real: **not tested** (background, chat closed, screen locked) | `app/background_notifications_test.dart`, `services/notification_coordinator_test.dart`, `ui/settings_background_ui_test.dart` |
| 12 | Platform-specific background restrictions | **Real only.** Nothing here can reproduce Doze, OEM battery managers, force-stop or iOS suspension | Only the app's own logic is tested: the service is started and stopped with Bluetooth, a refusal is reported (`app/background_notifications_test.dart`) |
| 13 | Public-chat cleanup after six hours | Sim (fake clock) | `services/public_chat_cleanup_test.dart`, `database/message_management_test.dart` ("public chat expiry"), `services/room_service_test.dart` |
| 14 | Private messages survive public-chat cleanup | Sim | `services/public_chat_cleanup_test.dart` ("private chats, groups, contacts and keys are never touched", "a private photo stays with its file"), `database/message_management_test.dart` |
| 15 | Delete for Me | Sim | `services/message_actions_test.dart`, `database/message_management_test.dart`, `ui/message_actions_ui_test.dart` |
| 16 | Delete for Everyone | Sim | `services/message_actions_test.dart` (private, group with admin, public room, forged requests), `ui/message_actions_ui_test.dart` |
| 17 | Deletion events delivered after reconnection | Sim | `services/message_actions_test.dart` ("a phone that is out of reach keeps it until the request arrives", "a member who was away ends up without it", "expired, not done"), `ui/message_actions_ui_test.dart` ("a delete request still waiting for the other phone is shown, not hidden") |
| 18 | No visible deletion placeholders | Sim | `services/message_actions_test.dart` (no row left), `ui/message_actions_ui_test.dart` (no bubble left; "Original message deleted" appears only in a reply's quote, with no content) |
| 19 | Pin removal after message deletion | Sim | `database/message_management_test.dart`, `services/message_actions_test.dart`, `services/public_chat_cleanup_test.dart` (pins of expired messages), `ui/message_actions_ui_test.dart` |
| 20 | Bulk selection and deletion | Sim | `ui/message_actions_ui_test.dart` (select, count, deselect, bulk delete, back leaves selection, bulk copy), `ui/message_extras_ui_test.dart` (select all, bulk pin, share, save) |
| 21 | Editing and offline synchronization conflicts | Sim | `database/message_management_test.dart` (older/newer, out of order, wrong author), `services/message_actions_test.dart` (edit offline, two edits, forged), `protocol/envelope_test.dart` |
| 22 | Forwarding and replying after the original is deleted | Sim | `services/message_actions_test.dart` ("the answer stays when the question is deleted", "the copy is independent"), `ui/message_actions_ui_test.dart` ("a quote of a message that was deleted shows no content") |
| 23 | Permission denial and Bluetooth disconnection | Partly: fake permission service and simulated radio. Real: pending | `app/app_controller_test.dart`, `ui/app_flow_test.dart`, `ui/chat_ui_test.dart` (microphone/camera/photos denied or switched off), `app/background_notifications_test.dart` (no notification permission: nothing shown, nothing asked) |
| 24 | Storage limits and corrupted attachments | Sim | `services/media_service_test.dart` (wrong checksum, wrong length, chunk count mismatch, tampering relay), `services/video_service_test.dart` (limits), `services/file_media_store_test.dart`, `app/local_storage_test.dart`, `ui/settings_background_ui_test.dart` (storage screen) |

## Other automated coverage

* **Protocol:** every envelope and packet format, size limits, truncation at every length, random garbage
  (`test/protocol/`).
* **Database:** schema, constraints, migrations from real v1 and v2 databases, repositories
  (`test/database/`).
* **UI:** screens, navigation, overflow on a 320-px-wide phone with 160 % text, the keyboard not rebuilding
  the message list (`test/ui/`). **Visual checks:** `test/visual/*` write PNG files to `build/shots/` for a
  person to look at; they are not assertions.
* **Languages:** `test/l10n/` keeps the three `.arb` files in step (same keys and blanks, right alphabet,
  Western digits, no stray English, Arabic plurals); `test/app/language_test.dart` the default, saving and
  the services' wording; `test/ui/language_ui_test.dart` the screens in Kurdish and Arabic and the
  directions; `test/ui/rtl_tour_test.dart` a walk through nearly every screen at 320 x 640 px and 150 %
  text, failing on any overflow. See `localization.md`. The wording itself is **not** judged by any test.
* **The redesign** ([ui-design.md](ui-design.md)): `test/ui/nav_bar_ui_test.dart` (the floating pill: order, size
  and place, right-to-left order, motion and its interruption, press feedback, unread, Back, keyboard, reduced
  motion, high contrast, 2x text on the smallest phone, a tablet), `home_landing_ui_test.dart` (the app opens on
  the public room after the first page and for a returning person, in each language, the first page is short),
  `settings_menu_ui_test.dart` and `licences_test.dart` (the menu, each page, Kurdish layout, the font's licence),
  `public_room_ui_test.dart` (the room as a chat, skeleton, empty room, rooms, the unread rule, the keyboard
  not rebuilding the messages, the field following the language typed), `state_views_test.dart` (skeletons
  and the error state), `theme_tokens_test.dart` (no colour or font written outside the theme),
  `typography_test.dart` (the bundled font, its letters, contrast of every text colour), and
  `test/app/conversation_feed_test.dart` (a feed that cannot read, one that is not on screen).
* **The mesh as a whole:** `test/integration/mesh_topology_test.dart` - lines of seven and eight phones (the
  hop limit), a star, and an Android / iPhone line writing 20 bytes at a time, with every layer running on the
  simulated radios. See [platform-and-mesh-review.md](platform-and-mesh-review.md).
* **The ghost and the movement:** `test/ui/ghost_ui_test.dart` (moods and sizes, where the ghost appears, the
  first page of a chat, fading lines, the bars that open and close, the tick, all with and without "remove
  animations") and `test/ui/touch_targets_test.dart` (44 points).
* **Appearance** ([ui-design.md](ui-design.md), section 3a): `test/ui/palette_test.dart` (contrast of every
  pair of text and ground, in the light and the dark palette), `test/theme/theme_controller_test.dart` (the
  choice, its storage, what a choice means on a phone), `test/ui/theme_switch_ui_test.dart` (the circular
  reveal, both directions, a second tap ignored, "remove animations", the phone going light or dark under
  "System default", the Appearance page in three languages, and that the open page, the tab and a typed draft
  survive a switch) and `test/ui/theme_tokens_test.dart` (no screen writes a colour). `test/visual/theme_shots_test.dart`
  draws about twenty screens in both appearances to `build/shots/theme_*.png` for a person to look at.
* **Quicker to use** (section 3b): `test/ui/page_transitions_test.dart` (300 ms on Android, native on iPhone),
  `test/ui/keyboard_dismiss_ui_test.dart` (dragging a room or a chat puts the keyboard away; checked to fail
  without the setting) and the settings read in `test/database/message_repository_test.dart`.
* **Limits:** more than 16 deleted at once, the caps on early edits and remote deletion records, a selection
  with a video forwarded to a public room, the settings note when notifications are not allowed, and coming
  back to the app while a background job fails.
* **Security:** forged signatures, tampered ciphertext, replay, wrong-sender receipts, non-member group
  messages, unauthorized delete and edit requests.

## What the tests cannot show

* Real BLE range, throughput, latency, connection limits, pairing quirks per phone model, scanning limits.
* Android behavior under Doze, battery optimisation, OEM task killers, force-stop; foreground-service
  behavior and its notification; Android 13+ notification permission; Android 14 foreground-service types.
* iOS in any form (the app has never been built or run on an iPhone).
* Notifications on a real lock screen.
* The gallery, share sheet, camera, video playback and `flutter_secure_storage` on a real device.
* Battery use, heat and long-running stability.
* Cross-platform behavior (Android with iPhone).

## Known sources of flakiness

The UI tests mix a simulated clock (the widget tester's) with the real event loop (SQLite and the simulated
radios). They wait with `UiHarness.until` for something to be true rather than for a fixed time; a test
that asserts straight after an action, without waiting, can fail under load. Timing-sensitive tests
(`ble_self_test_test.dart`, `ble_mesh_integration_test.dart`: the ones with tiny 20-byte writes) fail on some
machines and on some days, also on an idle one (the README says which failed in the last run); use
`--concurrency=2` and run a failing one alone before suspecting the code.
