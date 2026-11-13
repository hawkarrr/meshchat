# Languages: Kurdish, Arabic and English

دەمەتەقێ (Damatqe) speaks three languages. **Central Kurdish (Sorani, in the Arabic script) is the main one**: it is what
the app opens in until someone picks another. Arabic is the second, English the third.

| Language | Code | Script | Direction | Role |
| --- | --- | --- | --- | --- |
| Kurdish (Sorani) | `ckb` | Arabic script | right to left | **Main**: the default on a fresh install |
| Arabic | `ar` | Arabic script | right to left | Second |
| English | `en` | Latin | left to right | Third; the language the tests use unless a test asks for another |

> **What has and has not been checked.** The structure (every message exists in all three languages, with the
> same blanks, in the right alphabet), the layouts (a walk through nearly every screen in Kurdish and in Arabic
> on a 320-px-wide phone with 150 % text, with no overflow) and the behaviour (switching, saving, plurals,
> directions) are covered by automated tests, all simulated. **The Kurdish and Arabic wording has not been
> reviewed by a native speaker**, and **nothing has been seen on a real phone**: how the phone's own fonts draw
> the Sorani letters, and whether the keyboard offers them, are unverified. Treat the translations as a careful
> first draft that a fluent reader should go through, starting with the Settings page and the warnings
> ("What this app cannot protect", the delete dialogs).

## How the language is chosen

* Nothing stored yet → **Kurdish** (`AppLanguage.main`). The first-run page has a language picker at the top
  (a row of chips, each in its own language: `کوردی`, `العربية`, `English`), so someone who cannot read the
  default can change it before anything else.
* **Settings > Language** changes it at any time. The choice is saved in the local database
  (`settings` table, key `language`) and survives restarts. An unknown stored value falls back to Kurdish.
* The whole app changes at once, without a restart: texts, text direction, the left/right of every layout, the
  notification wording, and the text of the Android foreground-service notification.
* Code with no `BuildContext` (the services, the notifier, the self-test) gets the current strings through
  `AppController.l10n` / `ServiceContext.strings`, so an error such as "this message is too long" is told in
  the language shown now. In tests the default is English (`AppNode.create(language: ...)` chooses another).

## Where the text lives

| What | Where |
| --- | --- |
| The messages | `lib/l10n/app_en.arb` (the template), `app_ckb.arb`, `app_ar.arb`: 829 messages each |
| Generated code | `lib/l10n/app_localizations*.dart` (produced by `flutter gen-l10n`; kept in the source tree rather than hidden in `.dart_tool`, so it can be read and is there before any tool has run) |
| Settings of the generator | `l10n.yaml` (`preferred-supported-locales: [ckb, ar, en]`, so Kurdish is the first locale) |
| The three languages as a type | `lib/l10n/app_language.dart` (`AppLanguage`: code, native name, direction, `strings`) |
| `context.l10n` | `lib/l10n/l10n.dart` |
| Flutter's own words for Kurdish | `lib/l10n/ckb_localizations.dart` (see below) |
| Names of enum values and states | `lib/l10n/labels.dart` (`DiscoveryMode.localized(l)`, delivery states, kinds of media, and so on) |

### Adding or changing a message

1. Add the key to `app_en.arb` (with an `@key` description if it has blanks), then the same key to
   `app_ckb.arb` and `app_ar.arb`.
2. `flutter gen-l10n` (it writes `lib/l10n/app_localizations*.dart`).
3. Use it as `context.l10n.theKey` in a widget, or `_ctx.l10n.theKey` in a service.
4. `flutter test test/l10n` fails if a language lacks the key, if a blank (`{name}`, `{count}`) is missing or
   misspelled, if the braces are unbalanced, if a Kurdish message uses Arabic-only letters (or the other way
   round), if a message contains non-Western digits, or if a Kurdish or Arabic sentence has Latin words that
   are not on the short allow-list (Damatqe, Bluetooth, KB, ...).

### Adding a language

Add a value to `AppLanguage`, an `app_xx.arb`, the locale to `supportedLocales` and `l10n.yaml`, and an entry in
the language picker's test. If Flutter has no built-in `xx` words (as with Kurdish), add delegates like
`ckb_localizations.dart`. Then walk it through `test/ui/rtl_tour_test.dart` (or an LTR equivalent).

## Decisions worth knowing

* **Central Kurdish needed its own delegates.** `flutter_localizations` has no `ckb`, which would leave
  Material's own words ("Copy", "Paste", "Back", date and time pickers' labels, the scrolling direction)
  English or crash on a missing locale. `ckb_localizations.dart` supplies Widgets, Material and Cupertino
  delegates for `ckb`: right-to-left, the `tall` script category (taller line height for the Arabic script),
  and Sorani words for the text-selection toolbar and tooltips. Everything the app shows comes from its own
  messages; only the framework's tooltips and menus use these.
* **Digits are Western (0 1 2 3 ...) in every language**, and units are Latin (`B`, `KB`, `MB`), clocks are
  24-hour (`lib/core/format.dart`). Arabic-Indic or Kurdish-Indic digits would have made counts, sizes and
  times depend on the language, and safety numbers in particular must read identically on both phones. Many
  Iraqi and Kurdish readers use Western digits in everyday writing, but this is a choice a native speaker may
  want to revisit (see "Open questions").
* **Plurals.** `intl` has no plural rules for Kurdish and falls back to `other`, so Kurdish messages simply use
  one form (the number carries the meaning). Arabic spells out the dual (`=2`), `few` (3 to 10), `many` (11 to
  99) and `other`; where two of them read the same, `other` stands for both. English has `one` and `other`.
  `translations_test.dart` ("Arabic counts the way Arabic does") checks the counts 0, 1, 2, 3, 11 and 100.
* **Dialect and script.** Sorani in the Arabic script, because that is the Kurdish written in Iraq and Iran
  and the one a Kurdish keyboard offers by default. Kurmanji (the Latin-script Kurdish of Turkey and Syria) is
  not included. Whether to add it is an open question.
* **Names are limited in bytes, not letters.** The 32-byte limit comes from the Bluetooth packets: an English
  letter is 1 byte, a Kurdish or Arabic letter 2, an emoji 4. `ByteLimitFormatter` (`lib/core/byte_limit.dart`)
  stops typing at a whole character, and trims pasted text, instead of letting a long Kurdish name be cut
  silently on its way out. A Kurdish name therefore holds about 16 letters.

## Right to left

The language sets the direction of everything below `MaterialApp` (`Localizations`), so the app mirrors by
itself: the back arrow, the list items, the order of rows, drawers and sheets. The code uses *logical* sides
(`EdgeInsetsDirectional`, `AlignmentDirectional`, `BorderDirectional`, `PositionedDirectional`) so a margin on
the "start" side follows the language. Exceptions, on purpose:

* **Message bubbles keep their physical side** (mine on the right, theirs on the left) in every language, as in
  most messengers, but the *text* inside a bubble takes the direction of its own first strong letter
  (`textDirectionOf` in `lib/core/bidi.dart`). A Kurdish sentence in an English phone, and an English one in a
  Kurdish phone, both read correctly. Emoji do not decide the direction.
* **Technical text always reads left to right** (the `Ltr` widget, `lib/widgets/ltr.dart`): ids, fingerprints,
  safety numbers, versions, log lines, the signal bars. Inside a right-to-left screen their `#`, `.` and `/`
  would otherwise jump to the wrong end.
* **The IRC-style line in a public room** (`<@name> text`) isolates the tag with U+2066 and U+2069 so a name in
  one script does not reorder the rest of the line.
* **The bottom bar's highlight** moves from the start edge of the bar, which is the right edge in Kurdish and
  Arabic.

## Stored as codes, not as words

Text that the app *composes* is not saved as a sentence, so it can be shown in the language of the moment
rather than the language at the time:

* The last-message line in a chat list is stored as a small structure (`MessagePreview`: kind, text, author) and
  rendered when drawn: "Photo", "Voice message", "Video" and "You:" change with the language.
* Why a message or file failed is stored as a code (`DeliveryProblem`: `expired`, `nobody_in_range`, ...).
  Rows written before this change hold plain English text; they are shown as they are.

What people wrote is, of course, never translated.

## On Android

The foreground-service notification ("دەمەتەقێ is keeping Bluetooth running ...") and its channel name are
given to the native service from Dart each time it starts and whenever the language changes, so they follow the
language of the app. `KeepAliveService.kt` and `MainActivity.kt` have no text of their own except a last-resort
fallback in English.

## Still English

* Technical details that come from the Bluetooth layer or the protocol parser in error messages (for example
  the reason in the "Self-test" log, or the `detail` line under an entry of the security log, such as
  "neighbour exceeded inbound rate"). The headings, kinds and explanations around them are translated.
* Names that are the product's own (Bluetooth, BLE). The app's name, **دەمەتەقێ**, is written in Kurdish letters
  in every language, English included: it is the launcher label on Android and iOS (they take the label
  from the phone, not from the app's setting), the title of every notification, and the name inside
  every sentence. `AppInfo.latinName` ("Damatqe") exists for the few places that want Latin letters (a
  diagnostics report, the GATT service log).
* The texts the system itself shows around the app: Android's permission dialogs (in the phone's language),
  and on iOS the `NS...UsageDescription` lines of `Info.plist`, which are translated in `ios/Runner/ckb.lproj` and `ar.lproj/InfoPlist.strings` (iOS has never been built, so never seen).
* `docs/`, the README and the code comments.

## Tests

| File | What it covers |
| --- | --- |
| `test/l10n/translations_test.dart` | the three ARB files agree: same keys, same blanks, balanced braces, right alphabet, Western digits, no stray English, Arabic / English / Kurdish counts |
| `test/l10n/helpers_test.dart` | text direction by first strong letter, the byte limit, stored previews and delivery codes, labels, "5 min ago" in each language |
| `test/app/language_test.dart` | default, saving and restoring the language, an unknown stored value, services speaking the language on screen, the chat list reading one stored summary in each language |
| `test/ui/language_ui_test.dart` | a new install in Kurdish and right to left, the bottom bar and its highlight, switching in Settings, the picker on the first page, the 32-byte name field, per-message direction, bubbles keeping their side, the public room's tag, the main screens at 320 px with large text |
| `test/ui/rtl_tour_test.dart` | the walk through nearly every screen in Kurdish and Arabic, 320 x 640 px at 150 % text, failing on any overflow |

## Open questions

* Review of the Kurdish and Arabic wording by a fluent reader (see the note at the top).
* Sorani only, or Kurmanji (Latin script) as well?
* Western digits, or the Arabic-Indic / Kurdish digits?
* Should the name also appear in Latin letters somewhere visible (it is only `AppInfo.latinName` in code)?

## Fonts and typography

Kurdish and Arabic are drawn with **Noto Sans Arabic**, bundled in `assets/fonts/` and declared in
`pubspec.yaml` (Regular, Medium, SemiBold, Bold; SIL Open Font License, text in `assets/fonts/OFL.txt` and in
Settings > About > Open-source licences). It is the first font of the Kurdish and Arabic themes
(`fontsFor` in `lib/theme/app_theme.dart`) and the fallback of the English theme, so a Kurdish name inside an
English sentence is drawn with it too, on Android and iOS alike, whatever the phone has installed.

* It contains every letter the app writes in Kurdish and Arabic, including the Kurdish ones (`ڕ ڵ ۆ ێ ە ڤ پ چ ژ گ
  ک`) and the digits; `test/ui/typography_test.dart` reads the font file's character table and fails if any
  letter of any message of the two languages is missing.
* It has no Latin letters, and lacks the marks `· — • …`; those come from the next font (Roboto on Android,
  the system font on iOS), which is why the Arabic-script themes name Roboto as the fallback.
* Letter-spacing is never set on text that can be Arabic script: it would pull the joined letters apart.
* The theme is built once per language and cached; changing the language rebuilds the app with the other one.

Text direction: the app is right to left in Kurdish and Arabic and left to right in English, never forced.
A message and the text field are laid out by the first letter of what is written; an id tag after a name
(`#79e2`) and a room name (`#mesh`) are isolated so that the hash does not move to the far side. See
[ui-design.md](ui-design.md).
