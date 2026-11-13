import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../app_scope.dart';
import '../core/format.dart';
import '../models/peer.dart';
import '../theme/app_theme.dart';
import '../theme/surfaces.dart';
import '../widgets/peer_avatar.dart';
import '../widgets/prompts.dart';
import '../widgets/setting_switch.dart';
import '../widgets/status_pill.dart';
import 'chat_screen.dart';
import '../l10n/l10n.dart';

/// One contact: who they are cryptographically, and how to verify them.
///
/// Meeting a phone over Bluetooth tells you its keys, but not WHO holds them:
/// somebody could present a fake key the first time two phones meet. The only
/// defence is to compare the safety number below with the other person over a
/// channel an attacker can't tamper with (in person, or a call you recognise
/// them on), and mark the contact verified only if the numbers match.
class PeerDetailScreen extends StatefulWidget {
  const PeerDetailScreen({super.key, required this.peerId});

  final String peerId;

  @override
  State<PeerDetailScreen> createState() => _PeerDetailScreenState();
}

class _PeerDetailScreenState extends State<PeerDetailScreen> {
  Peer? _peer;
  String? _safety;
  String? _fingerprint;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final c = AppScope.read(context);
    final peer = await c.peer(widget.peerId);
    final safety = peer == null ? null : await c.safetyNumberFor(peer);
    final fp = peer == null ? null : await c.fingerprintFor(peer);
    if (!mounted) return;
    setState(() {
      _peer = peer;
      _safety = safety;
      _fingerprint = fp;
      _loading = false;
    });
  }

  Future<void> _rename() async {
    final c = AppScope.read(context);
    final value = await showTextPrompt(
      context,
      title: context.l10n.pdNameTitle,
      hint: _peer?.nickname ?? context.l10n.pdNameHint,
      initial: _peer?.alias ?? '',
    );
    if (value != null) {
      await c.setAlias(widget.peerId, value);
      await _load();
    }
  }
  Future<void> _confirmDelete() async {
    final c = AppScope.read(context);
    final navigator = Navigator.of(context);
    final ok = await showAppDialog<bool>(
      context: context,
      title: context.l10n.pdDeleteTitle,
      message: context.l10n.pdDeleteBody,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.commonCancel)),
        FilledButton(
          key: const Key('confirm-action'),
          style: FilledButton.styleFrom(backgroundColor: context.palette.danger),
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.l10n.commonDelete),
        ),
      ],
    );
    if (ok ?? false) {
      await c.deletePeer(widget.peerId);
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final peer = _peer;
    // Reachability changes while the page is open; rebuild when it does.
    return ValueListenableBuilder<List<PeerView>>(
      valueListenable: c.peersListenable,
      builder: (context, _, _) => _page(context, c, peer),
    );
  }

  Widget _page(BuildContext context, AppController c, Peer? peer) {
    return AppScaffold(
      appBar: AppBar(leading: const BackButton(), title: Text(context.l10n.pdTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : peer == null
              ? Center(child: Text(context.l10n.pdGone))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    Row(
                      children: [
                        PeerAvatar(
                          name: peer.displayName,
                          seed: peer.id,
                          status: c.statusOf(peer.id),
                          size: 64,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(peer.displayName,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                              if (peer.alias != null && peer.nickname.isNotEmpty)
                                Text(context.l10n.pdCallsThemselves(peer.nickname),
                                    style: TextStyle(color: context.palette.textMuted, fontSize: 13)),
                              const SizedBox(height: 6),
                              ReachabilityPill(c.statusOf(peer.id), long: true),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: peer.blocked
                          ? null
                          : () async {
                              final nav = Navigator.of(context);
                              nav.pop();
                              await openChatWith(nav.context, peer.id);
                            },
                      icon: const Icon(Icons.chat_bubble_rounded),
                      label: Text(context.l10n.pdSendMessage),
                    ),
                    const SizedBox(height: 20),
                    _Section(
                      title: peer.verified ? context.l10n.pdVerified : context.l10n.pdNotVerified,
                      icon: peer.verified ? Icons.verified_user_rounded : Icons.shield_outlined,
                      color: peer.verified ? context.palette.accent : context.palette.pending,
                      children: [
                        Text(
                          context.l10n.pdVerifyBody,
                          style: TextStyle(color: context.palette.textMuted, height: 1.4, fontSize: 13.5),
                        ),
                        const SizedBox(height: 14),
                        if (_safety == null)
                          Text(context.l10n.pdNoKey,
                              style: TextStyle(color: context.palette.pending))
                        else ...[
                          Text(context.l10n.pdSafetyNumber,
                              style: TextStyle(color: context.palette.textMuted, fontSize: 12)),
                          const SizedBox(height: 6),
                          InkWell(
                            onLongPress: () {
                              Clipboard.setData(ClipboardData(text: _safety!));
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(content: Text(context.l10n.actCopied)));
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: context.palette.surfaceHigh,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _safety!,
                                // The same digits in the same order on both phones,
                                // whatever the language of either one.
                                textDirection: TextDirection.ltr,
                                textAlign: TextAlign.center,
                                style: monoStyle(
                                  fontSize: 22,
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w700,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.l10n.pdSafetyNote,
                            style: TextStyle(color: context.palette.textMuted.withValues(alpha: 0.9), fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 8),
                        SettingSwitch(
                          padding: const EdgeInsetsDirectional.only(top: 4, bottom: 4),
                          title: context.l10n.pdNumbersMatch,
                          subtitle: context.l10n.pdMarkVerified,
                          value: peer.verified,
                          onChanged: _safety == null
                              ? null
                              : (v) async {
                                  await c.setVerified(peer.id, v);
                                  await _load();
                                },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _Section(
                      title: context.l10n.actDetails,
                      icon: Icons.fingerprint_rounded,
                      color: context.palette.textMuted,
                      children: [
                        _row(context.l10n.pdShortId, '#${peer.shortId}', ltr: true),
                        _row(context.l10n.pdFirstSeen, formatDateTime(peer.firstSeenMs), ltr: true),
                        _row(context.l10n.pdLastSeen, formatAgo(peer.lastSeenMs, context.l10n)),
                        if (_fingerprint != null) ...[
                          const SizedBox(height: 8),
                          Text(context.l10n.pdFullFingerprint,
                              style: TextStyle(color: context.palette.textMuted, fontSize: 12)),
                          const SizedBox(height: 4),
                          SelectableText(
                            _fingerprint!,
                            textDirection: TextDirection.ltr,
                            style: monoStyle(fontSize: 12.5, height: 1.5),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.edit_rounded),
                            title: Text(context.l10n.pdRename),
                            subtitle: Text(context.l10n.pdRenameBody),
                            onTap: _rename,
                          ),
                          const Divider(),
                          SettingSwitch(
                            icon: Icons.block_rounded,
                            title: context.l10n.pdBlock,
                            subtitle: context.l10n.pdBlockBody,
                            value: peer.blocked,
                            onChanged: (v) async {
                              await c.setBlocked(peer.id, v);
                              await _load();
                            },
                          ),
                          const Divider(),
                          ListTile(
                            leading: Icon(Icons.delete_outline_rounded, color: context.palette.danger),
                            title: Text(context.l10n.pdDeleteContact,
                                style: TextStyle(color: context.palette.danger)),
                            onTap: _confirmDelete,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _row(String k, String v, {bool ltr = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
                width: 96,
                child: Text(k, style: TextStyle(color: context.palette.textMuted, fontSize: 13))),
            Expanded(
                child: Text(v,
                    textDirection: ltr ? TextDirection.ltr : null,
                    textAlign: ltr && Directionality.of(context) == TextDirection.rtl
                        ? TextAlign.right
                        : TextAlign.start,
                    style: const TextStyle(fontSize: 13.5))),
          ],
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}
