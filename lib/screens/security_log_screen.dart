import 'dart:async';

import 'package:flutter/material.dart';

import '../core/bidi.dart';
import '../app_scope.dart';
import '../core/format.dart';
import '../database/message_repository.dart';
import '../theme/app_theme.dart';
import '../theme/surfaces.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton.dart';
import '../widgets/ghost_mark.dart' show GhostMood;
import '../widgets/prompts.dart';
import '../l10n/l10n.dart';

/// Things that went wrong in a way that might be an attack, a bug or just a
/// bad radio link: forged or corrupted messages, failed identity checks,
/// changed keys. Messages that fail verification are never shown as chat; they
/// end up here instead.
class SecurityLogScreen extends StatefulWidget {
  const SecurityLogScreen({super.key});

  @override
  State<SecurityLogScreen> createState() => _SecurityLogScreenState();
}

class _SecurityLogScreenState extends State<SecurityLogScreen> {
  List<SecurityEvent>? _events;
  StreamSubscription<DataChange>? _sub;

  @override
  void initState() {
    super.initState();
    final c = AppScope.read(context);
    _sub = c.dataChanges.where((d) => d == DataChange.securityEvents).listen((_) => _load());
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final events = await AppScope.read(context).securityEvents();
    if (!mounted) return;
    setState(() => _events = events);
  }

  Future<void> _clear() async {
    final c = AppScope.read(context);
    final ok = await showDangerConfirm(
      context,
      title: context.l10n.secClearTitle,
      body: context.l10n.secClearBody,
      action: context.l10n.commonClear,
    );
    if (ok) {
      await c.clearSecurityEvents();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = _events;
    return AppScaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.l10n.setSecurityLog),
        actions: [
          if (events != null && events.isNotEmpty)
            IconButton(
              tooltip: context.l10n.secClearTooltip,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _clear,
            ),
        ],
      ),
      body: events == null
          ? const ListSkeleton(rows: 6)
          : events.isEmpty
              ? EmptyState(
                  mood: GhostMood.happy,
                  title: context.l10n.secEmptyTitle,
                  message: context.l10n.secEmptyBody,
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: events.length,
                  separatorBuilder: (context, index) => const Divider(indent: 72, endIndent: 16),
                  itemBuilder: (context, i) => _EventTile(event: events[i]),
                ),
    );
  }
}

class _Described {
  const _Described(this.title, this.explanation, this.icon, this.color);

  final String title;
  final String explanation;
  final IconData icon;
  final Color color;
}

_Described _describe(AppLocalizations l, AppPalette p, String kind) {
  switch (kind) {
    case SecurityEventKind.badSignature:
      return _Described(l.secBadSignatureTitle, l.secBadSignatureBody, Icons.gpp_bad_rounded, p.danger);
    case SecurityEventKind.decryptFailed:
      return _Described(l.secDecryptFailedTitle, l.secDecryptFailedBody,
          Icons.enhanced_encryption_outlined, p.danger);
    case SecurityEventKind.linkAuthFailed:
      return _Described(l.secLinkAuthTitle, l.secLinkAuthBody, Icons.link_off_rounded, p.danger);
    case SecurityEventKind.keyChanged:
      return _Described(l.secKeyChangedTitle, l.secKeyChangedBody, Icons.key_off_rounded, p.pending);
    case SecurityEventKind.rateLimited:
      return _Described(l.secRateLimitedTitle, l.secRateLimitedBody, Icons.speed_rounded, p.pending);
    case SecurityEventKind.malformed:
      return _Described(
          l.secMalformedTitle, l.secMalformedBody, Icons.broken_image_outlined, p.pending);
    case SecurityEventKind.notAMember:
      return _Described(l.secNotAMemberTitle, l.secNotAMemberBody, Icons.group_off_rounded, p.danger);
    case SecurityEventKind.unauthorizedChange:
      return _Described(l.secUnauthorizedTitle, l.secUnauthorizedBody, Icons.edit_off_rounded, p.danger);
    case SecurityEventKind.badMedia:
      return _Described(l.secBadMediaTitle, l.secBadMediaBody, Icons.broken_image_outlined, p.pending);
    case SecurityEventKind.protocolError:
      return _Described(l.secProtocolTitle, l.secProtocolBody, Icons.rule_rounded, p.pending);
    default:
      return _Described(kind, l.secUnknownBody, Icons.info_outline_rounded, p.textMuted);
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final SecurityEvent event;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final d = _describe(context.l10n, context.palette, event.kind);
    final id = event.peerId;
    String? who;
    if (id != null) {
      final known = c.peers.where((p) => p.peer.id == id).firstOrNull;
      who = known != null
          ? known.peer.displayName
          : context.l10n.secUnknownPhone(
              isolatedIn(context, '#${id.length >= 8 ? id.substring(0, 8) : id}'));
    }
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: d.color.withValues(alpha: 0.15),
        child: Icon(d.icon, color: d.color, size: 22),
      ),
      title: Text(d.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(d.explanation,
                style: TextStyle(color: context.palette.textMuted, fontSize: 12.5, height: 1.35)),
            const SizedBox(height: 4),
            // The date, the phone and the technical detail (written in English, as
            // log lines are) read left to right whatever the language of the app.
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                [
                  formatDateTime(event.atMs),
                  ?who,
                  if (event.detail != null && event.detail!.isNotEmpty) event.detail!,
                ].join(' · '),
                textDirection: TextDirection.ltr,
                style: TextStyle(color: context.palette.textMuted, fontSize: 11.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
