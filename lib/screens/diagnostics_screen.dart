import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../core/app_log.dart';
import '../services/ble_self_test.dart';
import '../theme/app_theme.dart';
import '../theme/surfaces.dart';
import '../l10n/l10n.dart';
import '../widgets/ltr.dart';

/// The Bluetooth self-test and the activity log.
///
/// This is how "does Bluetooth actually work on these phones?" gets answered:
/// no simulator can say so. Run it on two phones side by side (Wi-Fi and mobile
/// data off) and every step either passes or tells you what to fix.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  late final BleSelfTest _test;
  bool _showLog = false;

  @override
  void initState() {
    super.initState();
    _test = AppScope.read(context).createSelfTest();
  }

  @override
  void dispose() {
    _test.dispose();
    super.dispose();
  }

  static const int _reportLogLines = 60;
  static const int _shownLogLines = 80;

  List<String> _recentLog(AppLog log, int n) {
    final entries = log.entries;
    final from = entries.length > n ? entries.length - n : 0;
    return [for (final e in entries.sublist(from)) e.toString()];
  }

  Future<void> _copy(String text, String done) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return AppScaffold(
      appBar: AppBar(leading: const BackButton(), title: Text(context.l10n.setSelfTest)),
      body: ListenableBuilder(
        listenable: _test,
        builder: (context, _) {
          final started = _test.results.any((r) => r.state != CheckState.pending);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              const _Intro(),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _test.running
                        ? OutlinedButton.icon(
                            key: const Key('stop-self-test'),
                            onPressed: _test.cancel,
                            icon: const Icon(Icons.stop_rounded),
                            label: Text(context.l10n.commonStop),
                          )
                        : FilledButton.icon(
                            key: const Key('run-self-test'),
                            onPressed: _test.run,
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: Text(started ? context.l10n.diagRunAgain : context.l10n.diagRun),
                          ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    key: const Key('copy-report'),
                    onPressed: started
                        ? () => _copy(
                              _test.report(logLines: _recentLog(c.log, _reportLogLines)),
                              context.l10n.diagReportCopied,
                            )
                        : null,
                    icon: const Icon(Icons.copy_rounded),
                    label: Text(context.l10n.diagCopyReport),
                  ),
                ],
              ),
              if (!_test.running && _test.finishedAt != null) ...[
                const SizedBox(height: 14),
                _Verdict(_test.overall),
              ],
              const SizedBox(height: 14),
              for (final r in _test.results) _CheckTile(result: r),
              const SizedBox(height: 18),
              const _Limits(),
              const SizedBox(height: 18),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: Text(context.l10n.diagLogTitle),
                      subtitle: Text(context.l10n.diagLogNote),
                      trailing: Icon(_showLog ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                      onTap: () => setState(() => _showLog = !_showLog),
                    ),
                    if (_showLog) _LogView(log: c.log, lines: _shownLogLines, onCopy: _copy),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.diagIntroTitle,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text(
              context.l10n.diagIntroBody,
              style: TextStyle(color: context.palette.textMuted, height: 1.4, fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict(this.overall);

  final CheckState overall;

  @override
  Widget build(BuildContext context) {
    final (color, icon, title, text) = switch (overall) {
      CheckState.passed => (
          context.palette.direct,
          Icons.check_circle_rounded,
          context.l10n.diagPass,
          context.l10n.diagPassBody,
        ),
      CheckState.warning => (
          context.palette.pending,
          Icons.warning_amber_rounded,
          context.l10n.diagWarn,
          context.l10n.diagWarnBody,
        ),
      CheckState.failed => (
          context.palette.danger,
          Icons.cancel_rounded,
          context.l10n.diagFail,
          context.l10n.diagFailBody,
        ),
      _ => (context.palette.offline, Icons.help_outline_rounded, context.l10n.diagNoResult, ''),
    };
    return Container(
      key: const Key('self-test-verdict'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
                if (text.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(text, style: const TextStyle(fontSize: 13, height: 1.35)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckTile extends StatelessWidget {
  const _CheckTile({required this.result});

  final CheckResult result;

  @override
  Widget build(BuildContext context) {
    final (Widget icon, Color color) = switch (result.state) {
      CheckState.pending => (
          Icon(Icons.radio_button_unchecked_rounded, color: context.palette.offline),
          context.palette.offline
        ),
      CheckState.running => (
          const SizedBox(
              width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
          context.palette.accent
        ),
      CheckState.passed => (
          Icon(Icons.check_circle_rounded, color: context.palette.direct),
          context.palette.direct
        ),
      CheckState.warning => (
          Icon(Icons.warning_amber_rounded, color: context.palette.pending),
          context.palette.pending
        ),
      CheckState.failed => (
          Icon(Icons.cancel_rounded, color: context.palette.danger),
          context.palette.danger
        ),
      CheckState.skipped => (
          Icon(Icons.remove_circle_outline_rounded, color: context.palette.offline),
          context.palette.offline
        ),
    };
    final skipped = result.state == CheckState.skipped;
    return Padding(
      key: Key('check-${result.id}'),
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 26, child: Center(child: icon)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: skipped ? context.palette.textMuted : context.palette.text,
                      ),
                    ),
                    if (result.detail.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        result.detail,
                        style: TextStyle(
                            color: context.palette.textMuted, fontSize: 13, height: 1.35),
                      ),
                    ],
                    if (result.advice != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lightbulb_outline_rounded, size: 16, color: color),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(result.advice!,
                                  style: const TextStyle(fontSize: 12.5, height: 1.35)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Limits extends StatelessWidget {
  const _Limits();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.diagLimitsTitle,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          SizedBox(height: 6),
          Text(
            context.l10n.diagLimitsBody,
            style: TextStyle(color: context.palette.textMuted, fontSize: 12.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _LogView extends StatelessWidget {
  const _LogView({required this.log, required this.lines, required this.onCopy});

  final AppLog log;
  final int lines;
  final Future<void> Function(String text, String done) onCopy;

  static Color _color(AppPalette p, LogLevel l) => switch (l) {
        LogLevel.error => p.danger,
        LogLevel.warning => p.pending,
        LogLevel.info => p.text,
        LogLevel.debug => p.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: log,
      builder: (context, _) {
        final all = log.entries;
        final shown = all.length > lines ? all.sublist(all.length - lines) : all;
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TextButton.icon(
                    onPressed: all.isEmpty ? null : () => onCopy(log.dump(), context.l10n.diagLogCopied),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: Text(context.l10n.commonCopy),
                  ),
                  TextButton.icon(
                    onPressed: all.isEmpty ? null : log.clear,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(context.l10n.commonClear),
                  ),
                ],
              ),
              Text(
                context.l10n.diagLogWarn,
                style: TextStyle(color: context.palette.textMuted, fontSize: 12, height: 1.35),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.palette.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: shown.isEmpty
                    ? Text(context.l10n.diagLogEmpty,
                        style: TextStyle(color: context.palette.textMuted, fontSize: 12))
                    : Ltr(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final e in shown.reversed)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 1.5),
                              child: Text(
                                e.toString(),
                                style: monoStyle(
                                  fontSize: 10.5,
                                  height: 1.3,
                                  color: _color(context.palette, e.level),
                                ),
                              ),
                            ),
                        ],
                      )),
              ),
            ],
          ),
        );
      },
    );
  }
}
