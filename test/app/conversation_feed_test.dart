import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/models/conversation.dart';
import 'package:offline_mesh_chat/protocol/room_record.dart';
import 'package:offline_mesh_chat/screens/conversation_feed.dart';

import '../support/app_harness.dart';
import '../support/fake_ble_world.dart';
import '../support/radio_harness.dart';

const String _mesh = 'rm:${PublicRooms.meshIdHex}';

/// What a conversation screen is shown while it reads its messages: nothing yet (a
/// skeleton), the messages, or - if the database cannot be read - a failure that
/// the person can retry. And when it counts a conversation as read.
void main() {
  late FakeBleWorld world;
  final nodes = <AppNode>[];

  setUp(() {
    world = FakeBleWorld();
    nodes.clear();
  });

  tearDown(() async {
    for (final n in nodes) {
      await n.dispose();
    }
  });

  Future<AppNode> phone(String name) async {
    final n = await AppNode.create(world, name);
    nodes.add(n);
    return n;
  }

  Future<void> loaded(ConversationFeed feed) => eventually(
        () => feed.state.value.loaded || feed.state.value.failed,
        timeout: const Duration(seconds: 5),
        reason: 'the feed should finish its first read',
      );

  test('starts empty and not loaded, then loads', () async {
    final a = await phone('Alice');
    final feed = ConversationFeed(a.controller, _mesh);
    expect(feed.state.value.loaded, isFalse, reason: 'the skeleton shows until the first read');
    expect(feed.state.value.failed, isFalse);
    feed.start();
    await loaded(feed);
    expect(feed.state.value.loaded, isTrue);
    expect(feed.state.value.failed, isFalse);
    expect(feed.state.value.messages, isEmpty);
    feed.dispose();
  });

  test('a database that cannot be read is a failure, not a crash and not a blank page', () async {
    final a = await phone('Alice');
    await a.db.close();
    final feed = ConversationFeed(a.controller, _mesh)..start();
    await loaded(feed);
    expect(feed.state.value.failed, isTrue);
    expect(feed.state.value.loaded, isFalse);

    // Trying again while it is still broken stays a failure, and does not throw.
    await feed.reload();
    expect(feed.state.value.failed, isTrue);
    feed.dispose();
  });

  test('what is already on screen stays when a later read fails', () async {
    final a = await phone('Alice');
    await a.controller.sendText(_mesh, 'still here');
    final feed = ConversationFeed(a.controller, _mesh)..start();
    await eventually(() => feed.state.value.messages.length == 1,
        timeout: const Duration(seconds: 5), reason: 'the message is read');
    await a.db.close();
    await feed.reload();
    expect(feed.state.value.loaded, isTrue);
    expect(feed.state.value.failed, isFalse, reason: 'a screen with messages keeps them');
    expect(feed.state.value.messages.single.body, 'still here');
    feed.dispose();
  });

  test('a conversation that is not on screen does not mark its messages as read', () async {
    final a = await phone('Alice');
    final b = await phone('Bob');
    await a.startUp();
    await b.startUp();
    await waitForDirect(a, b);
    var onScreen = false;
    final feed = ConversationFeed(a.controller, _mesh, isActive: () => onScreen)..start();
    await loaded(feed);

    await b.controller.sendText(_mesh, 'while you were away');
    await eventually(() => a.controller.totalUnread == 1,
        timeout: const Duration(seconds: 10), reason: 'counted as unread, not read');
    // The feed reloaded for the new message and left it unread.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(a.controller.totalUnread, 1);

    // Coming to the front reads it.
    onScreen = true;
    feed.markRead();
    await eventually(() => a.controller.totalUnread == 0,
        timeout: const Duration(seconds: 5), reason: 'read once it is on screen');

    // On screen, the next one is read as it arrives.
    await b.controller.sendText(_mesh, 'while you watch');
    await eventually(() => feed.state.value.messages.length == 2,
        timeout: const Duration(seconds: 10), reason: 'the second message arrives');
    await eventually(() => a.controller.totalUnread == 0, timeout: const Duration(seconds: 5));
    feed.dispose();
  });

  test('the conversation id helpers agree with the room id used here', () {
    expect(Conversation.roomConversationId(PublicRooms.meshIdHex), _mesh);
  });
}
