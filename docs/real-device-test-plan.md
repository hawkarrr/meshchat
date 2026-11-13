# Testing on real phones

**None of this has been done.** Everything the automated tests cover is simulated (`testing.md`). The
specification requires physical-device testing, in particular for multi-hop delivery (three phones),
background behavior and notifications. This plan is how to do it, and how to record what happens, so the
feature-status report can be updated with facts instead of claims.

## 1. What you need

* **Three Android phones** (two is enough for sections 3 to 6; three for section 7). Different makes and
  Android versions are valuable: at least one with Android 12 or newer and, if possible, one with Android 14.
* An iPhone would test nothing yet: the app has never been built for iOS. Treat iOS as **not started**.
* The APK from `build/app/outputs/flutter-apk/` (see `build-and-debug.md`), installed on every phone.
* A way to see the app's log: `adb logcat` with the phones plugged in, or none (the in-app Diagnostics screen
  and Security log are enough for most checks).
* A second room or a distance of 10 to 30 m with a wall between phones, for the relay test.
* A notebook (or the table at the end) to write down what happened, **including what failed**.

Before each section, on every phone: Wi-Fi and mobile data **off** (the header should say "Offline"),
Bluetooth **on**, Location **on** only for Android 11 and older.

## 2. Setup checks (each phone)

| Check | Expected |
| --- | --- |
| First start explains the app and asks nothing until you press the button | No permission dialog before that |
| Press "Start" | Bluetooth permission (Nearby devices on Android 12+) is asked once, with the app's explanation first |
| First place | The app opens on the public room: `#mesh` at the top with "Searching..." then "1 nearby" under it. Private and Groups show a one-word "Offline" badge and the same connection line |
| Settings > Privacy and security > Permissions | Bluetooth Allowed; Microphone, Camera, Notifications show "Allow" |
| Settings > Notifications | Turn on: the app explains, then Android asks; on Android 13+ allow |

## 3. Direct messaging (two phones, A and B, in range)

1. A and B appear in each other's list ("Available now") within about a minute. Note how long it took.
2. A sends "hello"; B shows it. A's bubble turns **Delivered** (two ticks). Note the delay.
3. Switch Bluetooth **off** on B. A sends "while you were away". A shows **Pending**.
4. Switch Bluetooth **on** on B. The message arrives; A turns **Delivered**. Note how long it took.
5. Force-close the app on B (swipe away), A sends "closed". Open B: does it arrive? (Expected: yes, after
   B reconnects, within the 12-hour window.)
6. Restart B. Open the app: all chats are still there.

## 4. Pictures, voice and video

1. A sends a photo: progress shows on B, then the picture; it opens full screen. Note seconds.
2. A sends a 10-second voice message: plays on B.
3. A records or picks a **very short, low-quality** video under the limit: card with progress on B, then plays.
   Pick a normal phone video: it must be **refused before sending** with the size and the limit. Raise the
   limit in Settings > Privacy and security > Storage and try the 512 KB maximum: note the time it takes.
4. During a transfer, walk B out of range, then back (or switch Bluetooth off and on): the transfer
   **continues**, it does not restart, and the file is complete and plays.
5. B long-presses the picture > **Save to gallery**: the explanation appears, then it is in the phone's gallery
   (on Android 9 and older the phone asks for storage permission). Note what each Android version does.
6. B long-presses > **Share**: the system share sheet opens with the picture.

## 5. Message management

For each: do it on A, then look at B, then look at A again after restarting the app.

* **Reply, edit, forward, pin.** Edit shows "edited" on both. A pin appears only on the phone that pinned.
* **Delete for me:** gone on A only; B still has it.
* **Delete for everyone:** gone on both; A's chat shows nothing in its place. **Delete for everyone with B
  out of range:** A shows "Waiting for B's phone to confirm"; bring B back: it disappears on B and the note
  goes. Take B out of range for **more than 12 hours** (or switch it off overnight): A shows that B did not get
  the request.
* **Select, bulk delete, select all, share, save.**
* **No placeholder anywhere:** not in the list, not in the chat-list preview, not in search, not in pinned.

## 6. Public chat and cleanup

1. Post in `#mesh` on A; B and C see it. Join a second room, post there.
2. Videos are **not** offered in the public room's attach sheet.
3. Leave the app running for **6 hours** (or use a phone whose time you can set forward by 6 hours: remember that
   the clock affects other things too). The posts are gone from the list, search, pin list and preview. A
   private message sent at the same time as the posts is still there. Restart the app after 6 hours:
   anything overdue is removed at once.
4. Settings > Privacy and security > Storage > **Clean public chats now** shows how many were removed.

## 7. Multi-hop (three phones in a line: A - B - C, A and C out of each other's range)

1. Place B between A and C so that A and C cannot see each other. Wait until A shows C as "via relay".
2. A sends C a private message. C receives it. A shows **Delivered** with the hop count in the details.
3. Check that **B has no readable copy and no notification** (B should show no conversation with A or C).
4. Send a group message in a group of A, B and C; and a public message. Check delivery to C.
5. In B's Settings, turn **Help relay messages for others** off. A sends C another message: it must **not** arrive.
   Turn it on again: the next message arrives.
6. Send a small video A to C through B: note the time. It is expected to take minutes.

## 8. Notifications and background (the part most likely to disappoint)

Do each on **every** Android version, and test **both** with and without "Keep the mesh running in the
background".

| Case | Steps | Record |
| --- | --- | --- |
| App on screen | Receive a message | No system notification; the unread badge increases |
| App in background, screen on | Press Home on B; A sends a message | Notification within how many seconds? What does it show for each privacy choice? |
| Chat closed, app in recents, screen locked | Lock B; A sends | Does B vibrate/ring? What does the lock screen show? |
| After 10 min, 1 h, 8 h locked | Repeat | Does it still receive? When does it stop? |
| Foreground service on | Settings > Chats and Bluetooth > Keep the mesh running > on; lock B | A persistent notification is shown; does reception continue longer? |
| Swiped away from recents | Swipe the app away on B; A sends. Once with "Keep the mesh running in the background" on, once off | Expected: on, B still receives (the engine is kept since 2026-11-09) unless the phone maker kills the process; off, no reception until the app is opened. Record what really happens and the phone model |
| Back on the first screen | Press Back on B's Public tab; A sends | Expected: the app goes to the background (not closed) and B keeps receiving while Android lets it |
| Battery restrictions | Settings > Chats and Bluetooth: the battery row; press its button | Expected: the phone's page opens; after choosing "Unrestricted" and coming back, the row says so |
| Force-stop | Settings > Apps > دەمەتەقێ > Force stop; A sends | Expected: no reception. Record |
| Battery saver / OEM battery manager | Turn on battery saver / aggressive mode | Record what stops |
| Notification permission denied | Deny it | Messages still arrive and are counted; no notification; no repeated prompts |
| Tap a notification | Tap it with the app closed and with it open | The right conversation opens |
| Relay does not notify | Run section 7 with B's screen locked | B must show **no** notification for messages it only carries |
| Duplicates | A sends 10 messages quickly | One notification per chat, with a count, not ten |
| Public rooms | Post in `#mesh` from A | No notification by default; one when "Public rooms too" is on |

State the limits you observe in the feature-status report. Do **not** write that background reception works
unless this table shows it on the phones you tried.

## 9. Permissions and failures

* Deny Bluetooth: the app explains and offers the settings; no crash; nothing is sent.
* Turn Bluetooth off during use: the banner says so; chats still open; messages queue.
* Deny microphone / camera / photos: each explains and offers the settings; no crash.
* Deny notifications: see section 8.
* Fill the phone's storage (large files) and try receiving a picture: the app reports and does not crash.
* Corrupt a file: not possible from the app; this is covered by the simulated tests only.

## 10. Languages and the look (a person who reads Kurdish and one who reads Arabic should do this)

The simulation draws Kurdish and Arabic with a Windows font and checks layouts; it cannot say how a **phone** does.

| Check | Expected |
| --- | --- |
| Fresh install, system language English | The app opens in **Kurdish**, right to left, with a language picker at the top of the first page |
| Every letter of Sorani (ڕ ڵ ۆ ێ ە ڤ پ چ ژ گ ک) in names, messages and the interface | Drawn, none as an empty box; the connecting forms look right |
| Type Kurdish and Arabic in a name and a message on the phone's own keyboard | The keyboard offers the letters; the text keeps its order; a 16-letter name fits, a 17th is refused |
| Switch the language in Settings > Language, then open a chat and the public room, with the keyboard open | Every word and the direction change at once; nothing jumps or is cut off |
| English words inside a Kurdish sentence (names, `#mesh`, the version line) | In their own order; the room tag reads `#mesh`, not `mesh#` |
| Large system text (the biggest setting) in Kurdish and Arabic | Everything can still be read and reached; Settings is long but never cut off |
| The notification and the foreground-service notification | In the language of the app; the right way round on the lock screen |
| **Read the translations** | Does each sentence sound right to a native reader? Mark the ones that do not (the .arb files in `lib/l10n/`), starting with Settings and the delete and honesty texts |
| The ghost, the empty pages, the movement | The ghost looks right and does not bob when "remove animations" is on; the reply bar opens and closes smoothly; buttons are easy to hit with a thumb (44 points) |
| Public room lines in their last hour | They are fainter, never unreadable; a selected line is whole |

## 11. What to record

| Field | Example |
| --- | --- |
| Test, date, build | 4.4 resume, 2026-10-20, 0.2.0+2 debug |
| Phones, Android versions | Pixel 7 (14), Galaxy A52 (13) |
| Distance, obstacles | 3 m, line of sight |
| Result | Passed / failed / partly |
| Times | Discovery 35 s; delivery 2 s; 400 KB video 4 min 10 s |
| Anything odd | Notification arrived only after unlocking |

## 12. After testing

Update `feature-status.md`: move a feature to **verified on devices** only for the phones and Android
versions you tried, and write the failures down. Report to the maintainers any phone on which discovery or
connection never worked (the Bluetooth self-test under Settings gives a precise reason).
