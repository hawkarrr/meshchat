import 'dart:async';
import 'dart:typed_data';

import '../core/app_log.dart';
import '../core/bytes.dart';
import '../mesh/mesh_router.dart';
import 'encryption_service.dart';

/// Gathers receipts for a short moment and sends them together, so an image
/// that arrives as dozens of packets is confirmed with a handful of receipts
/// instead of dozens.
class AckBatcher {
  AckBatcher({
    required this.crypto,
    required this.router,
    this.delay = const Duration(milliseconds: 250),
    AppLog? log,
  }) : _log = log ?? AppLog.instance;

  final EncryptionService crypto;
  final MeshRouter router;

  /// How long the first receipt of a batch waits for company.
  final Duration delay;
  final AppLog _log;

  static const String _tag = 'Acks';

  final Map<String, _Batch> _batches = <String, _Batch>{};
  final Set<Future<void>> _inFlight = <Future<void>>{};
  bool _closed = false;

  /// True while receipts are waiting to be sent or being sent.
  bool get hasPending => _batches.isNotEmpty || _inFlight.isNotEmpty;

  /// Confirms [messageId], which [author] sent us.
  void add(Uint8List author, Uint8List messageId) {
    if (_closed) return;
    final key = bytesToHex(author);
    final batch = _batches.putIfAbsent(key, () => _Batch(author));
    final idHex = bytesToHex(messageId);
    if (!batch.seen.add(idHex)) return;
    batch.ids.add(messageId);
    if (batch.ids.length >= AckContent.maxIds) {
      _flush(key);
    } else {
      batch.timer ??= Timer(delay, () => _flush(key));
    }
  }

  void _flush(String key) {
    final batch = _batches.remove(key);
    if (batch == null) return;
    batch.timer?.cancel();
    late final Future<void> task;
    task = _send(batch).whenComplete(() => _inFlight.remove(task));
    _inFlight.add(task);
  }

  Future<void> _send(_Batch batch) async {
    try {
      final ack = await crypto.buildAck(
        recipientSigningKey: batch.author,
        ackedMessageIds: batch.ids,
      );
      await router.submit(ack);
    } catch (e) {
      _log.w(_tag, 'could not send a receipt: $e');
    }
  }

  /// Sends everything that is waiting, now.
  Future<void> flushAll() async {
    for (final key in _batches.keys.toList()) {
      _flush(key);
    }
    await Future.wait(_inFlight.toList());
  }

  Future<void> dispose() async {
    _closed = true;
    for (final b in _batches.values) {
      b.timer?.cancel();
    }
    _batches.clear();
    await Future.wait(_inFlight.toList());
  }
}

class _Batch {
  _Batch(this.author);

  final Uint8List author;
  final List<Uint8List> ids = <Uint8List>[];
  final Set<String> seen = <String>{};
  Timer? timer;
}
