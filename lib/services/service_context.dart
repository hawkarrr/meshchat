import 'dart:async';

import '../core/app_log.dart';
import '../core/clock.dart';
import '../core/text.dart';
import '../database/group_repository.dart';
import '../database/media_repository.dart';
import '../database/message_repository.dart';
import '../database/room_repository.dart';
import '../l10n/l10n.dart';
import '../mesh/mesh_router.dart';
import 'ack_batcher.dart';
import 'encryption_service.dart';
import 'message_errors.dart';

/// What the message services share: identity, storage, the router, the clock
/// and the stream of incoming-message notices. Built once per identity.
class ServiceContext {
  ServiceContext({
    required this.crypto,
    required this.repo,
    required this.groupRepo,
    required this.roomRepo,
    required this.mediaRepo,
    required this.router,
    required this.nickname,
    this.clock = const SystemClock(),
    Duration ackBatchDelay = const Duration(milliseconds: 250),
    AppLocalizations Function()? strings,
    AppLog? log,
  })  : strings = strings ?? englishStrings,
        log = log ?? AppLog.instance {
    acks = AckBatcher(crypto: crypto, router: router, delay: ackBatchDelay, log: this.log);
  }

  final EncryptionService crypto;
  final MessageRepository repo;
  final GroupRepository groupRepo;
  final RoomRepository roomRepo;
  final MediaRepository mediaRepo;
  final MeshRouter router;

  /// Supplies the current display name for announcements and posts.
  final String Function() nickname;

  /// The app's text in the language being shown right now: what an error says is
  /// worded when it happens, in the language of the person who will read it.
  final AppLocalizations Function() strings;
  final Clock clock;
  final AppLog log;

  late final AckBatcher acks;

  final StreamController<IncomingNotice> _notices = StreamController<IncomingNotice>.broadcast();

  Stream<IncomingNotice> get notices => _notices.stream;

  void notify(IncomingNotice notice) {
    if (!_notices.isClosed) _notices.add(notice);
  }

  AppLocalizations get l10n => strings();

  String get ownId => crypto.identity.id;

  /// Our display name, cleaned the same way names from the network are.
  String get ownNickname => sanitizeDisplayName(nickname());

  Future<void> dispose() async {
    await acks.dispose();
    await _notices.close();
  }
}
