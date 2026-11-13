# Build, run, debug, and the permission configuration

## 1. Prerequisites

* Flutter 3.47.x (Dart 3.13.x). Check with `flutter --version`.
* A **full JDK 17 or newer** (Eclipse Temurin 21 is what this project was built with). A JDK without `jlink`
  makes the Android build fail. Point `JAVA_HOME` at it.
* Android SDK with the platform Gradle asks for (accept the licences: `flutter doctor --android-licenses`).
* iPhone builds need macOS with Xcode. **The iOS project has never been built or run.**

## 2. Commands (from the `offline_mesh_chat` folder)

```powershell
$env:JAVA_HOME = "C:\Path\To\jdk-21"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"

flutter pub get                 # dependencies
flutter analyze                 # expected: No issues found!
flutter test                    # 1,295 simulated tests (about four minutes)
flutter build apk --debug       # build/app/outputs/flutter-apk/app-debug.apk
flutter build apk --release     # build/app/outputs/flutter-apk/app-release.apk (debug key unless android/key.properties exists)
```

Do not run `flutter test` while a Gradle build runs, or several test runs at once: the simulated-radio tests
use millisecond-scale timeouts. On a busy or slow machine use `flutter test --concurrency=4`.

The app is built for **Android and iOS only**. There is no Windows, macOS, Linux or web version: SQLite
(`sqflite`), the Bluetooth roles and `dart:io` are not set up for them. `flutter create` must not be run on
this folder to add them (it also writes a counter-app `test/widget_test.dart` that breaks the test run).

### Check the plugins on a real phone

```powershell
flutter test integration_test -d <device-id>
```

`integration_test/plugins_on_phone_test.dart` opens SQLite, the keystore, the media folder, notifications and
the background-service channel on the phone, and starts the app. Use a test phone: the last test opens the
app's real storage. Run it first on every new phone model, before the Bluetooth tests of
`real-device-test-plan.md`.

### Signing a release for other people

Without a key, release builds are signed with the debug key (fine for testing, refused by stores). Create a key
once and keep it and its passwords safe (losing it means the app can never be updated):

```powershell
keytool -genkey -v -keystore $env:USERPROFILE\damataqe-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then create `android/key.properties` (it is ignored by Git, never commit it):

```
storePassword=<the store password>
keyPassword=<the key password>
keyAlias=upload
storeFile=C:\\Users\\<you>\\damataqe-upload.jks
```

`flutter build apk --release` (or `flutter build appbundle`) now signs with it. Change the application id
(`android/app/build.gradle.kts`) and the iOS bundle id before the first public release; neither can change
afterwards.

The app's text is in `lib/l10n/app_*.arb`. After editing those files run `flutter gen-l10n`, which writes the
Dart files kept next to them in `lib/l10n/` (`flutter pub get` and `flutter run` do it too, but do not rely on
that before a test run); `flutter test test/l10n` then checks that Kurdish, Arabic and English still agree.
See `localization.md`.

### Run on two or three phones

```powershell
flutter devices                              # note the ids
flutter run --release -d <phone-a-id>
flutter run --release -d <phone-b-id>        # second terminal
```

Use `--release` or `--profile` for Bluetooth tests: debug builds run the cryptography much slower and can
distort timing. To install without a cable: copy the APK to the phone, or `adb install -r <apk>`.

### See what the phone is doing

* In the app: **Settings > Chats and Bluetooth > Bluetooth self-test** (a step-by-step check of one phone finding, connecting to
  and talking to another), **Settings > Privacy and security > Security log** (forged or unreadable messages, failed identity
  checks, changed keys, refused edit/delete requests), the **header pill** and the banner under it (Bluetooth
  off, permission needed, unsupported), **Settings > Chats and Bluetooth > The mesh in the background** (what this phone has passed
  on).
* From a computer: `adb logcat -s flutter` shows the in-app log lines (they never contain keys, secrets or
  message text).
* The package id is `com.example.offline_mesh_chat`; to inspect the database of a **debug** build:
  `adb shell run-as com.example.offline_mesh_chat ls files` and pull `offline_mesh_chat.db`.

### Screenshots of the screens

`flutter test test/visual/screenshots_test.dart test/visual/message_actions_shots_test.dart` writes PNG files
to `build/shots/` (they are a visual check, not assertions).

## 3. Dependencies of note

| Package | Used for | Note |
| --- | --- | --- |
| `bluetooth_low_energy` | BLE central and peripheral | The only maintained plugin evaluated that has both roles |
| `sqflite` (`sqflite_common_ffi` in tests) | SQLite | See `database.md` for why not Drift |
| `cryptography`, `flutter_secure_storage` | Primitives; Android Keystore / iOS Keychain | |
| `permission_handler` ^12 | Microphone, camera, photos, notifications | Kept below 13 (13 needs compileSdk 37, which fails with this toolchain) |
| `record`, `audioplayers`, `image_picker`, `image` | Voice, pictures, videos | |
| `video_player` | Playing a received video | Plays from the app's private file |
| `flutter_local_notifications` | Local notifications | Needs Java library desugaring (enabled in `android/app/build.gradle.kts`) |
| `gal` | "Save to gallery" | |
| `share_plus` | The system share sheet | |

All five Android plugins above **compile** (a debug APK builds). That is all that has been verified: none has
run on a real phone. The Gradle build prints a warning that `bluetooth_low_energy_android` applies the Kotlin
Gradle plugin; future Flutter versions will require it to migrate.

## 4. Permissions and configuration

### Android (`android/app/src/main/AndroidManifest.xml`)

| Permission | Why | When it is requested |
| --- | --- | --- |
| `BLUETOOTH_SCAN` (`neverForLocation`), `BLUETOOTH_CONNECT`, `BLUETOOTH_ADVERTISE` | Find, connect to and be found by nearby phones (Android 12+) | When the person presses Start on the first-run page, after the app's explanation |
| `BLUETOOTH`, `BLUETOOTH_ADMIN`, `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION` (`maxSdkVersion` 30) | The same, on Android 11 and older, which tie scanning to Location. The app never reads the location | The same moment |
| `RECORD_AUDIO` | Voice messages | When the person starts recording, after an explanation |
| `CAMERA` | Taking a photo or recording a video to send | When the person chooses the camera |
| `POST_NOTIFICATIONS` | Message notifications (Android 13+) | When the person turns notifications on in Settings, after an explanation |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_CONNECTED_DEVICE` | "Keep the mesh running in the background" (a foreground service of the connected-device type with a visible notification) | Only when the person turns that switch on, with the app on screen |
| `WRITE_EXTERNAL_STORAGE` (`maxSdkVersion` 28) | "Save to gallery" on Android 9 and older | Only when the person saves, and the phone asks |

No `INTERNET` permission is declared; debug and profile builds get one from Flutter's own manifest for hot
reload; a release build has none (checked on the built release APK with `aapt2 dump permissions`). Plugins add
`ACCESS_NETWORK_STATE` (connectivity, display only), `VIBRATE` and `WAKE_LOCK` (notifications), and an implied
`READ_EXTERNAL_STORAGE` (Android 9 and older only) that comes with `WRITE_EXTERNAL_STORAGE`. Android backup and device transfer are off. The service is declared as
`<service android:name=".KeepAliveService" android:foregroundServiceType="connectedDevice" android:exported="false">`.

Photos are picked with the system photo picker (no storage permission). Android 10+ saves to the gallery
through MediaStore without a permission.

### iOS (`ios/Runner/Info.plist`, `ios/Podfile`) - not built

* `NSBluetoothAlwaysUsageDescription`, `NSMicrophoneUsageDescription`, `NSCameraUsageDescription`,
  `NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription` are present, each in the app's words.
* `ios/Podfile` switches on the `permission_handler` parts for microphone, camera, photos and notifications
  (and leaves every other permission compiled out).
* **No `UIBackgroundModes`** are declared and there is no Swift code: the app does not try to run in the
  background on iPhone. Adding `bluetooth-central` and `bluetooth-peripheral` and Core Bluetooth state
  restoration is future work, and would need a real iPhone to verify.

## 5. Native code

* `android/.../KeepAliveService.kt`: a foreground service that only holds the process alive and shows the
  required notification. All Bluetooth logic stays in Dart.
* `android/.../MainActivity.kt`: a method channel `damataqe/keep_alive` (`start`, `stop`, `isRunning`).
* The service is started only from the Dart side while the app is on screen (Android 12+ forbids starting one
  from the background) and is **not restarted** by the system if the process is killed.

## 6. Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| Gradle: "jlink" not found | JDK without `jlink`; use a full JDK 17+ |
| `compileSdk 37` not found | `permission_handler` 13 was installed; keep ^12 |
| A test fails once under load | Run it alone; the simulated radio uses short timeouts |
| Two phones never see each other | Check Bluetooth is on, the permission is allowed, Location is on (Android 11-); try Settings > Chats and Bluetooth > Bluetooth self-test |
| Notifications never appear | Allow them (Settings > Privacy and security > Permissions); check "Message notifications" is on; the app must **not** be on screen |
| The background service does not start | Android refuses to start it unless the app is on screen; try again from the app |
