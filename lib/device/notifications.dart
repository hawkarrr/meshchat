import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// One system notification: which conversation it is about, and exactly what
/// it says. What it says has already been chosen according to the person's
/// privacy setting; the sink shows it as given.
class MessageNotification {
  const MessageNotification({
    required this.conversationId,
    required this.title,
    required this.body,
    this.channelName = 'Messages',
    this.channelDescription = 'New messages and group invitations',
  });

  final String conversationId;
  final String title;
  final String body;

  /// The name and description of the notification channel in the system's
  /// settings, in the language of the app.
  final String channelName;
  final String channelDescription;
}

/// Shows and removes notifications. Behind an interface so everything that
/// decides *whether* to notify can be tested without a phone.
abstract interface class NotificationSink {
  /// Prepares the notification channel. [onTap] is called with the conversation
  /// id when the person taps a notification while the app is running.
  Future<void> initialize({required void Function(String conversationId) onTap});

  /// Shows (or updates) the one notification of a conversation.
  Future<void> show(MessageNotification notification);

  /// Removes the notification of a conversation (it was read).
  Future<void> cancelConversation(String conversationId);

  Future<void> cancelAll();

  /// The conversation whose notification started the app, if that is how it was
  /// opened.
  Future<String?> launchConversation();
}

/// The real thing, through `flutter_local_notifications`.
class PluginNotificationSink implements NotificationSink {
  PluginNotificationSink();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const String _channelId = 'messages';

  /// The channel name the system was last told, so it is told again only when
  /// the language of the app changed.
  String? _channelNamed;

  /// A stable number for a conversation (the platform wants an int). The same
  /// conversation always gets the same one, so a newer notification replaces the
  /// older one instead of piling up.
  static int idFor(String conversationId) {
    var h = 0x811c9dc5;
    for (final unit in conversationId.codeUnits) {
      h = ((h ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return h;
  }

  @override
  Future<void> initialize({required void Function(String conversationId) onTap}) async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        // A white silhouette: Android draws a notification's small icon as a mask.
        android: AndroidInitializationSettings('ic_stat_damataqe'),
        // The person is asked in the app's own words first (see the settings), so
        // nothing is requested when the plugin starts.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) onTap(payload);
      },
    );
    _ready = true;
  }

  @override
  Future<void> show(MessageNotification n) async {
    if (!_ready) return;
    if (_channelNamed != n.channelName) {
      _channelNamed = n.channelName;
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(AndroidNotificationChannel(
            _channelId,
            n.channelName,
            description: n.channelDescription,
            importance: Importance.high,
          ));
    }
    await _plugin.show(
      id: idFor(n.conversationId),
      title: n.title,
      body: n.body,
      payload: n.conversationId,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          n.channelName,
          channelDescription: n.channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.message,
          // The lock screen shows only that something arrived, as the system's
          // own setting for sensitive content decides.
          visibility: NotificationVisibility.private,
          onlyAlertOnce: true,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  @override
  Future<void> cancelConversation(String conversationId) async {
    if (!_ready) return;
    await _plugin.cancel(id: idFor(conversationId));
  }

  @override
  Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }

  @override
  Future<String?> launchConversation() async {
    if (!_ready) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    final payload = details.notificationResponse?.payload;
    return payload == null || payload.isEmpty ? null : payload;
  }
}
