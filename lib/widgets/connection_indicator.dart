import 'dart:async';

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_scope.dart';
import '../services/network_status_service.dart';
import '../theme/app_theme.dart';
import '../transport/ble_radio.dart';
import '../l10n/l10n.dart';

/// The one-glance answer to "is this phone able to talk to anyone right now?".
class ConnectionSummary {
  const ConnectionSummary(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;

  /// [n] describes the live network, [l] says it in the person's language and [p] colours
  /// it; that is all this needs.
  static ConnectionSummary of(NetworkSnapshot n, AppLocalizations l, AppPalette p) {
    if (n.startError != null) {
      return ConnectionSummary(l.connError, p.danger, Icons.error_outline_rounded);
    }
    if (!n.started) {
      return ConnectionSummary(
        n.starting ? l.connStarting : l.connNotStarted,
        p.offline,
        Icons.bluetooth_disabled_rounded,
      );
    }
    switch (n.radioStatus.blocker) {
      case RadioAvailability.unsupported:
        return ConnectionSummary(l.connNotSupported, p.danger, Icons.block_rounded);
      case RadioAvailability.unauthorized:
        return ConnectionSummary(l.connPermissionNeeded, p.pending, Icons.lock_outline_rounded);
      case RadioAvailability.poweredOff:
        return ConnectionSummary(l.connBluetoothOff, p.danger, Icons.bluetooth_disabled_rounded);
      case RadioAvailability.unknown:
        return ConnectionSummary(l.connStarting, p.offline, Icons.bluetooth_searching_rounded);
      case RadioAvailability.poweredOn:
      case null:
        break;
    }
    final direct = n.neighborCount;
    final relayed = n.reachableCount - direct;
    if (direct > 0 && relayed > 0) {
      return ConnectionSummary(l.connNearbyRelayed(direct, relayed), p.direct, Icons.hub_rounded);
    }
    if (direct > 0) {
      return ConnectionSummary(l.connNearby(direct), p.direct, Icons.bluetooth_connected_rounded);
    }
    if (relayed > 0) {
      return ConnectionSummary(l.connViaRelay(relayed), p.relay, Icons.hub_rounded);
    }
    return ConnectionSummary(l.connSearching, p.relay, Icons.bluetooth_searching_rounded);
  }
}

/// A line that always shows the live connection state - a coloured icon and the words:
/// nearby phones, phones reachable only through relays, or what is wrong. Tapping it
/// opens the list of phones. Rebuilds only when that state changes.
class ConnectionIndicator extends StatelessWidget {
  const ConnectionIndicator({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.read(context);
    return ValueListenableBuilder<NetworkSnapshot>(
      valueListenable: c.networkListenable,
      builder: (context, n, _) {
        final s = ConnectionSummary.of(n, context.l10n, context.palette);
        final line = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(s.icon, size: 15, color: s.color),
            const SizedBox(width: 6),
            // Shrinks (with an ellipsis) instead of overflowing when space is tight:
            // narrow screens, or large system font sizes.
            Flexible(
              child: Text(
                s.label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: s.color, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
        if (onTap == null) return line;
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Align(alignment: AlignmentDirectional.centerStart, widthFactor: 1, child: line),
          ),
        );
      },
    );
  }
}

/// Says plainly that this app works without the internet: "Offline" while there
/// is none, and "Internet is on, but not used" while there is. It is about the
/// internet only; whether anyone can be reached by Bluetooth is the
/// [ConnectionIndicator] next to it.
class OfflineBadge extends StatefulWidget {
  const OfflineBadge({super.key});

  @override
  State<OfflineBadge> createState() => _OfflineBadgeState();
}

class _OfflineBadgeState extends State<OfflineBadge> {
  NetworkKind? _kind;
  StreamSubscription<NetworkKind>? _sub;

  @override
  void initState() {
    super.initState();
    final c = AppScope.read(context);
    c.networkKind().then((k) {
      if (mounted) setState(() => _kind = k);
    });
    _sub = c.networkChanges.listen((k) {
      if (mounted) setState(() => _kind = k);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kind = _kind;
    if (kind == null) return const SizedBox.shrink();
    final offline = kind == NetworkKind.none;
    final color = offline ? context.palette.accentSoft : context.palette.textMuted;
    return Tooltip(
      message: offline ? context.l10n.offlineTipNone : context.l10n.offlineTipOn,
      child: Row(
        key: const Key('offline-badge'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(offline ? Icons.cloud_off_rounded : Icons.cloud_queue_rounded, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            offline ? context.l10n.offlineBadge : context.l10n.internetOnBadge,
            maxLines: 1,
            style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
