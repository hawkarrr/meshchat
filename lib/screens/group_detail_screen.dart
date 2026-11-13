import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_scope.dart';
import '../models/group.dart';
import '../protocol/protocol_constants.dart';
import '../services/message_service.dart';
import '../theme/app_theme.dart';
import '../theme/surfaces.dart';
import '../widgets/peer_avatar.dart';
import '../widgets/status_pill.dart';
import 'create_group_screen.dart';
import '../l10n/l10n.dart';

/// Who is in a group, and what you can do about it. Only the admin can add or
/// remove people; changing the membership gives the group a new key.
class GroupDetailScreen extends StatelessWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.read(context);
    return AppScaffold(
      appBar: AppBar(title: Text(context.l10n.chatGroupDetails), leading: const BackButton()),
      body: ValueListenableBuilder<List<GroupChat>>(
          valueListenable: c.groupsListenable,
          builder: (context, groups, _) {
            final group = groups.where((g) => g.id == groupId).firstOrNull;
            if (group == null) {
              return Center(
                child: Text(context.l10n.gdGone, style: TextStyle(color: context.palette.textMuted)),
              );
            }
            return ValueListenableBuilder<List<PeerView>>(
              valueListenable: c.peersListenable,
              builder: (context, peers, _) => _Body(group: group, peers: peers, controller: c),
            );
          },
        ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.group, required this.peers, required this.controller});

  final GroupChat group;
  final List<PeerView> peers;
  final AppController controller;

  bool get _admin => group.adminId == controller.identityId;

  Future<void> _run(BuildContext context, Future<void> Function() action,
      {String? done, bool popAfter = false}) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await action();
      if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
      if (popAfter) navigator.popUntil((r) => r.isFirst);
    } on MessageError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<bool> _confirm(BuildContext context, String title, String message, String action) async {
    final ok = await showAppDialog<bool>(
      context: context,
      title: title,
      message: message,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.commonCancel)),
        Builder(
          builder: (context) => FilledButton(
            key: const Key('confirm-action'),
            style: FilledButton.styleFrom(backgroundColor: context.palette.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ),
      ],
    );
    return ok ?? false;
  }

  Future<void> _addPeople(BuildContext context) async {
    final ids = await Navigator.of(context).push<List<String>>(MaterialPageRoute(
      builder: (_) => _AddPeopleScreen(group: group),
    ));
    if (ids == null || ids.isEmpty || !context.mounted) return;
    await _run(context, () => controller.addGroupMembers(group.id, ids),
        done: context.l10n.gdInvitationsSent);
  }

  @override
  Widget build(BuildContext context) {
    final byId = {for (final v in peers) v.peer.id: v};
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
      children: [
        Center(
          child: Column(
            children: [
              PeerAvatar(name: group.name, seed: group.id, size: 84, kind: AvatarKind.group),
              const SizedBox(height: 12),
              Text(group.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                '${context.l10n.chatGroupMembers(group.members.length)} · ${switch (group.state) {
                  GroupState.active => context.l10n.gdStateActive,
                  GroupState.left => context.l10n.gdStateLeft,
                  GroupState.removed => context.l10n.gdStateRemoved,
                  GroupState.invited => context.l10n.gdStateInvited,
                }}',
                style: TextStyle(color: context.palette.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
                  context.l10n.gdEncryptedNote,
                  style: TextStyle(color: context.palette.textSecondary, fontSize: 12.5, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(4, 18, 4, 6),
          child: Text(context.l10n.gdMembers,
              style: TextStyle(color: context.palette.textMuted, fontWeight: FontWeight.w700)),
        ),
        for (final m in group.members)
          Builder(builder: (context) {
            final me = m.id == controller.identityId;
            final view = byId[m.id];
            final isAdmin = m.id == group.adminId;
            final name = me ? context.l10n.commonYou : (view?.peer.displayName ?? (m.nickname.isEmpty ? 'Peer ${m.id.substring(0, 8)}' : m.nickname));
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: AppPanel(
                radius: 18,
                child: ListTile(
                  key: Key('member-${m.id}'),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  leading: PeerAvatar(name: name, seed: m.id, status: view?.status, size: 42),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(width: 8),
                        StatusPill(label: context.l10n.gdAdmin, color: context.palette.accentSoft, dense: true),
                      ],
                    ],
                  ),
                  subtitle: me || view == null
                      ? null
                      : Text(reachabilityShort(context.l10n, view.status),
                          style: TextStyle(
                              color: reachabilityColor(view.status.reachability, context.palette), fontSize: 12)),
                  trailing: _admin && !me && group.isActive
                      ? IconButton(
                          key: Key('remove-${m.id}'),
                          tooltip: context.l10n.gdRemoveTooltip,
                          icon: Icon(Icons.person_remove_rounded, color: context.palette.danger),
                          onPressed: () async {
                            final ok = await _confirm(
                              context,
                              context.l10n.gdRemoveTitle(name),
                              context.l10n.gdRemoveBody,
                              context.l10n.commonRemove,
                            );
                            if (ok && context.mounted) {
                              await _run(context,
                                  () => controller.removeGroupMember(group.id, m.id));
                            }
                          },
                        )
                      : null,
                ),
              ),
            );
          }),
        const SizedBox(height: 16),
        if (_admin && group.isActive) ...[
          OutlinedButton.icon(
            key: const Key('group-add'),
            onPressed: group.members.length >= Protocol.maxGroupMembers
                ? null
                : () => _addPeople(context),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: Text(group.members.length >= Protocol.maxGroupMembers
                ? context.l10n.gdFull
                : context.l10n.gdAddPeople),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('group-delete'),
            style: OutlinedButton.styleFrom(foregroundColor: context.palette.danger),
            onPressed: () async {
              final ok = await _confirm(
                context,
                context.l10n.homeDeleteGroupTitle,
                context.l10n.gdDeleteBody,
                context.l10n.gdDeleteAction,
              );
              if (ok && context.mounted) {
                await _run(context, () => controller.deleteGroup(group.id), popAfter: true);
              }
            },
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(context.l10n.gdDeleteButton),
          ),
        ] else if (!_admin && group.isActive)
          OutlinedButton.icon(
            key: const Key('group-leave'),
            style: OutlinedButton.styleFrom(foregroundColor: context.palette.danger),
            onPressed: () async {
              final ok = await _confirm(
                context,
                context.l10n.homeLeaveGroupTitle,
                context.l10n.gdLeaveBody,
                context.l10n.commonLeave,
              );
              if (ok && context.mounted) {
                await _run(context, () => controller.leaveGroup(group.id), popAfter: true);
              }
            },
            icon: const Icon(Icons.logout_rounded),
            label: Text(context.l10n.gdLeaveButton),
          )
        else
          OutlinedButton.icon(
            key: const Key('group-forget'),
            style: OutlinedButton.styleFrom(foregroundColor: context.palette.danger),
            onPressed: () async {
              final ok = await _confirm(
                context,
                context.l10n.gdForgetTitle,
                context.l10n.gdForgetBody,
                context.l10n.commonDelete,
              );
              if (ok && context.mounted) {
                await _run(context, () => controller.removeGroupFromPhone(group.id),
                    popAfter: true);
              }
            },
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(context.l10n.gdForgetButton),
          ),
      ],
    );
  }
}

class _AddPeopleScreen extends StatefulWidget {
  const _AddPeopleScreen({required this.group});

  final GroupChat group;

  @override
  State<_AddPeopleScreen> createState() => _AddPeopleScreenState();
}

class _AddPeopleScreenState extends State<_AddPeopleScreen> {
  final Set<String> _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final c = AppScope.read(context);
    final room = Protocol.maxGroupMembers - widget.group.members.length;
    return AppScaffold(
      appBar: AppBar(title: Text(context.l10n.gdAddPeople), leading: const BackButton()),
      body: ValueListenableBuilder<List<PeerView>>(
          valueListenable: c.peersListenable,
          builder: (context, all, _) {
            final peers = invitablePeers(all, exclude: {for (final m in widget.group.members) m.id});
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                        child: Text(context.l10n.gdSelectedOf(_selected.length, room),
                            style: TextStyle(
                                color: context.palette.textMuted, fontWeight: FontWeight.w700)),
                      ),
                      PeerChecklist(
                        peers: peers,
                        selected: _selected,
                        maxSelected: room,
                        onToggle: (id) => setState(() {
                          if (!_selected.remove(id)) _selected.add(id);
                        }),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('add-people-confirm'),
                        onPressed:
                            _selected.isEmpty ? null : () => Navigator.pop(context, _selected.toList()),
                        child: Text(context.l10n.gdInvite),
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
