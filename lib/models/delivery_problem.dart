import '../l10n/l10n.dart';

/// Why an outgoing message or file did not arrive.
///
/// The reason is stored as a short code, not as words, so that it is told in
/// whatever language the app is in when someone looks at it (and not in the
/// language it happened to be in when it went wrong).
enum DeliveryProblem {
  /// The router would not take the message.
  queueFailed('queue_failed'),

  /// A private message ran out of time before its recipient could be reached.
  expired('expired'),

  /// A group or room message that nobody in range took.
  nobodyInRange('nobody_in_range'),

  /// A file arrived but its checksum did not match.
  fileDamaged('file_damaged'),

  /// A file that never completed.
  fileIncomplete('file_incomplete');

  const DeliveryProblem(this.code);

  /// What is stored.
  final String code;

  static DeliveryProblem? parse(String? code) {
    for (final p in values) {
      if (p.code == code) return p;
    }
    return null;
  }

  String text(AppLocalizations l) => switch (this) {
        queueFailed => l.problemQueueFailed,
        expired => l.problemExpired,
        nobodyInRange => l.problemNobodyInRange,
        fileDamaged => l.problemFileDamaged,
        fileIncomplete => l.problemFileIncomplete,
      };

  /// The words for a stored reason. A reason that is not one of the codes (one
  /// written by an older version, in English) is shown as it is.
  static String? describe(AppLocalizations l, String? stored) {
    if (stored == null) return null;
    return parse(stored)?.text(l) ?? stored;
  }
}
