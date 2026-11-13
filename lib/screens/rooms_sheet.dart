import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_scope.dart';
import '../core/bidi.dart';
import '../core/format.dart';
import '../models/conversation.dart';
import '../models/room.dart';
import '../protocol/protocol_constants.dart';
import '../services/message_service.dart';
import '../theme/app_theme.dart';
import '../theme/surfaces.dart';
import '../widgets/peer_avatar.dart';
import '../widgets/prompts.dart';
import '../widgets/radar.dart';
import '../l10n/l10n.dart';

/// Asks for a name (and an optional description) and creates a public room.
/// Returns the new room, or null if the person backed out.
Future<PublicRoom?> showCreateRoomDialog(BuildContext context) {
  final c = AppScope.read(context);
  return showDialog<PublicRoom>(
    context: context,
    barrierColor: context.palette.scrim,
    builder: (context) => _CreateRoomDialog(controller: c),
  );
}

class _CreateRoomDialog extends StatefulWidget {
  const _CreateRoomDialog({required this.controller});

  final AppController controller;

  @override
  State<_CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends State<_CreateRoomDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _description = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final room = await widget.controller.createRoom(
        _name.text,
        description: _description.text,
      );
      if (mounted) Navigator.pop(context, room);
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
    return AppDialogFrame(
      title: context.l10n.roomsCreateTitle,
      message: context.l10n.roomsCreateBody,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('room-name'),
            controller: _name,
            autofocus: true,
            maxLength: Protocol.maxRoomNameBytes,
            textCapitalization: TextCapitalization.none,
            decoration: InputDecoration(
              prefixText: '#',
              hintText: context.l10n.roomsNameHint,
              counterText: '',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('room-description'),
            controller: _description,
            maxLength: Protocol.maxRoomDescriptionBytes,
            decoration: InputDecoration(
              hintText: context.l10n.roomsAboutHint,
              counterText: '',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: context.palette.danger, fontSize: 13),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('room-create'),
          onPressed: _busy ? null : _create,
          child: Text(context.l10n.commonCreate),
        ),
      ],
    );
  }
}

/// The rooms this phone knows: joined ones to open (and to leave), nearby ones to join,
/// and a button to create one. Returns the conversation id to open, or null.
Future<String?> showRoomsSheet(BuildContext context, {String? currentRoomId}) {
  return showAppSheet<String>(
    context: context,
    builder: (context) => _RoomsSheet(currentRoomId: currentRoomId),
  );
}

class _RoomsSheet extends StatelessWidget {
  const _RoomsSheet({this.currentRoomId});

  final String? currentRoomId;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.read(context);
    return ValueListenableBuilder<List<PublicRoom>>(
      valueListenable: c.roomsListenable,
      builder: (context, rooms, _) {
        final joined = rooms.where((r) => r.joined).toList();
        final nearby = rooms.where((r) => !r.joined).toList();
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          // Not a lazy list: the few rows are all built, so the button at the end is
          // always there to be reached.
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.s),
                  child: Text(
                    context.l10n.roomsTitle,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                for (final r in joined)
                  _RoomRow(
                    room: r,
                    current: r.id == currentRoomId,
                    trailing: r.id == currentRoomId
                        ? Icon(
                            Icons.check_rounded,
                            color: context.palette.accentSoft,
                          )
                        // The built-in room is never left; any other can be.
                        : (r.builtin
                              ? null
                              : IconButton(
                                  key: Key('leave-${r.id}'),
                                  tooltip: context.l10n.commonLeave,
                                  icon: const Icon(
                                    Icons.logout_rounded,
                                    size: 20,
                                  ),
                                  onPressed: () => confirmAndRun(
                                    context,
                                    title: context.l10n.homeLeaveRoomTitle(
                                      isolatedIn(context, r.label),
                                    ),
                                    message: context.l10n.homeLeaveRoomBody,
                                    action: context.l10n.commonLeave,
                                    run: () => c.leaveRoom(r.id),
                                  ),
                                )),
                    onTap: () => Navigator.pop(
                      context,
                      Conversation.roomConversationId(r.id),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
                  child: Text(
                    context.l10n.homeNearbyRooms,
                    style: TextStyle(
                      color: context.palette.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (nearby.isEmpty)
                  Padding(
                    key: const Key('rooms-listening'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        const RadarPulse(size: 40),
                        const SizedBox(width: AppSpace.m),
                        Expanded(
                          child: Text(
                            context.l10n.homeListeningForRooms,
                            style: TextStyle(
                              color: context.palette.textMuted,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (final r in nearby)
                    _RoomRow(
                      room: r,
                      trailing: FilledButton(
                        key: Key('join-${r.id}'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            final joinedRoom = await c.joinRoom(r.id);
                            navigator.pop(
                              Conversation.roomConversationId(joinedRoom.id),
                            );
                          } on MessageError catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text(e.message)),
                            );
                          }
                        },
                        child: Text(context.l10n.commonJoin),
                      ),
                      onTap: null,
                    ),
                const SizedBox(height: AppSpace.m),
                OutlinedButton.icon(
                  key: const Key('rooms-create'),
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final room = await showCreateRoomDialog(context);
                    if (room != null) {
                      navigator.pop(Conversation.roomConversationId(room.id));
                    }
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: Text(context.l10n.roomsCreateButton),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RoomRow extends StatelessWidget {
  const _RoomRow({
    required this.room,
    this.trailing,
    this.onTap,
    this.current = false,
  });

  final PublicRoom room;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      leading: PeerAvatar(
        name: room.name,
        seed: room.id,
        size: 42,
        kind: AvatarKind.room,
        ringColor: context.palette.surface,
      ),
      title: Text(
        isolatedIn(context, room.label),
        style: TextStyle(
          fontWeight: current ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      subtitle: Text(
        room.builtin
            // The built-in room's stored description is English; this is the same
            // line the header shows, in the language of the app.
            ? context.l10n.homeMeshSubtitle
            : (room.description.isEmpty
                  ? context.l10n.homeHeardAgo(
                      formatAgo(room.lastHeardAtMs, context.l10n),
                    )
                  : room.description),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: context.palette.textMuted, fontSize: 12.5),
      ),
      trailing: trailing,
    );
  }
}
