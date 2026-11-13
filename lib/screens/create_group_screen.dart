import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_scope.dart';
import '../models/conversation.dart';
import '../protocol/protocol_constants.dart';
import '../services/message_service.dart';
import '../theme/app_theme.dart';
import '../theme/surfaces.dart';
import '../widgets/empty_state.dart';
import '../widgets/peer_avatar.dart';
import '../widgets/status_pill.dart';
import 'chat_screen.dart';
import '../l10n/l10n.dart';

/// People who can be invited to a group: known, not blocked, and with an
/// encryption key (the invitation is sealed to it).
List<PeerView> invitablePeers(List<PeerView> peers, {Set<String> exclude = const <String>{}}) {
  return [
    for (final v in peers)
      if (!exclude.contains(v.peer.id) && !v.peer.blocked) v,
  ];
}

/// A list of people with checkboxes. Used to create a group and to add people
/// to one.
class PeerChecklist extends StatelessWidget {
  const PeerChecklist({
    super.key,
    required this.peers,
    required this.selected,
    required this.onToggle,
    required this.maxSelected,
  });

  final List<PeerView> peers;
  final Set<String> selected;
  final void Function(String id) onToggle;
  final int maxSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final v in peers)
          Builder(builder: (context) {
            final p = v.peer;
            final on = selected.contains(p.id);
            final blockedByKey = !p.canReceiveEncrypted;
            final full = !on && selected.length >= maxSelected;
            final enabled = !blockedByKey && !full;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: AppPanel(
                radius: 18,
                tint: on ? context.palette.accent : null,
                child: ListTile(
                  key: Key('pick-${p.id}'),
                  enabled: enabled,
                  onTap: enabled ? () => onToggle(p.id) : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  leading: PeerAvatar(name: p.displayName, seed: p.id, status: v.status, size: 42),
                  title: Text(p.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: blockedByKey
                      ? Text(context.l10n.groupNoKeyYet,
                          style: TextStyle(color: context.palette.pending, fontSize: 12))
                      : Text(reachabilityShort(context.l10n, v.status),
                          style: TextStyle(
                              color: reachabilityColor(v.status.reachability, context.palette), fontSize: 12)),
                  trailing: Checkbox(
                    value: on,
                    onChanged: enabled ? (_) => onToggle(p.id) : null,
                    shape: const CircleBorder(),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

/// Name a group and choose who is in it. Everyone chosen gets a sealed
/// invitation (they must accept it); only the people in the group can ever see
/// that it exists.
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _name = TextEditingController();
  final Set<String> _selected = <String>{};
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _toggle(String id) => setState(() {
        if (!_selected.remove(id)) _selected.add(id);
      });

  Future<void> _create() async {
    final c = AppScope.read(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final g = await c.createGroup(_name.text, _selected.toList());
      navigator.pushReplacement(MaterialPageRoute<void>(
        builder: (_) => ChatScreen(conversationId: Conversation.groupConversationId(g.id)),
      ));
    } on MessageError catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.read(context);
    final max = Protocol.maxGroupMembers - 1;
    return AppScaffold(
      appBar: AppBar(
        title: Text(context.l10n.fabNewGroup),
        leading: const BackButton(),
      ),
      body: ValueListenableBuilder<List<PeerView>>(
          valueListenable: c.peersListenable,
          builder: (context, allPeers, _) {
            final peers = invitablePeers(allPeers);
            final ready = _name.text.trim().isNotEmpty && _selected.isNotEmpty && !_busy;
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                    children: [
                      TextField(
                        key: const Key('group-name'),
                        controller: _name,
                        maxLength: Protocol.maxGroupNameBytes,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: context.l10n.groupNameLabel,
                          counterText: '',
                          prefixIcon: Icon(Icons.groups_rounded, color: context.palette.accentSoft),
                        ),
                      ),
                      const SizedBox(height: 10),
                      AppPanel(
                        radius: 16,
                        padding: EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lock_outline_rounded, size: 18, color: context.palette.accentSoft),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                context.l10n.groupCreateNote,
                                style: TextStyle(
                                    color: context.palette.textSecondary, fontSize: 12.5, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
                        child: Text(
                          context.l10n.groupAddPeople(_selected.length, max),
                          style: TextStyle(
                              color: context.palette.textMuted, fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (peers.isEmpty)
                        SizedBox(
                          height: 280,
                          child: EmptyState(
                            title: context.l10n.groupNobodyToAdd,
                            message: context.l10n.groupNobodyBody,
                          ),
                        )
                      else
                        PeerChecklist(
                          peers: peers,
                          selected: _selected,
                          onToggle: _toggle,
                          maxSelected: max,
                        ),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    child: Text(_error!,
                        style: TextStyle(color: context.palette.danger, fontSize: 13)),
                  ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const Key('group-create'),
                        onPressed: ready ? _create : null,
                        icon: const Icon(Icons.check_rounded),
                        label: Text(_busy ? context.l10n.groupCreating : context.l10n.groupCreate),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
    );
  }
}
