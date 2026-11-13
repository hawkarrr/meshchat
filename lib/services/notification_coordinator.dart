import '../core/app_info.dart';
import '../device/notifications.dart';
import '../device/permission_service.dart';
import '../l10n/labels.dart';
import '../l10n/l10n.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import 'message_errors.dart';

/// How much a notification gives away. A notification can be read by anyone who
/// can see the lock screen, so the person chooses.
enum NotificationPrivacy {
  /// "Bob: see you at ten". Name and text.
  full,

  /// "Bob - New message". Who, but not what. The default.
  sender,

  /// "Damatqe - You have a new message". Neither who nor what.
  hidden;

  static NotificationPrivacy parse(String? name) => NotificationPrivacy.values
      .firstWhere((p) => p.name == name, orElse: () => NotificationPrivacy.sender);
}

/// What the person asked for.
class NotificationPolicy {
  const NotificationPolicy({
    this.enabled = true,
    this.privacy = NotificationPrivacy.sender,
    this.publicRooms = false,
  });

  /// Show notifications at all (the system permission is checked as well).
  final bool enabled;
  final NotificationPrivacy privacy;

  /// Also notify about public rooms. Off by default: a public room is everyone
  /// nearby talking, and would never stop.
  final bool publicRooms;
}

/// Decides whether an incoming message becomes a notification, and what it
/// says.
///
/// It only ever hears about messages that were addressed to this phone and
/// passed every check: a phone that merely relays a packet never produces one.
/// Nothing is shown while the app is on screen (the unread badges do that job),
/// nothing for a message that could not be read, and nothing for a public room
/// unless the person asked for it.
class NotificationCoordinator {
  NotificationCoordinator({
    required this.sink,
    required this.permissions,
    required this.policy,
    required this.isForeground,
    AppLocalizations Function()? strings,
  }) : strings = strings ?? englishStrings;

  final NotificationSink sink;
  final PermissionService permissions;

  /// The person's choices, read afresh each time.
  final NotificationPolicy Function() policy;

  /// Whether the app is on screen right now.
  final bool Function() isForeground;

  /// The app's text in the language being shown: a notification is worded in
  /// the language of the app when it is shown.
  final AppLocalizations Function() strings;

  static const int _rememberIds = 200;

  /// Messages already notified about, so a message that reaches the phone twice
  /// (or is announced by two paths) is only shown once.
  final List<String> _notified = <String>[];

  /// How many messages of each conversation arrived since its notification was
  /// last cleared.
  final Map<String, int> _unseen = <String, int>{};

  /// The message each conversation's notification is about (the latest one), so
  /// the notification can be taken back if that message is deleted or expires.
  final Map<String, String> _shownFor = <String, String>{};

  /// Handles one incoming notice. Returns whether a notification was shown.
  Future<bool> onNotice(IncomingNotice notice) async {
    final settings = policy();
    if (!settings.enabled || isForeground()) return false;
    if (notice.verifiedFailure) return false;
    if (notice.type == ConversationType.room && !settings.publicRooms) return false;
    final id = notice.messageId;
    if (id != null) {
      if (_notified.contains(id)) return false;
      _notified.add(id);
      if (_notified.length > _rememberIds) _notified.removeAt(0);
    }
    if (await permissions.status(AppPermission.notifications) != PermissionOutcome.granted) {
      return false;
    }
    final count = notice.isInvite ? 1 : (_unseen[notice.conversationId] = (_unseen[notice.conversationId] ?? 0) + 1);
    await sink.show(_content(notice, settings.privacy, count));
    if (id != null) _shownFor[notice.conversationId] = id;
    return true;
  }

  MessageNotification _content(IncomingNotice n, NotificationPrivacy privacy, int count) {
    final l = strings();
    final who = (n.sender ?? '').trim();
    final channelName = l.notifyChannelName;
    final channelDescription = l.notifyChannelDescription;
    switch (privacy) {
      case NotificationPrivacy.hidden:
        return MessageNotification(
          conversationId: n.conversationId,
          title: AppInfo.name,
          body: n.isInvite
              ? l.notifyHiddenInvite
              : count > 1
                  ? l.notifyHiddenMany(count)
                  : l.notifyHiddenOne,
          channelName: channelName,
          channelDescription: channelDescription,
        );
      case NotificationPrivacy.sender:
        return MessageNotification(
          conversationId: n.conversationId,
          title: n.title,
          body: n.isInvite
              ? l.notifySenderInvite
              : count > 1
                  ? l.notifySenderMany(count)
                  : l.notifySenderOne,
          channelName: channelName,
          channelDescription: channelDescription,
        );
      case NotificationPrivacy.full:
        final text = n.mediaKind != null ? n.mediaKind!.label(l) : (n.preview ?? '').trim();
        final line = n.type == ConversationType.direct || who.isEmpty ? text : '$who: $text';
        return MessageNotification(
          conversationId: n.conversationId,
          title: n.title,
          body: n.isInvite
              ? (who.isEmpty ? l.notifyFullInvite : l.notifyFullInviteBy(who))
              : count > 1
                  ? l.notifyFullMore(line, count - 1)
                  : line,
          channelName: channelName,
          channelDescription: channelDescription,
        );
    }
  }

  /// The person read the conversation (or opened it): its notification goes.
  Future<void> cleared(String conversationId) async {
    _unseen.remove(conversationId);
    _shownFor.remove(conversationId);
    await sink.cancelConversation(conversationId);
  }

  /// Messages were removed (deleted here, deleted at their author's request, or
  /// expired). A notification that was about one of them goes too: it may have
  /// quoted what is now deleted.
  Future<void> removed(List<ChatMessage> messages) async {
    for (final m in messages) {
      if (_shownFor[m.conversationId] == m.id) await cleared(m.conversationId);
    }
  }

  /// Everything was seen (the app came to the screen with nothing unread).
  Future<void> clearedAll() async {
    _unseen.clear();
    _shownFor.clear();
    await sink.cancelAll();
  }
}
