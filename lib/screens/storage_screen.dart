import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_scope.dart';
import '../core/format.dart';
import '../theme/app_theme.dart';
import '../widgets/skeleton.dart';
import '../theme/surfaces.dart';
import '../widgets/prompts.dart';
import '../l10n/l10n.dart';

/// What the app keeps on this phone, and ways to free it. Everything here is
/// local: removing something never tells anyone else.
class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  StorageUsage? _usage;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final usage = await AppScope.read(context).storageUsage();
    if (mounted) setState(() => _usage = usage);
  }

  Future<void> _cleanPublic() async {
    final c = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    setState(() => _busy = true);
    final r = await c.cleanPublicChats();
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(
      content: Text(r.messages == 0 ? l.stNothingToClean : l.stRemovedPublic(r.messages)),
    ));
    await _load();
  }

  Future<void> _deleteMedia() async {
    final c = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final ok = await showDangerConfirm(
      context,
      title: l.stDeleteMediaTitle,
      body: l.stDeleteMediaBody,
      action: l.stDeleteMediaAction,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final n = await c.deleteAllMedia();
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(
      content: Text(n == 0 ? l.stNothingToDelete : l.stDeletedMedia(n)),
    ));
    await _load();
  }

  Widget _row(Key key, IconData icon, String title, String value, {String? note}) {
    return ListTile(
      key: key,
      leading: Icon(icon, color: context.palette.textMuted),
      title: Text(title),
      subtitle: note == null ? null : Text(note),
      trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = _usage;
    final c = AppScope.of(context);
    return AppScaffold(
      appBar: AppBar(leading: const BackButton(), title: Text(context.l10n.setStorage)),
      body: u == null
          ? const ListSkeleton(rows: 5)
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
              children: [
                Card(
                  child: Column(
                    children: [
                      _row(const Key('storage-messages'), Icons.chat_bubble_outline_rounded,
                          context.l10n.stMessages, '${u.messages}'),
                      const Divider(),
                      _row(
                        const Key('storage-media'),
                        Icons.perm_media_outlined,
                        context.l10n.stMedia,
                        formatBytes(u.mediaBytes),
                        note: context.l10n.stFiles(u.mediaCount),
                      ),
                      if (u.databaseBytes > 0) ...[
                        const Divider(),
                        _row(const Key('storage-database'), Icons.storage_rounded,
                            context.l10n.stDatabase, formatBytes(u.databaseBytes)),
                      ],
                      const Divider(),
                      _row(
                        const Key('storage-public'),
                        Icons.public_rounded,
                        context.l10n.stPublic,
                        context.l10n.stMessagesCount(u.publicMessages),
                        note: u.lastCleanupAtMs == null
                            ? context.l10n.stPublicNoteNever
                            : context.l10n.stPublicNote(
                                formatAgo(u.lastCleanupAtMs!, context.l10n), u.lastCleanupRemoved),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.l10n.stVideoLimit, style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.stVideoLimitBody(formatBytes(AppController.videoLimitChoices.last)),
                          style: TextStyle(
                              color: context.palette.textMuted, fontSize: 13.5, height: 1.3),
                        ),
                        DropdownButton<int>(
                          key: const Key('video-limit'),
                          value: c.videoSendLimit,
                          isExpanded: true,
                          dropdownColor: context.palette.surfaceHigh,
                          underline: const SizedBox.shrink(),
                          onChanged: (v) {
                            if (v != null) c.setVideoSendLimit(v);
                          },
                          items: [
                            for (final bytes in AppController.videoLimitChoices)
                              DropdownMenuItem<int>(value: bytes, child: Text(formatBytes(bytes))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        key: const Key('storage-clean-public'),
                        enabled: !_busy,
                        leading: const Icon(Icons.cleaning_services_outlined),
                        title: Text(context.l10n.stCleanNow),
                        subtitle: Text(context.l10n.stCleanNowBody),
                        onTap: _cleanPublic,
                      ),
                      const Divider(),
                      ListTile(
                        key: const Key('storage-delete-media'),
                        enabled: !_busy && u.mediaCount > 0,
                        leading: Icon(Icons.delete_sweep_outlined, color: context.palette.danger),
                        title: Text(context.l10n.stDeleteMediaTile,
                            style: TextStyle(color: context.palette.danger)),
                        subtitle: Text(context.l10n.stDeleteMediaTileBody),
                        onTap: _deleteMedia,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(4, 14, 4, 0),
                  child: Text(
                    context.l10n.stFooter,
                    style: TextStyle(color: context.palette.textMuted, fontSize: 12.5, height: 1.4),
                  ),
                ),
              ],
            ),
    );
  }
}
