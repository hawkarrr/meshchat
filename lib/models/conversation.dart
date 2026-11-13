import '../l10n/l10n.dart';
import 'message_preview.dart';

enum ConversationType { direct, group, room }

class Conversation {
  const Conversation({
    required this.id,
    required this.type,
    required this.title,
    this.peerId,
    this.groupId,
    this.roomId,
    required this.createdAtMs,
    this.lastMessageAtMs,
    this.lastMessagePreview,
    this.unreadCount = 0,
  });

  /// `dm:<peer id>`, `gr:<group id>` or `rm:<room id>` (all hex).
  final String id;
  final ConversationType type;
  final String title;
  final String? peerId;
  final String? groupId;
  final String? roomId;
  final int createdAtMs;
  final int? lastMessageAtMs;
  final String? lastMessagePreview;
  final int unreadCount;

  /// The last message as one line in the language of [l], or null if there is none.
  String? previewIn(AppLocalizations l) => MessagePreview.show(lastMessagePreview, l);

  static String directId(String peerId) => 'dm:$peerId';

  static String groupConversationId(String groupId) => 'gr:$groupId';

  static String roomConversationId(String roomId) => 'rm:$roomId';

  bool get isDirect => type == ConversationType.direct;

  bool get isGroup => type == ConversationType.group;

  bool get isRoom => type == ConversationType.room;

  /// Group and room messages show who wrote them; a one-to-one chat does not.
  bool get showsSenderNames => type != ConversationType.direct;
}
