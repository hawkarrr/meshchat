import '../database/message_repository.dart';
import '../models/message.dart';
import 'media_service.dart';
import 'service_context.dart';

/// What one cleanup removed.
class CleanupResult {
  const CleanupResult({required this.messages, required this.files});

  final int messages;
  final int files;

  static const CleanupResult nothing = CleanupResult(messages: 0, files: 0);
}

/// Removes the messages of public rooms whose time is up.
///
/// The policy, in full:
///
///  * Every message of a public room lives [MessageRepository.publicRetention]
///    (six hours) from the moment this phone sent or received it, counted on this
///    phone's own clock. Another phone's clock, right or wrong, changes nothing.
///  * Only public-room messages have an expiry. Private chats, groups, contacts
///    and identities are not touched by this code at all: it can only select rows
///    that carry an expiry.
///  * The cleanup runs when the app starts, when it comes back to the screen, and
///    on every maintenance round while it runs (about once a minute), so a phone
///    that was switched off for a day removes everything overdue at once, and
///    never shows an expired message after the first screen.
///  * It is safe to run any number of times: running it again finds nothing more.
///  * What goes: the messages, their pins, their picture and voice records and
///    files (a file is kept only if some message still refers to it), half-received
///    pieces, and the replies that quoted them stop showing a quote because the
///    quote is looked up from a message that no longer exists.
///  * A message of a public room that is still waiting to be sent is given up by
///    the sending queue after two hours (see [Protocol.roomMessageTtl]) and marked
///    as not delivered; it is removed here with the rest at six hours.
///  * An incomplete picture is given up after twelve hours at the latest, or when
///    its message is removed, whichever comes first.
///  * Expired ids are remembered (without any content) for 48 hours, longer than a
///    packet can live, so a late copy arriving during synchronisation is refused
///    instead of reappearing.
class PublicChatCleanup {
  PublicChatCleanup(this._ctx, this._media);

  final ServiceContext _ctx;
  final MediaService _media;

  bool _running = false;

  /// Told which messages were removed, so a notification that quotes one can be
  /// taken back.
  void Function(List<ChatMessage> removed)? onRemoved;

  Future<CleanupResult> run() async {
    if (_running) return CleanupResult.nothing;
    _running = true;
    try {
      final now = _ctx.clock.nowMs;
      final filesBefore = (await _media.store.list()).length;
      final removed = await _ctx.repo.removeExpiredPublic(now);
      if (removed.isNotEmpty) onRemoved?.call(removed);
      await _media.forget(removed);
      await _media.sweepFiles();
      await _ctx.repo.purgeStaleRecords(now);
      final files = filesBefore - (await _media.store.list()).length;
      if (removed.isNotEmpty) {
        await _ctx.repo.recordPublicCleanup(now, removed: removed.length, files: files);
      }
      return CleanupResult(messages: removed.length, files: files < 0 ? 0 : files);
    } finally {
      _running = false;
    }
  }
}
