import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/models/message.dart';
import 'package:offline_mesh_chat/services/encryption_service.dart';

import '../support/fake_clock.dart';
import '../support/memory_network.dart';
import '../support/message_node.dart';
import '../support/test_node.dart';

const _mesh = PublicRooms.meshIdHex;

/// "Help relay messages for others": with it off a phone still receives what is
/// for it and sends its own, and carries nothing for anybody else.
void main() {
  late MemoryNetwork net;
  late FakeClock clock;
  final nodes = <MessageNode>[];

  setUp(() {
    net = MemoryNetwork();
    clock = FakeClock(1700000000000);
    nodes.clear();
  });

  tearDown(() async {
    for (final n in nodes) {
      await n.close();
    }
  });

  Future<MessageNode> mk(String name, int seed) async {
    final n = await MessageNode.create(name, net, clock, seed: seed);
    nodes.add(n);
    return n;
  }

  Future<void> run() => settle(net, nodes.map((n) => n.node),
      extraBusy: () => nodes.any((n) => n.service.hasPendingWork));

  /// Alice - Relay - Carol in a line; Alice and Carol know each other's keys.
  Future<(MessageNode, MessageNode, MessageNode)> line() async {
    final a = await mk('Alice', 1);
    final b = await mk('Relay', 2);
    final c = await mk('Carol', 3);
    await net.connect(a.id, b.id);
    await net.connect(b.id, c.id);
    await run();
    await c.node.router.announceNow();
    await a.node.router.announceNow();
    await run();
    expect(await a.repo.getPeer(c.id), isNotNull, reason: 'the relay passed the announcement on');
    expect(await c.repo.getPeer(a.id), isNotNull);
    return (a, b, c);
  }

  test('it is on by default', () async {
    final a = await mk('Alice', 1);
    expect(a.node.router.relayForOthers, isTrue);
  });

  test('with relaying on, a message reaches the phone behind the relay', () async {
    final (a, _, c) = await line();
    await a.service.sendDirect(c.id, 'via the relay');
    await run();
    expect((await c.chatWith(a)).single.body, 'via the relay');
  });

  test('with relaying off, a private message to somebody behind the phone is not carried',
      () async {
    final (a, b, c) = await line();
    b.node.router.relayForOthers = false;

    final sent = await a.service.sendDirect(c.id, 'through a closed door');
    await run();

    expect(await c.chatWith(a), isEmpty);
    expect((await a.message(sent.id))!.status, isNot(MessageStatus.delivered));
    expect(b.node.router.stats.relayRefused, greaterThan(0));
    expect(await b.repo.listConversations().then((l) => l.where((x) => x.id.contains(c.id))), isEmpty,
        reason: 'and it kept nothing of it');
  });

  test('...but it still receives what is addressed to it, and sends its own', () async {
    final (a, b, c) = await line();
    b.node.router.relayForOthers = false;

    await a.service.sendDirect(b.id, 'for the relay itself');
    await b.service.sendDirect(c.id, 'from the relay');
    await run();

    expect((await b.chatWith(a)).single.body, 'for the relay itself');
    expect((await c.chatWith(b)).single.body, 'from the relay');
  });

  test('a public room post is read by the phone that does not relay, and goes no further',
      () async {
    final (a, b, c) = await line();
    b.node.router.relayForOthers = false;

    await a.service.rooms.sendText(_mesh, 'public words');
    await run();

    expect((await b.repo.getMessages('rm:$_mesh')).single.body, 'public words',
        reason: 'it still takes part in the room itself');
    expect(await c.repo.getMessages('rm:$_mesh'), isEmpty);
  });

  test('turning it back on lets the next message through', () async {
    final (a, b, c) = await line();
    b.node.router.relayForOthers = false;
    await a.service.sendDirect(c.id, 'one');
    await run();
    expect(await c.chatWith(a), isEmpty);

    b.node.router.relayForOthers = true;
    await a.service.sendDirect(c.id, 'two');
    await run();
    expect((await c.chatWith(a)).map((m) => m.body), contains('two'));
  });
}
