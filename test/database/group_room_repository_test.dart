import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/database/data_changes.dart';
import 'package:offline_mesh_chat/database/database_helper.dart';
import 'package:offline_mesh_chat/database/group_repository.dart';
import 'package:offline_mesh_chat/database/room_repository.dart';
import 'package:offline_mesh_chat/models/group.dart';
import 'package:offline_mesh_chat/protocol/protocol_constants.dart';
import 'package:offline_mesh_chat/protocol/room_record.dart';

import '../support/test_database.dart';

Uint8List _k(int v) => Uint8List(32)..fillRange(0, 32, v);

RoomRecord _record(
  int roomSeed, {
  int creatorSeed = 2,
  String name = 'Cafe',
  int version = 1,
  int expires = 10000000,
}) =>
    RoomRecord(
      roomId: _k(roomSeed),
      name: name,
      description: 'desc',
      creatorKey: _k(creatorSeed),
      createdAtMs: 1000,
      expiresAtMs: expires,
      version: version,
      signature: Uint8List(Protocol.signatureLength),
    );

void main() {
  late DatabaseHelper helper;
  late ChangeBus bus;

  setUp(() async {
    helper = await openMemoryDatabase();
    bus = ChangeBus();
  });

  tearDown(() async {
    await bus.dispose();
    await helper.close();
  });

  group('GroupRepository', () {
    late GroupRepository groups;

    setUp(() => groups = GroupRepository(helper.db, bus: bus));

    GroupChat group(
      String id, {
      GroupState state = GroupState.active,
      int created = 1,
      List<GroupMember>? members,
      int epoch = 0,
    }) =>
        GroupChat(
          id: id,
          name: 'Group $id',
          adminId: 'admin',
          epoch: epoch,
          state: state,
          invitedBy: state == GroupState.invited ? 'admin' : null,
          createdAtMs: created,
          members: members ??
              const [
                GroupMember(id: 'admin', nickname: 'Admin'),
                GroupMember(id: 'sara', nickname: 'Sara'),
              ],
        );

    test('saves a group with its members, in order', () async {
      await groups.save(group('g1'));
      final g = (await groups.getGroup('g1'))!;
      expect(g.name, 'Group g1');
      expect(g.adminId, 'admin');
      expect(g.members.map((m) => m.id), ['admin', 'sara']);
      expect(g.members.map((m) => m.nickname), ['Admin', 'Sara']);
      expect(g.hasMember('sara'), isTrue);
      expect(g.hasMember('mallory'), isFalse);
      expect(g.nicknameOf('sara'), 'Sara');
      expect(g.isAdmin('admin'), isTrue);
    });

    test('saving again replaces the member list and bumps the epoch', () async {
      await groups.save(group('g1'));
      await groups.save(group('g1', epoch: 1, members: const [GroupMember(id: 'admin', nickname: 'A')]));
      final g = (await groups.getGroup('g1'))!;
      expect(g.epoch, 1);
      expect(g.members.map((m) => m.id), ['admin']);
    });

    test('states: invited, active, left, removed', () async {
      await groups.save(group('inv', state: GroupState.invited));
      expect((await groups.getGroup('inv'))!.invitedBy, 'admin');
      await groups.setState('inv', GroupState.active, joinedAtMs: 55);
      final g = (await groups.getGroup('inv'))!;
      expect(g.state, GroupState.active);
      expect(g.joinedAtMs, 55);
      expect(g.isActive, isTrue);
      await groups.setState('inv', GroupState.left);
      expect(await groups.stateOf('inv'), GroupState.left);
      expect(await groups.stateOf('missing'), isNull);
    });

    test('lists newest first and can filter by state', () async {
      await groups.save(group('old', created: 1));
      await groups.save(group('new', created: 9));
      await groups.save(group('pending', created: 5, state: GroupState.invited));
      expect((await groups.listGroups()).map((g) => g.id), ['new', 'pending', 'old']);
      expect((await groups.listGroups(states: [GroupState.invited])).map((g) => g.id), ['pending']);
      expect(
        (await groups.listGroups(states: [GroupState.active, GroupState.invited])).map((g) => g.id),
        ['new', 'pending', 'old'],
      );
    });

    test('deleting a group removes its members', () async {
      await groups.save(group('g1'));
      await groups.delete('g1');
      expect(await groups.getGroup('g1'), isNull);
      final rows = await helper.db.query('group_members');
      expect(rows, isEmpty);
    });

    test('unknown state names are treated as removed (fail closed)', () {
      expect(GroupState.parse('???'), GroupState.removed);
    });

    test('changes are announced', () async {
      final seen = <DataChange>[];
      final sub = bus.stream.listen(seen.add);
      await groups.save(group('g1'));
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(seen, contains(DataChange.groups));
    });
  });

  group('RoomRepository', () {
    late RoomRepository rooms;

    setUp(() => rooms = RoomRepository(helper.db, bus: bus, maxDiscovered: 5, maxDiscoveredPerCreator: 3));

    test('the built-in #mesh room exists once, is joined and never expires', () async {
      await rooms.ensureBuiltin(100);
      await rooms.ensureBuiltin(200);
      final all = await rooms.listRooms();
      expect(all.length, 1);
      final mesh = all.single;
      expect(mesh.id, PublicRooms.meshIdHex);
      expect(mesh.name, 'mesh');
      expect(mesh.label, '#mesh');
      expect(mesh.builtin, isTrue);
      expect(mesh.joined, isTrue);
      expect(mesh.isExpiredAt(1 << 52), isFalse);
      expect(mesh.discoveredAtMs, 100, reason: 'a second call changes nothing');
    });

    test('the built-in room cannot be left, replaced or deleted', () async {
      await rooms.ensureBuiltin(1);
      await rooms.setJoined(PublicRooms.meshIdHex, false);
      expect((await rooms.getRoom(PublicRooms.meshIdHex))!.joined, isTrue);
      await rooms.delete(PublicRooms.meshIdHex);
      expect(await rooms.getRoom(PublicRooms.meshIdHex), isNotNull);
      final impostor = RoomRecord(
        roomId: PublicRooms.meshId,
        name: 'hacked',
        description: '',
        creatorKey: _k(2),
        createdAtMs: 1,
        expiresAtMs: 99999,
        version: 50,
        signature: Uint8List(64),
      );
      expect(await rooms.upsertRecord(impostor, nowMs: 5), RoomUpsertOutcome.unchanged);
      expect((await rooms.getRoom(PublicRooms.meshIdHex))!.name, 'mesh');
    });

    test('a heard room is added, not joined, and keeps its signed record', () async {
      final r = _record(5);
      expect(await rooms.upsertRecord(r, nowMs: 2000), RoomUpsertOutcome.added);
      final room = (await rooms.getRoom(r.roomIdHex))!;
      expect(room.name, 'Cafe');
      expect(room.description, 'desc');
      expect(room.joined, isFalse);
      expect(room.builtin, isFalse);
      expect(room.creatorId, r.creatorId);
      expect(room.version, 1);
      expect(room.discoveredAtMs, 2000);
      expect(room.record, r.encode());
      expect(room.isMine(r.creatorId), isTrue);
    });

    test('only a higher version replaces a known room', () async {
      final v1 = _record(5);
      await rooms.upsertRecord(v1, nowMs: 100);
      expect(await rooms.upsertRecord(_record(5, version: 1, name: 'Same'), nowMs: 200),
          RoomUpsertOutcome.unchanged);
      expect((await rooms.getRoom(v1.roomIdHex))!.name, 'Cafe');
      expect((await rooms.getRoom(v1.roomIdHex))!.lastHeardAtMs, 200,
          reason: 'hearing it again still counts');
      expect(await rooms.upsertRecord(_record(5, version: 3, name: 'Cafe 2', expires: 20000000), nowMs: 300),
          RoomUpsertOutcome.updated);
      final room = (await rooms.getRoom(v1.roomIdHex))!;
      expect(room.name, 'Cafe 2');
      expect(room.version, 3);
      expect(room.expiresAtMs, 20000000);
      expect(await rooms.upsertRecord(_record(5, version: 2, name: 'Stale'), nowMs: 400),
          RoomUpsertOutcome.unchanged);
      expect((await rooms.getRoom(v1.roomIdHex))!.name, 'Cafe 2');
    });

    test('a different creator cannot take over a known room id', () async {
      await rooms.upsertRecord(_record(5), nowMs: 1);
      final takeover = _record(5, creatorSeed: 9, name: 'Mine now', version: 99);
      expect(await rooms.upsertRecord(takeover, nowMs: 2), RoomUpsertOutcome.unchanged);
      final room = (await rooms.getRoom(_record(5).roomIdHex))!;
      expect(room.name, 'Cafe');
      expect(room.creatorId, _record(5).creatorId);
    });

    test('joining keeps a room through updates; leaving makes it discoverable again', () async {
      final r = _record(5);
      await rooms.upsertRecord(r, nowMs: 1);
      await rooms.setJoined(r.roomIdHex, true);
      expect(await rooms.isJoined(r.roomIdHex), isTrue);
      await rooms.upsertRecord(_record(5, version: 2), nowMs: 2);
      expect((await rooms.getRoom(r.roomIdHex))!.joined, isTrue);
      expect((await rooms.joinedRooms()).map((x) => x.id), [r.roomIdHex]);
      await rooms.setJoined(r.roomIdHex, false);
      expect(await rooms.isJoined(r.roomIdHex), isFalse);
    });

    test('creating a room joins it straight away', () async {
      final r = _record(6);
      await rooms.upsertRecord(r, nowMs: 1, join: true);
      expect(await rooms.isJoined(r.roomIdHex), isTrue);
    });

    test('lists built-in first, then joined, then most recently heard', () async {
      await rooms.ensureBuiltin(1);
      await rooms.upsertRecord(_record(5, name: 'a'), nowMs: 100);
      await rooms.upsertRecord(_record(6, name: 'b'), nowMs: 300);
      await rooms.upsertRecord(_record(7, name: 'c'), nowMs: 200, join: true);
      expect((await rooms.listRooms()).map((r) => r.name), ['mesh', 'c', 'b', 'a']);
    });

    test('expired rooms we only heard about are forgotten; joined ones stay', () async {
      await rooms.upsertRecord(_record(5, name: 'gone', expires: 5000), nowMs: 1);
      await rooms.upsertRecord(_record(6, name: 'kept', expires: 5000), nowMs: 1, join: true);
      await rooms.upsertRecord(_record(7, name: 'live', expires: 90000), nowMs: 1);
      expect(await rooms.purgeExpired(6000), 1);
      expect((await rooms.listRooms()).map((r) => r.name).toSet(), {'kept', 'live'});
      expect((await rooms.getRoom(_record(6).roomIdHex))!.isExpiredAt(6000), isTrue);
    });

    test('announceable rooms are unexpired, have a record, and exclude the built-in', () async {
      await rooms.ensureBuiltin(1);
      await rooms.upsertRecord(_record(5, name: 'live', expires: 90000), nowMs: 10);
      await rooms.upsertRecord(_record(6, name: 'dead', expires: 100), nowMs: 10);
      await rooms.upsertRecord(_record(7, name: 'mine', expires: 90000), nowMs: 5, join: true);
      expect((await rooms.announceable(1000)).map((r) => r.name), ['mine', 'live']);
    });

    test('rooms we only heard about are capped per creator and overall', () async {
      for (var i = 0; i < 6; i++) {
        await rooms.upsertRecord(_record(20 + i, name: 'r$i'), nowMs: 100 + i);
      }
      // 3 per creator: only the three most recently heard survive.
      expect((await rooms.listRooms()).map((r) => r.name), ['r5', 'r4', 'r3']);

      for (var c = 0; c < 4; c++) {
        for (var i = 0; i < 2; i++) {
          await rooms.upsertRecord(_record(60 + c * 2 + i, creatorSeed: 30 + c, name: 'c$c$i'),
              nowMs: 1000 + c * 10 + i);
        }
      }
      final left = await rooms.listRooms();
      expect(left.length, lessThanOrEqualTo(5));
      expect(left.first.name, 'c31', reason: 'the most recently heard is kept');
    });

    test('joined rooms are never evicted by the caps', () async {
      for (var i = 0; i < 4; i++) {
        await rooms.upsertRecord(_record(40 + i, name: 'j$i'), nowMs: i, join: true);
      }
      for (var i = 0; i < 5; i++) {
        await rooms.upsertRecord(_record(50 + i, creatorSeed: 10 + i, name: 'x$i'), nowMs: 100 + i);
      }
      final joined = await rooms.joinedRooms();
      expect(joined.length, 4);
    });

    test('a room can be forgotten', () async {
      final r = _record(5);
      await rooms.upsertRecord(r, nowMs: 1);
      await rooms.delete(r.roomIdHex);
      expect(await rooms.getRoom(r.roomIdHex), isNull);
    });
  });
}
