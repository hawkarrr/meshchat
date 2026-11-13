import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_scope.dart';
import '../core/format.dart';
import '../models/message.dart';
import '../theme/app_theme.dart';
import '../theme/surfaces.dart';
import '../widgets/composer_target.dart';
import '../widgets/empty_state.dart';
import '../widgets/ghost_mark.dart' show GhostMood;
import '../l10n/l10n.dart';

/// Searches one conversation: text and captions, optionally only pictures,
/// only voice messages, or only what you wrote. Pops with the id of the message
/// that was picked, so the chat can jump to it.
class MessageSearchScreen extends StatefulWidget {
  const MessageSearchScreen({
    super.key,
    required this.conversationId,
    required this.title,
    required this.authorOf,
  });

  final String conversationId;
  final String title;

  /// Who wrote a message, as this person knows them ("You", a name).
  final String Function(ChatMessage) authorOf;

  @override
  State<MessageSearchScreen> createState() => _MessageSearchScreenState();
}

class _MessageSearchScreenState extends State<MessageSearchScreen> {
  late final AppController _c;
  final TextEditingController _query = TextEditingController();
  bool _photos = false;
  bool _videos = false;
  bool _voice = false;
  bool _mine = false;
  List<ChatMessage> _results = const <ChatMessage>[];
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _c = AppScope.read(context);
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool get _hasCriteria => _query.text.trim().isNotEmpty || _photos || _videos || _voice || _mine;

  Future<void> _search() async {
    final seq = ++_seq;
    if (!_hasCriteria) {
      setState(() => _results = const <ChatMessage>[]);
      return;
    }
    final kinds = <MessageKind>{
      if (_photos) MessageKind.image,
      if (_videos) MessageKind.video,
      if (_voice) MessageKind.voice,
    };
    final found = await _c.searchMessages(
      widget.conversationId,
      query: _query.text,
      kinds: kinds.isEmpty ? null : kinds,
      senderId: _mine ? _c.identityId : null,
    );
    if (!mounted || seq != _seq) return;
    setState(() => _results = found);
  }

  void _toggle(void Function() change) {
    setState(change);
    _search();
  }

  Widget _chip(Key key, String label, IconData icon, bool on, VoidCallback onTap) {
    return FilterChip(
      key: key,
      selected: on,
      showCheckmark: false,
      avatar: Icon(icon, size: 16, color: on ? context.palette.onAccent : context.palette.textSecondary),
      label: Text(label),
      onSelected: (_) => onTap(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 12, 4),
              child: Row(
                children: [
                  RoundButton(
                    key: const Key('search-back'),
                    icon: Icons.arrow_back_rounded,
                    tooltip: context.l10n.commonBack,
                    size: 44,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      key: const Key('search-field'),
                      controller: _query,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onChanged: (_) => _search(),
                      decoration: InputDecoration(
                        hintText: context.l10n.searchInTitle(widget.title),
                        prefixIcon: const Icon(Icons.search_rounded),
                        isDense: true,
                        suffixIcon: _query.text.isEmpty
                            ? null
                            : IconButton(
                                key: const Key('search-clear'),
                                tooltip: context.l10n.commonClear,
                                icon: const Icon(Icons.close_rounded, size: 20),
                                onPressed: () {
                                  _query.clear();
                                  _search();
                                },
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(
                  spacing: 8,
                  children: [
                    _chip(const Key('search-filter-photos'), context.l10n.searchPictures, Icons.photo_rounded,
                        _photos, () => _toggle(() => _photos = !_photos)),
                    _chip(const Key('search-filter-videos'), context.l10n.searchVideos, Icons.videocam_rounded,
                        _videos, () => _toggle(() => _videos = !_videos)),
                    _chip(const Key('search-filter-voice'), context.l10n.searchVoice, Icons.mic_rounded, _voice,
                        () => _toggle(() => _voice = !_voice)),
                    _chip(const Key('search-filter-mine'), context.l10n.searchFromMe, Icons.person_rounded, _mine,
                        () => _toggle(() => _mine = !_mine)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: !_hasCriteria
                  ? EmptyState(
                      mood: GhostMood.curious,
                      title: context.l10n.chatSearchTooltip,
                      message: context.l10n.searchEmptyBody,
                    )
                  : _results.isEmpty
                      ? EmptyState(
                          mood: GhostMood.oops,
                          title: context.l10n.homeNothingFound,
                          message: context.l10n.searchNoMatch,
                        )
                      : ListView.builder(
                          key: const Key('search-results'),
                          // Scrolling through the results puts the keyboard away.
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          itemCount: _results.length,
                          itemBuilder: (context, i) => _ResultTile(
                            message: _results[i],
                            author: widget.authorOf(_results[i]),
                            needle: _query.text.trim(),
                            onTap: () => Navigator.pop(context, _results[i].id),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.message,
    required this.author,
    required this.needle,
    required this.onTap,
  });

  final ChatMessage message;
  final String author;
  final String needle;
  final VoidCallback onTap;

  /// The text with every match of [needle] in bold.
  List<TextSpan> _highlighted(String text, Color highlight) {
    if (needle.isEmpty) return [TextSpan(text: text)];
    final spans = <TextSpan>[];
    final lower = text.toLowerCase();
    final n = needle.toLowerCase();
    var from = 0;
    while (true) {
      final at = lower.indexOf(n, from);
      if (at < 0) break;
      if (at > from) spans.add(TextSpan(text: text.substring(from, at)));
      spans.add(TextSpan(
        text: text.substring(at, at + n.length),
        style: TextStyle(color: highlight, fontWeight: FontWeight.w800),
      ));
      from = at + n.length;
    }
    if (from < text.length) spans.add(TextSpan(text: text.substring(from)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final icon = messageSnippetIcon(message);
    return ListTile(
      key: Key('search-result-${message.id}'),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Row(
        children: [
          Expanded(
            child: Text(author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
          Text(formatListTime(message.sortTimeMs, context.l10n),
              style: TextStyle(color: context.palette.textMuted, fontSize: 12)),
        ],
      ),
      subtitle: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: context.palette.textSecondary),
            const SizedBox(width: 5),
          ],
          Expanded(
            child: Text.rich(
              TextSpan(
                  children: _highlighted(
                      messageSnippet(message, context.l10n), context.palette.accentSoft)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.palette.textSecondary, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}
