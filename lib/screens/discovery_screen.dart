import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_scope.dart';
import '../core/format.dart';
import '../l10n/labels.dart';
import '../services/bluetooth_service.dart';
import '../services/discovery_service.dart';
import '../theme/app_theme.dart';
import '../theme/surfaces.dart';
import '../transport/ble_radio.dart';
import '../transport/mesh_transport.dart';
import '../widgets/connection_indicator.dart';
import '../widgets/ltr.dart';
import '../widgets/radio_status_banner.dart';
import '../widgets/status_pill.dart';
import 'diagnostics_screen.dart';
import '../l10n/l10n.dart';

/// What the radio is doing right now: the nearby-device discovery screen.
///
/// Shows three different things that are easy to confuse:
///  * devices HEARD (an advertisement was received; not yet a person),
///  * LINKS (a Bluetooth connection exists; possibly still verifying),
///  * and, on the People tab, verified PEERS.
class DiscoveryScreen extends StatelessWidget {
  const DiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return AppScaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.l10n.nearbyTitle),
        actions: const [
          Padding(
            padding: EdgeInsetsDirectional.only(end: 12),
            child: Center(child: ConnectionIndicator()),
          ),
        ],
      ),
      // Raw live radio state: it changes many times a second, so this screen
      // listens to the throttled "live" signal instead of the whole app.
      body: ListenableBuilder(
        listenable: c.liveChanges,
        builder: (context, _) => _body(context, c),
      ),
    );
  }

  Widget _body(BuildContext context, AppController c) {
    final devices = c.nearbyDevices;
    final links = c.links;
    final status = c.radioStatus;
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        const RadioStatusBanner(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusRow(
                    label: context.l10n.setBluetooth,
                    pill: _availabilityPill(context.l10n, context.palette, status),
                  ),
                  _StatusRow(
                    label: context.l10n.nearbyVisible,
                    pill: c.isAdvertising
                        ? StatusPill(
                            label: context.l10n.commonYes,
                            color: context.palette.direct,
                          )
                        : StatusPill(
                            label: context.l10n.commonNo,
                            color: context.palette.offline,
                          ),
                  ),
                  _StatusRow(
                    label: context.l10n.nearbySearching,
                    pill: c.isScanning
                        ? StatusPill(
                            label: context.l10n.nearbyScanningNow,
                            color: context.palette.relay,
                          )
                        : StatusPill(
                            label: c.discovery.isRunning
                                ? context.l10n.nearbyBetweenScans
                                : context.l10n.nearbyStopped,
                            color: context.palette.offline,
                          ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.nearbyHowHard,
                    style: TextStyle(
                      color: context.palette.textMuted,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<DiscoveryMode>(
                      showSelectedIcon: false,
                      segments: [
                        for (final m in DiscoveryMode.values)
                          ButtonSegment(value: m, label: Text(m.localized(context.l10n))),
                      ],
                      selected: {c.discoveryMode},
                      onSelectionChanged: (s) => c.setDiscoveryMode(s.first),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const DiagnosticsScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.bug_report_outlined),
                      label: Text(context.l10n.nearbyRunSelfTest),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _SectionTitle(context.l10n.nearbyConnected(links.length)),
        if (links.isEmpty)
          _Hint(
            context.l10n.nearbyNoLinks,
          )
        else
          for (final l in links) _LinkTile(link: l, nameOf: _nameFor(c, l)),
        _SectionTitle(context.l10n.nearbyHeard(devices.length)),
        if (devices.isEmpty)
          _Hint(
            context.l10n.nearbyNothingHeard,
          )
        else
          for (final d in devices) _DeviceTile(device: d),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Text(
            context.l10n.nearbyFootnote,
            style: TextStyle(
              color: context.palette.textMuted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  static String? _nameFor(AppController c, LinkSnapshot l) {
    final id = l.peerId;
    if (id == null) return null;
    final known = c.peers.where((p) => p.peer.id == id).firstOrNull;
    if (known != null) return known.peer.displayName;
    final nick = l.nickname;
    return (nick == null || nick.isEmpty) ? null : nick;
  }

  static Widget _availabilityPill(AppLocalizations l, AppPalette p, RadioStatus s) {
    switch (s.blocker) {
      case RadioAvailability.unsupported:
        return StatusPill(
          label: s.canScan ? l.nearbyCannotAdvertise : l.connNotSupported,
          color: s.canScan ? p.pending : p.danger,
        );
      case RadioAvailability.unauthorized:
        return StatusPill(
          label: l.connPermissionNeeded,
          color: p.pending,
        );
      case RadioAvailability.poweredOff:
        return StatusPill(label: l.commonOff, color: p.danger);
      case RadioAvailability.unknown:
        return StatusPill(label: l.nearbyStartingPill, color: p.offline);
      case RadioAvailability.poweredOn:
      case null:
        return StatusPill(label: l.commonOn, color: p.direct);
    }
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.pill});

  final String label;
  final Widget pill;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14.5))),
        // The pill gives way (it ends in an ellipsis) before the row overflows.
        Flexible(child: pill),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
    child: Text(
      text,
      style: TextStyle(
        color: context.palette.textMuted,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    ),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Text(
      text,
      style: TextStyle(
        color: context.palette.textMuted,
        fontSize: 13,
        height: 1.4,
      ),
    ),
  );
}

class _SignalBars extends StatelessWidget {
  const _SignalBars(this.rssi);

  final int rssi;

  @override
  Widget build(BuildContext context) {
    final bars = rssiBars(rssi);
    return Ltr(
        child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 1; i <= 4; i++)
          Container(
            width: 4,
            height: 4.0 + i * 3,
            margin: const EdgeInsetsDirectional.only(end: 2),
            decoration: BoxDecoration(
              color: i <= bars ? context.palette.accent : context.palette.outline,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
      ],
    ));
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.link, required this.nameOf});

  final LinkSnapshot link;
  final String? nameOf;

  @override
  Widget build(BuildContext context) {
    final ready = link.phase == LinkPhase.ready;
    final color = switch (link.phase) {
      LinkPhase.ready => context.palette.direct,
      LinkPhase.handshaking => context.palette.pending,
      LinkPhase.closing => context.palette.offline,
    };
    final label = switch (link.phase) {
      LinkPhase.ready => context.l10n.linkConnected,
      LinkPhase.handshaking => context.l10n.linkVerifying,
      LinkPhase.closing => context.l10n.linkClosing,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      nameOf ?? (ready ? context.l10n.linkUnnamed : context.l10n.linkUnverified),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                      ),
                    ),
                  ),
                  StatusPill(label: label, color: color, dense: true),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  _kv(
                    context,
                    context.l10n.linkRole,
                    link.role == LinkRole.central
                        ? context.l10n.linkWeConnected
                        : context.l10n.linkTheyConnected,
                  ),
                  _kv(context, context.l10n.linkWriteSize, '${link.maxChunk} B'),
                  if (link.rssi != null) _kv(context, context.l10n.linkSignal, '${link.rssi} dBm'),
                  if (link.lastRttMs != null)
                    _kv(context, context.l10n.linkRoundTrip, '${link.lastRttMs} ms'),
                  _kv(
                    context,
                    context.l10n.linkTraffic,
                    '↓ ${formatBytes(link.bytesIn)}  ↑ ${formatBytes(link.bytesOut)}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '$k  ',
          style: TextStyle(color: context.palette.textMuted, fontSize: 12.5),
        ),
        TextSpan(
          text: v,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device});

  final NearbyDevice device;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (device.state) {
      DeviceState.seen => (context.l10n.devHeard, context.palette.relay),
      DeviceState.connecting => (context.l10n.devConnecting, context.palette.pending),
      DeviceState.connected => (context.l10n.devLinked, context.palette.direct),
      DeviceState.backoff => (context.l10n.devRetrying, context.palette.offline),
      DeviceState.alreadyLinked => (context.l10n.devAlreadyLinked, context.palette.direct),
    };
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: _SignalBars(device.rssi),
      title: Text(
        device.deviceId.length > 13
            ? '…${device.deviceId.substring(device.deviceId.length - 12)}'
            : device.deviceId,
        style: monoStyle(fontSize: 13),
      ),
      subtitle: Text(
        [
          '${device.rssi} dBm',
          context.l10n.homeHeardAgo(formatAgo(device.lastSeenMs, context.l10n)),
          if (device.failures > 0)
            context.l10n.devFailedAttempts(device.failures),
          if (device.lastError != null && device.state == DeviceState.backoff)
            device.lastError!,
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: context.palette.textMuted),
      ),
      trailing: StatusPill(label: label, color: color, dense: true),
    );
  }
}
