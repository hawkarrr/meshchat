import 'dart:async';

import 'package:flutter/foundation.dart';

import '../app_controller.dart';
import '../database/message_repository.dart';
import '../models/media.dart';
import '../models/message.dart';

/// What a conversation screen shows: its messages (oldest first) and the
/// picture / voice files they carry.
@immutable
class FeedState {
  const FeedState({
    this.messages = const <ChatMessage>[],
    this.media = const <String, MediaItem>{},
    this.referenced = const <String, ChatMessage>{},
    this.pinned = const <ChatMessage>[],
    this.deletions = const <String, int>{},
    this.loaded = false,
    this.failed = false,
  });

  final List<ChatMessage> messages;

  /// Keyed by media id.
  final Map<String, MediaItem> media;

  /// Messages of this conversation that replies point at but that are older than
  /// the ones shown, keyed by message id. A reply can only ever quote a message
  /// of its own conversation: whatever else its id names is ignored.
  final Map<String, ChatMessage> referenced;

  /// The messages this person pinned, the most recently pinned first.
  final List<ChatMessage> pinned;

  /// Our own "delete for everyone" requests here, by state.
  final Map<String, int> deletions;
  final bool loaded;

  /// The messages could not be read from the database, and nothing was shown yet.
  /// [ConversationFeed.reload] tries again.
  final bool failed;

  /// Finds a message by id among those shown and those only quoted.
  ChatMessage? byId(String id) {
    for (final m in messages) {
      if (m.id == id) return m;
    }
    return referenced[id];
  }

  Set<String> get pinnedIds => {for (final m in pinned) m.id};
}

/// Keeps a [FeedState] up to date for one conversation.
///
/// It reloads messages when messages change, and only the (small) media table
/// when a file's progress changes, and it publishes a new state only when
/// something the screen shows is different - so a screen listening to it
/// rebuilds only for real changes.
class ConversationFeed {
  /// [isActive] says whether the person is looking at this conversation right now.
  /// A conversation that is only kept ready (the public room behind the other tabs)
  /// does not mark its messages as read, or take back their notification, until it
  /// is on screen; [markRead] is for the moment it comes to the front.
  ConversationFeed(this.controller, this.conversationId, {this.isActive});

  final AppController controller;
  final String conversationId;
  final bool Function()? isActive;
  final ValueNotifier<FeedState> state = ValueNotifier<FeedState>(const FeedState());

  StreamSubscription<DataChange>? _sub;
  Timer? _messagesTimer;
  Timer? _mediaTimer;
  bool _disposed = false;
  String _signature = '';

  void start() {
    _sub = controller.dataChanges.listen((change) {
      switch (change) {
        case DataChange.messages:
        case DataChange.conversations:
          _messagesTimer?.cancel();
          _messagesTimer = Timer(const Duration(milliseconds: 40), reload);
        case DataChange.media:
          _mediaTimer ??= Timer(const Duration(milliseconds: 150), () {
            _mediaTimer = null;
            unawaited(_reloadMedia());
          });
        case DataChange.peers:
        case DataChange.groups:
        case DataChange.rooms:
        case DataChange.securityEvents:
          break;
      }
    });
    unawaited(reload());
  }

  static String _sign(FeedState s) {
    final b = StringBuffer();
    for (final m in s.messages) {
      b.write('${m.id}|${m.status.name}|${m.receiptCount}|${m.hops}|${m.editVersion};');
    }
    for (final i in s.media.values) {
      b.write('${i.id}|${i.state.name}|${i.receivedChunks};');
    }
    b.write('R');
    for (final m in s.referenced.values) {
      b.write('${m.id}|${m.editVersion};');
    }
    b.write('P');
    for (final m in s.pinned) {
      b.write('${m.id}|${m.editVersion};');
    }
    b.write('D');
    for (final e in s.deletions.entries) {
      b.write('${e.key}=${e.value};');
    }
    return b.toString();
  }

  Future<void> reload() async {
    if (_disposed) return;
    final FeedState next;
    try {
      final messages = await controller.loadMessages(conversationId);
      final media = await controller.loadMedia(
        [for (final m in messages) if (m.mediaId != null) m.mediaId!],
      );
      final shown = {for (final m in messages) m.id};
      final missing = {
        for (final m in messages)
          if (m.replyToId != null && !shown.contains(m.replyToId)) m.replyToId!,
      };
      final referenced = <String, ChatMessage>{
        if (missing.isNotEmpty)
          for (final m in await controller.messagesByIds(missing))
            if (m.conversationId == conversationId) m.id: m,
      };
      final pinned = await controller.pinnedMessages(conversationId);
      final deletions = await controller.deletionRequests(conversationId);
      if (_disposed) return;
      next = FeedState(
        messages: messages,
        media: media,
        referenced: referenced,
        pinned: pinned,
        deletions: deletions,
        loaded: true,
      );
    } catch (e) {
      if (_disposed) return;
      controller.log.w('Feed', 'could not read $conversationId: $e');
      // What is on screen stays; only a screen with nothing yet shows the failure.
      if (!state.value.loaded) {
        _signature = '';
        state.value = const FeedState(failed: true);
      }
      return;
    }
    final signature = _sign(next);
    if (!state.value.loaded || signature != _signature) {
      _signature = signature;
      state.value = next;
    }
    if (isActive?.call() ?? true) markRead();
  }

  /// Marks the conversation as read and takes back its notification. Called after
  /// each load while the conversation is on screen, and when it comes back to it.
  void markRead() {
    if (_disposed) return;
    unawaited(controller.markRead(conversationId));
  }

  Future<void> _reloadMedia() async {
    if (_disposed) return;
    final messages = state.value.messages;
    final ids = [for (final m in messages) if (m.mediaId != null) m.mediaId!];
    if (ids.isEmpty) return;
    final media = await controller.loadMedia(ids);
    if (_disposed) return;
    final current = state.value;
    final next = FeedState(
      messages: messages,
      media: media,
      referenced: current.referenced,
      pinned: current.pinned,
      deletions: current.deletions,
      loaded: true,
    );
    final signature = _sign(next);
    if (signature != _signature) {
      _signature = signature;
      state.value = next;
    }
  }

  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _messagesTimer?.cancel();
    _mediaTimer?.cancel();
    state.dispose();
  }
}
