import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_scope.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../theme/surfaces.dart';
import '../transport/ble_radio.dart';

enum _Severity { error, warning, info }

class _Problem {
  const _Problem(this.severity, this.title, this.message, {this.actions = const []});

  final _Severity severity;
  final String title;
  final String message;
  final List<_Action> actions;
}

class _Action {
  const _Action(this.label, this.run, {this.primary = false});

  final String label;
  final Future<void> Function(AppController) run;
  final bool primary;
}

_Problem? _describe(AppLocalizations l, NetworkSnapshot n) {
  if (n.startError != null) {
    return _Problem(
      _Severity.error,
      l.radioCouldNotStart,
      n.startError!,
      actions: [_Action(l.commonTryAgain, (c) => c.startNetworking(), primary: true)],
    );
  }
  if (!n.started) {
    if (n.starting) return null;
    return _Problem(
      _Severity.info,
      l.radioNotStarted,
      l.radioNotStartedBody,
      actions: [_Action(l.commonStart, (c) => c.startNetworking(), primary: true)],
    );
  }
  final status = n.radioStatus;
  switch (status.blocker) {
    case RadioAvailability.unsupported:
      if (status.canScan) {
        // Can scan but not advertise: partly usable.
        return _Problem(_Severity.warning, l.radioNotVisible, l.radioNotVisibleBody);
      }
      return _Problem(_Severity.error, l.radioNoBle, l.radioNoBleBody);
    case RadioAvailability.unauthorized:
      return _Problem(
        _Severity.warning,
        l.radioPermission,
        l.radioPermissionBody,
        actions: [
          _Action(l.radioAllow, (c) => c.requestPermissions(), primary: true),
          _Action(l.commonOpenSettings, (c) => c.openSystemSettings()),
        ],
      );
    case RadioAvailability.poweredOff:
      return _Problem(_Severity.error, l.radioOff, l.radioOffBody);
    case RadioAvailability.unknown:
      return null;
    case RadioAvailability.poweredOn:
    case null:
      break;
  }
  final error = n.radioError;
  if (error != null) {
    return _Problem(_Severity.warning, l.radioProblem, error);
  }
  return null;
}

/// Explains, in plain words, why this phone can't currently reach anyone and
/// what to do about it. Renders nothing when everything is fine.
class RadioStatusBanner extends StatelessWidget {
  const RadioStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context); // rebuilds for the identity notice
    return ValueListenableBuilder<NetworkSnapshot>(
      valueListenable: c.networkListenable,
      builder: (context, network, _) {
        final problem = _describe(context.l10n, network);
        final notices = <Widget>[];
        if (problem != null) notices.add(_BannerCard(problem: problem, controller: c));
        final l = context.l10n;
        // A phone nearby speaks another version of the app: the two cannot
        // talk, and the person would otherwise never learn why.
        for (final (shown, key, title, body) in [
          (network.newerVersionNearby, 'version-newer', l.versionNewerTitle, l.versionNewerBody),
          (network.olderVersionNearby, 'version-older', l.versionOlderTitle, l.versionOlderBody),
        ]) {
          if (!shown) continue;
          notices.add(KeyedSubtree(
            key: Key(key),
            child: _BannerCard(
              controller: c,
              problem: _Problem(
                _Severity.info,
                title,
                body,
                actions: [
                  _Action(l.commonDismiss, (c) async => c.dismissVersionNotice(), primary: true),
                ],
              ),
            ),
          ));
        }
        if (c.identityWasReset) {
          notices.add(_BannerCard(
            controller: c,
            problem: _Problem(
              _Severity.warning,
              context.l10n.identityResetTitle,
              context.l10n.identityResetBody,
              actions: [
                _Action(context.l10n.commonDismiss, (c) async => c.dismissIdentityNotice(),
                    primary: true),
              ],
            ),
          ));
        }
        if (notices.isEmpty) return const SizedBox.shrink();
        return Column(children: notices);
      },
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.problem, required this.controller});

  final _Problem problem;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final color = switch (problem.severity) {
      _Severity.error => context.palette.danger,
      _Severity.warning => context.palette.pending,
      _Severity.info => context.palette.accentSoft,
    };
    final icon = switch (problem.severity) {
      _Severity.error => Icons.error_outline_rounded,
      _Severity.warning => Icons.warning_amber_rounded,
      _Severity.info => Icons.info_outline_rounded,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: AppPanel(
        radius: 18,
        tint: color,
        borderColor: color.withValues(alpha: 0.45),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    problem.title,
                    style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              problem.message,
              style: TextStyle(color: context.palette.text, fontSize: 13.5, height: 1.4),
            ),
            if (problem.actions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final a in problem.actions)
                    a.primary
                        ? FilledButton(
                            onPressed: () => a.run(controller),
                            style: FilledButton.styleFrom(
                              backgroundColor: color,
                              foregroundColor: context.palette.onStatus,
                              minimumSize: const Size(0, 38),
                            ),
                            child: Text(a.label),
                          )
                        : OutlinedButton(
                            onPressed: () => a.run(controller),
                            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                            child: Text(a.label),
                          ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
