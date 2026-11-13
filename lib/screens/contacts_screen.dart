import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_scope.dart';
import '../theme/app_theme.dart';
import '../theme/surfaces.dart';
import '../widgets/connection_indicator.dart';
import '../widgets/empty_state.dart';
import '../widgets/ghost_mark.dart' show GhostMood;
import '../widgets/peer_tile.dart';
import '../widgets/radio_status_banner.dart';
import 'chat_screen.dart';
import 'discovery_screen.dart';
import 'peer_detail_screen.dart';
import '../l10n/l10n.dart';

enum _Filter { all, reachable, contacts }

/// Everyone this phone has met or heard about, with live reachability.
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  _Filter _filter = _Filter.all;

  void _openNearby() => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const DiscoveryScreen()));

  @override
  Widget build(BuildContext context) {
    final c = AppScope.read(context);
    return AppScaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.l10n.homePeople),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: Center(child: ConnectionIndicator(onTap: _openNearby)),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<PeerView>>(
        valueListenable: c.peersListenable,
        builder: (context, all, _) {
          final shown = switch (_filter) {
            _Filter.all => all,
            _Filter.reachable => all.where((p) => p.isReachable).toList(),
            _Filter.contacts => all.where((p) => p.peer.isContact).toList(),
          };
          return Column(
            children: [
              const RadioStatusBanner(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final (f, label, count) in [
                      (_Filter.all, context.l10n.peopleFilterAll, all.length),
                      (_Filter.reachable, context.l10n.peopleFilterReachable, all.where((p) => p.isReachable).length),
                      (_Filter.contacts, context.l10n.peopleFilterContacts, all.where((p) => p.peer.isContact).length),
                    ])
                      ChoiceChip(
                        label: Text('$label · $count'),
                        selected: _filter == f,
                        selectedColor: context.palette.accent.withValues(alpha: 0.3),
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: shown.isEmpty
                    ? EmptyState(
                        mood: all.isEmpty ? GhostMood.sleepy : GhostMood.curious,
                        title: all.isEmpty ? context.l10n.peopleEmptyTitle : context.l10n.peopleEmptyFilterTitle,
                        message: all.isEmpty
                            ? context.l10n.peopleEmptyBody
                            : context.l10n.peopleEmptyFilterBody,
                        action: all.isEmpty
                            ? OutlinedButton.icon(
                                onPressed: _openNearby,
                                icon: const Icon(Icons.radar_rounded),
                                label: Text(context.l10n.peopleSeeNearby),
                              )
                            : null,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 4, bottom: 24),
                        itemCount: shown.length,
                        itemBuilder: (context, i) {
                          final v = shown[i];
                          return PeerTile(
                            view: v,
                            onTap: () => openChatWith(context, v.peer.id),
                            trailing: IconButton(
                              tooltip: context.l10n.peopleDetailsTooltip,
                              icon: Icon(
                                v.peer.verified
                                    ? Icons.verified_user_rounded
                                    : Icons.shield_outlined,
                                color: v.peer.verified ? context.palette.accentSoft : context.palette.textMuted,
                              ),
                              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                                builder: (_) => PeerDetailScreen(peerId: v.peer.id),
                              )),
                            ),
                            onLongPress: () => Navigator.of(context).push(MaterialPageRoute<void>(
                              builder: (_) => PeerDetailScreen(peerId: v.peer.id),
                            )),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Picks a person to start a conversation with.
Future<void> pickPeerAndChat(BuildContext context) async {
  final c = AppScope.read(context);
  final candidates =
      c.peers.where((p) => p.peer.canReceiveEncrypted && !p.peer.blocked).toList();
  if (candidates.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(context.l10n.peoplePickEmpty),
    ));
    return;
  }
  final chosen = await showAppSheet<PeerView>(
    context: context,
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.65),
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(context.l10n.fabNewMessage, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          for (final v in candidates)
            PeerTile(view: v, onTap: () => Navigator.pop(context, v), trailing: const SizedBox()),
        ],
      ),
    ),
  );
  if (chosen != null && context.mounted) {
    await openChatWith(context, chosen.peer.id);
  }
}
