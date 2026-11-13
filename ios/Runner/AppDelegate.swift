import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // flutter_local_notifications needs the app delegate to receive notification
    // taps (it forwards them to the plugin); without this, tapping a message
    // notification would open the app but not the chat.
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    excludeAppDataFromBackups()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  /// The chat database and the media files live in Application Support (that is
  /// where path_provider puts them on iOS), without encryption of their own. Like
  /// on Android (allowBackup="false"), they must not leave the phone through an
  /// iCloud or computer backup. Excluding the folder excludes everything in it.
  /// The identity keys are in the Keychain as "this device only" and never move
  /// to another phone anyway.
  private func excludeAppDataFromBackups() {
    let files = FileManager.default
    guard var folder = files.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
      return
    }
    do {
      try files.createDirectory(at: folder, withIntermediateDirectories: true)
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try folder.setResourceValues(values)
    } catch {
      NSLog("Damatqe: could not exclude the app's data from backups: \(error)")
    }
  }
}
