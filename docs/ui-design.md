# Interface design (the 2026-10 redesign)

The look of دەمەتەقێ (Damatqe) after the redesign: a Telegram-inspired interface in a dark and (since
2026-11-09) a light appearance, a floating bottom bar with the public room first, a Settings menu with
one page per subject, and Kurdish and Arabic set in a font that ships inside the app. This page says
what each part is, where it lives in the code, and how it was checked. What has **not** been checked
(a real phone, a native speaker) is listed at the end.

Telegram is a reference for how a dark messenger feels, not a source: no Telegram name, logo, icon or
asset is used. The blue (`#3390EC`) is a colour, not a brand.

## 1. Where the app opens

The first place of the home screen is **Public**: the built-in `#mesh` room as a chat, with a header,
the messages as bubbles and a field. It is the first item of the bar (the rightmost in Kurdish and
Arabic) and the place the app opens on, for a person who has just finished the first page and for one
who comes back. Nothing is shown in between except the startup splash while the database opens.

| Item of the bar | Place | Notes |
| --- | --- | --- |
| Public | The public room (`RoomChat`, embedded) | The header's name opens the list of rooms: switch, join a nearby room, create one, leave one |
| Private | Private chats (`PrivateTab`) | People who can be reached now, the chats; search, People, new message |
| Groups | Group chats (`GroupsTab`) | Invitations, the groups; new group |
| Settings | The Settings menu (`SettingsTab`) | See section 5 |

The specification this redesign followed also names **Content / Stories** and **Calls**. This app has
neither (there are no stories, and voice calls exist only as a design document), so those two items are
not in the bar: an item that opened nothing would be a dead button. They can be added to the same
`AppNavBar` when the features exist.

Public shows three states, all real:

* **Loading** - a grey skeleton of bubbles while the messages are read (`ChatSkeleton`);
* **Empty** - the ghost, "No messages yet", and the plain statement that what is written is public;
* **Error** - if the messages cannot be read from the database: the ghost looking sheepish, what
  happened, and a Try again button (`ErrorState`, `FeedState.failed`). A Bluetooth problem is shown by
  the radio banner above the room, with the button that fixes it.

A room that is only kept ready behind another tab does not mark its messages as read (`isActive` of
`ConversationFeed`): they count on the badge of the Public item and are read when the person comes back.

## 2. The bar

`lib/widgets/nav_bar.dart`. A rounded charcoal pill that floats 16 points in from the sides and 12 above
the bottom edge (inside the safe area), 64 points high, with a soft blue pill behind the current item.

* Selected: blue icon and word, the icon a tenth larger; not selected: grey. Every item is the same size
  whether chosen or not, so nothing shifts.
* Motion: the highlight moves on a critically damped spring (no bounce), the colour and size follow it,
  the item shrinks while a finger is on it. With "remove animations" the highlight jumps; with high
  contrast the bar gets an outline.
* Right to left: the first item sits at the start edge, so at the right in Kurdish and Arabic; the
  highlight knows which side to start from.
* Keyboard: the home screen resizes for it, so the field of the room sits right above the keyboard and
  the bar stays under it. The floating button of the two lists hides while it is up.
* Unread counts on the three chat items; `99+` beyond 99; spoken as "Private, 2 unread".

## 3. Colour, type, shape

The colours are in `lib/theme/app_palette.dart` (one palette per appearance, read from the theme as
`context.palette`), the rest of the theme in `lib/theme/app_theme.dart`; no screen writes a colour of its
own (a test reads the sources and fails if one does). The values below are the dark appearance; section
3a has the light one.

* **Surfaces:** page `#0E0E0E` (a faint blue light in the top corner), layers `#1A1A1C`, `#242427`,
  `#2E2E32`; no card borders, no shadows except under the bar.
* **Blue:** `#3390EC` for icons, links and the current item; `#2874C8` for what carries white text (a
  button, the bubble you sent), so white keeps 4.5 : 1; `#6CB2F5` for small text.
* **Status:** green directly connected, blue through a relay, grey offline, amber pending, red errors.
* **Contrast:** checked by tests (`test/ui/typography_test.dart`): text, secondary and muted text on
  every layer, white on the blue fills, the status colours on the layers.
* **Shape:** radii 12 / 16 / 20 / 28 (`AppRadii`), spacing in steps of 4 (`AppSpace`), a smallest target
  of 44 (`AppSizes`; `test/ui/touch_targets_test.dart`).
* **Bubbles:** the ones you sent are blue on the right, the others charcoal on the left; no line round
  them; the time at the bottom; the delivery state in white on the blue. In a group and in the public
  room the writer's name is on top in their own colour (in the public room with the first characters of
  their id, because names are not unique).
* **Lists:** flat rows, 52-point avatars, the unread count as a blue pill, a green dot on the avatar of
  someone who is connected directly (blue through a relay).

## 3a. Light and dark (2026-11-09)

**What the person sees.** A sun / moon button at the top of Settings and on the first-run page switches
between the light and the dark appearance, the new one spreading out from the button in a circle (as in
Telegram). Settings > Appearance has the three choices - *System default* (follows the phone, also while
the app is open), *Light* and *Dark* - and the new look spreads from the row that was tapped. A new
install follows the phone. The choice is kept (`SharedPreferences`, key `theme_mode`) and is read before
the database opens, so the splash is already in the right appearance. "Delete all local data" leaves it
alone, like the language. With "remove animations" on, the look just changes.

**How it works.**

| Part | File | What it does |
| --- | --- | --- |
| `AppPalette` | `lib/theme/app_palette.dart` | Every colour of one appearance, as a `ThemeExtension`: `AppPalette.dark`, `AppPalette.light`. Widgets read it with `context.palette.text` |
| `buildAppTheme` | `lib/theme/app_theme.dart` | `ThemeData` for a language and a brightness (`lightTheme()`, `darkTheme()`), built once each. `AppColors` keeps only what is the same in both (over a picture, avatar gradients) |
| `ThemeController` | `lib/theme/theme_controller.dart` | The choice (`ThemeMode`), its storage, and which brightness a choice means on a phone. Reached as `AppScope.of(context).theme` |
| `ThemeHost` | `lib/theme/theme_host.dart` | Puts the app under the `animated_theme_switcher` package: `ThemeProvider` (holds the theme, runs the reveal), `ThemeSwitchingArea` (the covered area: everything under `MaterialApp`) and, in the buttons, `ThemeSwitcher` |
| `ThemeToggleButton`, `switchThemeMode` | `lib/widgets/theme_toggle.dart` | The sun / moon button, and the one function every control calls to change the appearance |
| `AppearancePage` | `lib/screens/appearance_page.dart` | The three choices |

Things the package does not do, and what is done about them (the comments in `theme_host.dart` have the
detail, and `test/ui/theme_switch_ui_test.dart` checks each):

* It cannot set a theme without a reveal. A change that must not be revealed (language, the phone going
  light or dark, "remove animations") gives the provider a new seed, which starts it again from the theme
  the app now asks for.
* Its area moves its child while the reveal runs. The child is `MaterialApp`'s Navigator, which has a
  `GlobalKey`, so every page, the place of the bar, a typed draft and the scroll positions survive a
  switch. Anything put in the area without a key of its own would be rebuilt.
* It takes a picture of the screen before changing the theme, so nothing may rebuild the app between the
  tap and the picture: `DamataqeApp` does not listen to the choice, only to "swap at once" changes.
* It calls `ui.window`, which Flutter has deprecated but still has (3.47). It compiles; if a later Flutter
  removes it, this package is the thing to replace.

**Where to change colours.** Only in `lib/theme/app_palette.dart`: `AppPalette.dark` and
`AppPalette.light`. Every pair of text and ground is checked for contrast in both
(`test/ui/palette_test.dart`: 4.5 : 1 for text, 3 : 1 for icons), so a value that cannot be read fails a
test. The light palette: page `#F1F3F6`, layers white and `#E9ECF1`, text `#0F1419`, the same blue family
(deeper where it is small text: `#1A63AB`), and status colours deep enough to be read on white
(`#157A48` green, `#A85200` amber, `#C62828` red). What sits on the blue bubble is white in both.

**Adding the button to another screen.**

```dart
import '../widgets/theme_toggle.dart';
...
AppTopBar(title: 'Something', actions: const [ThemeToggleButton()])
```

It works anywhere under the app, in a bar, a sheet or a dialog. For a different control, wrap it in
`ThemeSwitcher.switcher(builder: (context, switcher) => ...)` and call
`switchThemeMode(context, switcher, ThemeMode.dark)`. In new screens use `context.palette` for every
colour (a `const` widget that reads it stops being `const`, which is fine: it rebuilds when the theme
changes).

**Checked.** Contrast of both palettes; the theme built from each; the controller and its storage; the
reveal (a picture under a growing circle, then gone), both directions, a second tap during it ignored,
"remove animations", the phone going light and dark while "System default" is chosen, and that the open
page, the selected tab and a typed draft survive a switch; Kurdish and Arabic; and screenshots of about
twenty screens in both appearances (`flutter test test/visual/theme_shots_test.dart`, written to
`build/shots/theme_*`), which were looked at. **Not checked:** a real phone - how the reveal performs
(it takes one picture of the screen and clips a live page with a moving circle, which should be cheap but
has not been measured), the status and navigation bar colours on Android and iOS, and the Kurdish and
Arabic words of the new strings by a native speaker.

## 3b. Quicker to use (2026-11-09)

* **Pages** open and close in 300 ms on Android (`lib/theme/page_transitions.dart`). Flutter's default there
  is Material 3's fade-forwards at 450 ms; `AppPageTransitionsBuilder` subclasses the platform's own
  builder and changes only the length, so the motion (and predictive back, where the phone and the app opt
  in) is the platform's. iPhone keeps the native slide with the swipe back gesture.
* **The keyboard** goes away when a conversation, the search results or the lists under the search field
  are dragged (`keyboardDismissBehavior: onDrag`), as in every messenger.
* **Startup** has fewer steps before the first screen: the settings are read in one query
  (`MessageRepository.allSettings`) and the database and media folder open side by side.
* The appearance is read before anything else, so the splash is already in it.

Not measured on a phone: how much faster any of this feels. Checked by tests: the durations, the
keyboard (with and without the setting), the single read of the settings.

### Kurdish and Arabic type

The bundled font is **Noto Sans Arabic** (SIL Open Font License; `assets/fonts/`, four weights, the
licence beside it and in Settings > About > Open-source licences). It is the first font of the Kurdish
and Arabic themes and the fallback of the English one, so a Kurdish name inside an English sentence is
drawn with it too. It has no Latin letters and lacks `· — • …`, so Roboto (Android) / the system font
(iOS) draw those. A test reads the font's character table and fails if any letter of any Kurdish or
Arabic message is missing. Letter-spacing is never set on text that can be Arabic script (it would pull
the joined letters apart).

Direction: the app is right to left in Kurdish and Arabic and left to right in English, never forced.
What a person writes keeps its own direction: a message is laid out by its first letter, and so is the
text field while it is typed (English typed in a Kurdish app keeps its punctuation at its end). The
names the app makes (`#mesh`) are isolated so the hash stays in front. The back arrow, the forward
arrow and the chevrons turn with the language; bubbles stay where every messenger puts them (yours on
the right).

## 4. Less on the screen

What was removed from the lists and the chats, and where it went:

| Was on the screen | Now |
| --- | --- |
| A long "Public · not private" paragraph under the rooms list | In the empty room, in the field's hint ("Message #mesh · public") and in Help |
| The "Offline · no internet needed" pill (two lines on a narrow phone) | A one-word badge ("Offline"); the explanation is its tooltip and the Help page |
| "Directly connected. Messages are delivered immediately." strip in every chat | Gone: the header already says it in green. The strip stays for what is not obvious (relayed, offline, waiting for a key) |
| The terminal-style prompt `damataqe/@name` and `<@name>` lines | A header and bubbles; the name you speak under is a small `@name` chip you tap to change |
| Five long points on the first page | Three short points and one short honest note ("Experimental..."); the rest is in Help |
| A single endless Settings page | The Settings menu (below) |
| A globe button in the field, a "Nearby rooms" list in a tab | The room's name opens the list of rooms |

Kept, on purpose: the security and honesty notices (public is public, not audited, tested only with
simulated radios), every error message, every accessibility label, and every essential action.

## 5. Settings

`lib/screens/settings_screen.dart` is the menu; `settings_pages.dart`, `help_screen.dart` and
`about_screen.dart` are the pages. The menu is the profile and one row per subject; no explanation
sits on it.

| Row | Page | What is on it (nothing is duplicated) |
| --- | --- | --- |
| Profile (top) and **Profile and identity** | `ProfilePage` | Name (edit), short id, identity fingerprint (copy) |
| **Language** | `LanguagePage` | The language picker; the menu shows the language's own name |
| **Notifications** | `NotificationsPage` | On/off, what a notification shows, public rooms too; the "not allowed" hint |
| **Privacy and security** | `PrivacyPage` | Permissions; Storage, keep messages for, Security log; Reset identity, Delete everything |
| **Chats and Bluetooth** | `ChatSettingsPage` | How hard to look, Bluetooth self-test, the internet row; relaying, keep running in the background |
| **Help and instructions** | `HelpScreen` | "How it works, and what it cannot do": twelve lines that open |
| **About دەمەتەقێ** | `AboutScreen` | The mark, the name, the version and protocol, the open-source licences |

The specification also lists **Appearance and Theme**. The app has one theme (dark) and no setting for
it, so there is no page for it; a light theme would be a refactor of the palette into a theme extension
(every colour is a `static const` today), which is not part of this work. "Account" is called
**Profile and identity**: there are no accounts.

## 6. Checked how

* `flutter analyze` and the whole test suite (see [testing.md](testing.md)).
* `test/ui/nav_bar_ui_test.dart`, `home_landing_ui_test.dart`: the order, the first place being current
  after the first page and for a returning person, right-to-left order, the pill's geometry, the
  motion, the keyboard, the smallest phone with 2x text, a tablet.
* `test/ui/settings_menu_ui_test.dart`: every row opens its page and Back returns; the pages' contents;
  Kurdish layout.
* `test/ui/public_room_ui_test.dart`: the room as a chat, the skeleton, the empty room, rooms (create,
  join, leave, fall back to `#mesh`), the unread rule, the keyboard not rebuilding the messages.
* `test/ui/theme_tokens_test.dart`: no colour written outside the palette.
* `test/ui/rtl_tour_test.dart`, `language_ui_test.dart`: nearly every screen in Kurdish and Arabic at 320
  points wide and 1.5x text, looking for overflow.
* Pictures (`build/shots/home_*.png`, from `test/visual/`) were looked at in all three languages.

## 7. Not checked

* **Any real phone.** Everything above ran in the widget tester with the real font and icons. How the
  font and the bar look on a given Android or iPhone screen, the real keyboard, and the real
  system bars are unseen.
* **A native speaker has not read the Kurdish or Arabic wording**, including the new menu and page
  titles ("Profile and identity", "Chats and Bluetooth", "Help and instructions" and the onboarding
  text).
* **iOS** has never been built (it cannot be on Windows).
