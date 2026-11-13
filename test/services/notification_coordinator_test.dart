import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/core/app_info.dart';
import 'package:offline_mesh_chat/device/permission_service.dart';
import 'package:offline_mesh_chat/models/conversation.dart';
import 'package:offline_mesh_chat/models/message.dart';
import 'package:offline_mesh_chat/services/message_errors.dart';
import 'package:offline_mesh_chat/services/notification_coordinator.dart';

import '../support/fake_device.dart';

/// When a message becomes a notification, and exactly what the notification
/// gives away.
void main() {
  late FakeNotificationSink sink;
  late FakePermissionService permissions;
  late NotificationPolicy policy;
  late bool foreground;
  late NotificationCoordinator coordinator;

  setUp(() {
    sink = FakeNotificationSink();
    permissions = FakePermissionService(
      initial: {AppPermission.notifications: PermissionOutcome.granted},
    );
    policy = const NotificationPolicy();
    foreground = false;
    coordinator = NotificationCoordinator(
      sink: sink,
      permissions: permissions,
      policy: () => policy,
      isForeground: () => foreground,
    );
  });

  IncomingNotice direct({String id = 'm1', String text = 'see you at ten', String from = 'Bob'}) =>
      IncomingNotice(
        conversationId: 'dm:bob',
        title: from,
        type: ConversationType.direct,
        messageId: id,
        preview: text,
        sender: from,
      );

  IncomingNotice groupMessage({String id = 'g1', String text = 'pizza?'}) => IncomingNotice(
        conversationId: 'gr:trip',
        title: 'Trip',
        type: ConversationType.group,
        messageId: id,
        preview: text,
        sender: 'Carol',
      );

  IncomingNotice room({String id = 'r1'}) => IncomingNotice(
        conversationId: 'rm:mesh',
        title: '#mesh',
        type: ConversationType.room,
        messageId: id,
        preview: 'anyone near?',
        sender: 'Zed',
      );

  group('whether', () {
    test('a message that arrives while the app is closed is notified', () async {
      expect(await coordinator.onNotice(direct()), isTrue);
      expect(sink.shown, hasLength(1));
      expect(sink.shown.single.conversationId, 'dm:bob');
    });

    test('nothing while the app is on screen: the badges do that job', () async {
      foreground = true;
      expect(await coordinator.onNotice(direct()), isFalse);
      expect(sink.shown, isEmpty);
    });

    test('nothing when the person turned notifications off', () async {
      policy = const NotificationPolicy(enabled: false);
      expect(await coordinator.onNotice(direct()), isFalse);
      expect(sink.shown, isEmpty);
    });

    test('nothing without the system permission, and no prompt is made here', () async {
      permissions.set(AppPermission.notifications, PermissionOutcome.denied);
      expect(await coordinator.onNotice(direct()), isFalse);
      expect(sink.shown, isEmpty);
      expect(permissions.requested, isEmpty, reason: 'only the settings ask, in their own words');
    });

    test('public rooms are silent unless asked for', () async {
      expect(await coordinator.onNotice(room()), isFalse);
      policy = const NotificationPolicy(publicRooms: true);
      expect(await coordinator.onNotice(room(id: 'r2')), isTrue);
    });

    test('a message that could not be read never reaches the lock screen', () async {
      const failure = IncomingNotice(
        conversationId: 'dm:bob',
        title: 'Bob',
        type: ConversationType.direct,
        kind: NoticeKind.failure,
        messageId: 'bad',
      );
      expect(await coordinator.onNotice(failure), isFalse);
      expect(sink.shown, isEmpty);
    });

    test('the same message is only announced once, however often it is heard', () async {
      expect(await coordinator.onNotice(direct(id: 'same')), isTrue);
      expect(await coordinator.onNotice(direct(id: 'same')), isFalse);
      expect(sink.shown, hasLength(1));
    });

    test('a group invitation is notified, too', () async {
      const invite = IncomingNotice(
        conversationId: 'gr:trip',
        title: 'Trip',
        type: ConversationType.group,
        kind: NoticeKind.groupInvite,
        sender: 'Carol',
      );
      expect(await coordinator.onNotice(invite), isTrue);
      expect(sink.shown.single.body, 'Invited you to a group');
    });
  });

  group('what it says', () {
    test('name and message: the text, with the author in a group', () async {
      policy = const NotificationPolicy(privacy: NotificationPrivacy.full);
      await coordinator.onNotice(direct());
      await coordinator.onNotice(groupMessage());
      expect([sink.shown[0].title, sink.shown[0].body], ['Bob', 'see you at ten']);
      expect([sink.shown[1].title, sink.shown[1].body], ['Trip', 'Carol: pizza?']);
    });

    test('name only: who, but never what', () async {
      await coordinator.onNotice(direct());
      expect([sink.shown.single.title, sink.shown.single.body], ['Bob', 'New message']);
      expect(sink.shown.single.body, isNot(contains('ten')));
    });

    test('nothing: not even who', () async {
      policy = const NotificationPolicy(privacy: NotificationPrivacy.hidden);
      await coordinator.onNotice(direct());
      final n = sink.shown.single;
      expect([n.title, n.body], [AppInfo.name, 'You have a new message']);
      expect('${n.title} ${n.body}', isNot(contains('Bob')));
      expect('${n.title} ${n.body}', isNot(contains('ten')));
    });

    test('the default is "name only", never the text', () {
      expect(const NotificationPolicy().privacy, NotificationPrivacy.sender);
      expect(NotificationPrivacy.parse(null), NotificationPrivacy.sender);
      expect(NotificationPrivacy.parse('nonsense'), NotificationPrivacy.sender);
      expect(NotificationPrivacy.parse('hidden'), NotificationPrivacy.hidden);
    });

    test('several messages of one chat update the same notification with a count', () async {
      await coordinator.onNotice(direct(id: 'a'));
      await coordinator.onNotice(direct(id: 'b'));
      await coordinator.onNotice(direct(id: 'c'));
      expect(sink.shown.map((n) => n.conversationId).toSet(), {'dm:bob'},
          reason: 'one conversation, one notification slot');
      expect(sink.shown.last.body, '3 new messages');

      policy = const NotificationPolicy(privacy: NotificationPrivacy.full);
      await coordinator.onNotice(direct(id: 'd', text: 'latest words'));
      expect(sink.shown.last.body, 'latest words  (+3 more)');
    });
  });

  group('when the message is taken back', () {
    ChatMessage gone(String id, {String conv = 'dm:bob'}) => ChatMessage(
          id: id,
          conversationId: conv,
          senderId: 'bob',
          isOutgoing: false,
          body: 'x',
          sortTimeMs: 1,
          claimedTimestampMs: 1,
          status: MessageStatus.received,
        );

    test('a notification about a message that is then deleted goes with it', () async {
      await coordinator.onNotice(direct(id: 'm1', text: 'secret plans'));
      await coordinator.removed([gone('m1')]);
      expect(sink.cancelled, ['dm:bob']);
    });

    test('a notification about another message stays', () async {
      await coordinator.onNotice(direct(id: 'new'));
      await coordinator.removed([gone('old')]);
      expect(sink.cancelled, isEmpty);
      await coordinator.removed([gone('new', conv: 'dm:someone-else')]);
      expect(sink.cancelled, isEmpty, reason: 'same id, other conversation: not this notification');
    });

    test('nothing to take back is not an error', () async {
      await coordinator.removed([gone('never-notified')]);
      expect(sink.cancelled, isEmpty);
    });
  });

  group('clearing', () {
    test('reading a chat removes its notification and restarts its count', () async {
      await coordinator.onNotice(direct(id: 'a'));
      await coordinator.onNotice(direct(id: 'b'));
      await coordinator.cleared('dm:bob');
      expect(sink.cancelled, ['dm:bob']);
      await coordinator.onNotice(direct(id: 'c'));
      expect(sink.shown.last.body, 'New message', reason: 'the count started again');
    });

    test('everything can be cleared at once', () async {
      await coordinator.onNotice(direct());
      await coordinator.clearedAll();
      expect(sink.cancelledAll, 1);
    });
  });
}
