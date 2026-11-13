import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../app_scope.dart';
import '../device/device_io.dart';
import '../l10n/l10n.dart';
import '../l10n/labels.dart';
import '../services/discovery_service.dart';
import '../services/network_status_service.dart';
import '../services/notification_coordinator.dart';
import '../theme/app_theme.dart';
import '../theme/surfaces.dart';
import '../transport/ble_radio.dart';
import '../widgets/language_picker.dart';
import '../widgets/peer_avatar.dart';
import '../widgets/permission_prompt.dart';
import '../widgets/prompts.dart';
import '../widgets/setting_switch.dart';
import '../widgets/status_pill.dart';
import 'diagnostics_screen.dart';
import 'security_log_screen.dart';
import 'storage_screen.dart';

/// A page of the settings: a title bar and, under it, the sections of one subject.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpace.m, AppSpace.m, AppSpace.m, 40),
            children: children,
          ),
        ),
      ),
    );
  }
}

/// The small blue heading above a section of a settings page.
class SettingsHeading extends StatelessWidget {
  const SettingsHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.l, AppSpace.xs, AppSpace.s),
        child: Text(text,
            style: TextStyle(
                color: context.palette.accentSoft, fontWeight: FontWeight.w700, fontSize: 13.5)),
      );
}

// =============================================================================
// Profile and identity
// =============================================================================

/// Who this phone is on the mesh: the name nearby people see, the short id, and the
/// fingerprint that contacts compare to be sure it is really this person.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _editNickname(BuildContext context) async {
    final c = AppScope.read(context);
    final value = await showTextPrompt(
      context,
      title: context.l10n.setName,
      message: context.l10n.setNameBody,
      hint: context.l10n.setNicknameHint,
      initial: c.nickname,
      fieldKey: const Key('nickname-field'),
    );
    if (value != null) await c.setNickname(value);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final shortId = c.identityId.substring(0, 8);
    return SettingsPage(
      title: context.l10n.setProfileTitle,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PeerAvatar(name: c.nickname, seed: c.identityId, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.nickname,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text('#$shortId',
                              textDirection: TextDirection.ltr,
                              style: monoStyle(color: context.palette.textMuted, fontSize: 13)),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('edit-nickname'),
                      tooltip: context.l10n.setChangeName,
                      icon: const Icon(Icons.edit_rounded),
                      onPressed: () => _editNickname(context),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(context.l10n.setFingerprint,
                    style: TextStyle(color: context.palette.textMuted, fontSize: 12)),
                const SizedBox(height: 4),
                SelectableText(
                  c.fingerprintText,
                  textDirection: TextDirection.ltr,
                  style: monoStyle(fontSize: 12.5, height: 1.5),
                ),
                const SizedBox(height: 6),
                // A column, not a row: the word on the button is long in some languages and
                // the system text can be large, and a row would squeeze the sentence out.
                Text(
                  context.l10n.setFingerprintBody,
                  style: TextStyle(color: context.palette.textMuted, fontSize: 12, height: 1.35),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: c.fingerprintText));
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.l10n.setFingerprintCopied)));
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: Text(context.l10n.commonCopy),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Language
// =============================================================================

/// The language of the whole app; the choice applies at once.
class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsPage(
      title: context.l10n.setLanguage,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.setLanguageBody,
                    style: TextStyle(color: context.palette.textMuted, fontSize: 13.5, height: 1.3)),
                const SizedBox(height: 10),
                const LanguagePicker(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Notifications
// =============================================================================

/// Whether, and how much, a notification shows when a message arrives while the
/// app is not on screen.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  static String _privacyHelp(AppLocalizations l, NotificationPrivacy p) => switch (p) {
        NotificationPrivacy.full => l.setNotifyFullHelp,
        NotificationPrivacy.sender => l.setNotifySenderHelp,
        NotificationPrivacy.hidden => l.setNotifyHiddenHelp,
      };

  static String _privacyLabel(AppLocalizations l, NotificationPrivacy p) => switch (p) {
        NotificationPrivacy.full => l.setNotifyFull,
        NotificationPrivacy.sender => l.setNotifySender,
        NotificationPrivacy.hidden => l.setNotifyHidden,
      };

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return SettingsPage(
      title: context.l10n.setNotifications,
      children: [
        Card(
          child: Column(
            children: [
              SettingSwitch(
                key: const Key('notify-switch'),
                icon: Icons.notifications_rounded,
                title: context.l10n.setNotifyTitle,
                subtitle: context.l10n.setNotifyBody,
                value: c.notificationsEnabled,
                onChanged: (on) async {
                  await c.setNotificationsEnabled(on);
                  if (on && context.mounted) {
                    await ensurePermission(context, AppPermission.notifications);
                  }
                },
              ),
              if (c.notificationsEnabled) ...[
                const _NotificationPermissionHint(),
                const Divider(),
                ChoiceRow<NotificationPrivacy>(
                  icon: Icons.visibility_outlined,
                  title: context.l10n.setNotifyShows,
                  subtitle: _privacyHelp(context.l10n, c.notificationPrivacy),
                  dropdownKey: const Key('notify-privacy'),
                  value: c.notificationPrivacy,
                  choices: {
                    for (final p in NotificationPrivacy.values) p: _privacyLabel(context.l10n, p)
                  },
                  onChanged: c.setNotificationPrivacy,
                ),
                const Divider(),
                SettingSwitch(
                  key: const Key('notify-public'),
                  icon: Icons.public_rounded,
                  title: context.l10n.setNotifyPublic,
                  subtitle: context.l10n.setNotifyPublicBody,
                  value: c.notifyPublicRooms,
                  onChanged: c.setNotifyPublicRooms,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Under the notification switch: when it is on here but the phone does not allow
/// notifications, none will ever appear, and the switch alone would not say so. This
/// says it, with the button that asks (or, if the phone was told never to ask again,
/// goes to its settings). It is not there while they are allowed.
class _NotificationPermissionHint extends StatefulWidget {
  const _NotificationPermissionHint();

  @override
  State<_NotificationPermissionHint> createState() => _NotificationPermissionHintState();
}

class _NotificationPermissionHintState extends State<_NotificationPermissionHint>
    with WidgetsBindingObserver {
  PermissionOutcome? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from the phone's own settings: show what was chosen there.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final status = await AppScope.read(context).io.permissions.status(AppPermission.notifications);
    if (mounted) setState(() => _status = status);
  }

  Future<void> _allow() async {
    await ensurePermission(context, AppPermission.notifications);
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null ||
        status == PermissionOutcome.granted ||
        status == PermissionOutcome.unavailable) {
      return const SizedBox.shrink();
    }
    return Padding(
      key: const Key('notify-not-allowed'),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 8, 8),
      child: AppPanel(
        radius: AppRadii.md,
        tint: context.palette.pending,
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.notifications_off_outlined, size: 18, color: context.palette.pending),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.setNotifyNotAllowed,
                    style: const TextStyle(fontSize: 13, height: 1.35),
                  ),
                ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                key: const Key('notify-allow'),
                onPressed: _allow,
                child: Text(status == PermissionOutcome.permanentlyDenied
                    ? context.l10n.settingsTitle
                    : context.l10n.commonAllow),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Privacy and security
// =============================================================================

/// What the app may use, what it keeps and for how long, the log of what failed a
/// check, and the two things that cannot be undone.
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  static const List<int> _retentionChoices = [0, 1, 7, 30];

  static String _retentionLabel(AppLocalizations l, int days) => switch (days) {
        0 => l.setRetForever,
        1 => l.setRetDay,
        _ => l.setRetDays(days),
      };

  Future<void> _resetIdentity(BuildContext context) async {
    final c = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final ok = await showDangerConfirm(
      context,
      title: l.setResetTitle,
      body: l.setResetBody,
      action: l.setResetAction,
    );
    if (!ok) return;
    await c.resetIdentity();
    messenger.showSnackBar(SnackBar(content: Text(l.setResetDone)));
  }

  Future<void> _clearAll(BuildContext context) async {
    final c = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final ok = await showDangerConfirm(
      context,
      title: l.setClearTitle,
      body: l.setClearBody,
      action: l.setClearAction,
      typeToConfirm: l.confirmWordDelete,
    );
    if (!ok) return;
    await c.clearAllData();
    messenger.showSnackBar(SnackBar(content: Text(l.setClearDone)));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = context.l10n;
    return SettingsPage(
      title: l.setPrivacy,
      children: [
        SettingsHeading(l.setPermissions),
        const _PermissionsCard(),
        SettingsHeading(l.setDataHeading),
        Card(
          child: Column(
            children: [
              ListTile(
                key: const Key('open-storage'),
                leading: const Icon(Icons.storage_rounded),
                title: Text(l.setStorage),
                subtitle: Text(l.setStorageBody),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => const StorageScreen())),
              ),
              const Divider(),
              ChoiceRow<int>(
                icon: Icons.history_toggle_off_rounded,
                title: l.setKeepMessages,
                subtitle: l.setKeepMessagesBody,
                dropdownKey: const Key('retention'),
                value: _retentionChoices.contains(c.retentionDays) ? c.retentionDays : 0,
                choices: {for (final d in _retentionChoices) d: _retentionLabel(l, d)},
                onChanged: c.setRetentionDays,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.gpp_maybe_outlined),
                title: Text(l.setSecurityLog),
                subtitle: Text(l.setSecurityLogBody),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => const SecurityLogScreen())),
              ),
            ],
          ),
        ),
        SettingsHeading(l.setDanger),
        Card(
          child: Column(
            children: [
              ListTile(
                key: const Key('reset-identity'),
                leading: Icon(Icons.refresh_rounded, color: context.palette.pending),
                title: Text(l.setResetAction),
                subtitle: Text(l.setResetTileBody),
                onTap: () => _resetIdentity(context),
              ),
              const Divider(),
              ListTile(
                key: const Key('clear-all-data'),
                leading: Icon(Icons.delete_forever_rounded, color: context.palette.danger),
                title: Text(l.setClearTile, style: TextStyle(color: context.palette.danger)),
                subtitle: Text(l.setClearTileBody),
                onTap: () => _clearAll(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// What the app may use, and a way to grant or revoke each one. Nothing is
/// requested here without the person pressing a button.
class _PermissionsCard extends StatefulWidget {
  const _PermissionsCard();

  @override
  State<_PermissionsCard> createState() => _PermissionsCardState();
}

class _PermissionsCardState extends State<_PermissionsCard> with WidgetsBindingObserver {
  final Map<AppPermission, PermissionOutcome> _state = <AppPermission, PermissionOutcome>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back from the system settings: show what the person chose there.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final io = AppScope.read(context).io;
    for (final p in AppPermission.values) {
      final s = await io.permissions.status(p);
      if (!mounted) return;
      setState(() => _state[p] = s);
    }
  }

  Future<void> _allow(AppPermission p) async {
    await ensurePermission(context, p);
    if (mounted) await _refresh();
  }

  static (IconData, String, String) _info(AppLocalizations l, AppPermission p) => switch (p) {
        AppPermission.microphone => (Icons.mic_rounded, l.setPermMic, l.setPermMicShort),
        AppPermission.camera => (Icons.photo_camera_rounded, l.setPermCamera, l.setPermCameraShort),
        AppPermission.photos => (Icons.photo_library_rounded, l.setPermPhotos, l.setPermPhotosShort),
        AppPermission.notifications =>
          (Icons.notifications_rounded, l.setNotifications, l.setPermNotifShort),
      };

  @override
  Widget build(BuildContext context) {
    final c = AppScope.read(context);
    return Card(
      child: Column(
        children: [
          ValueListenableBuilder<NetworkSnapshot>(
            valueListenable: c.networkListenable,
            builder: (context, n, _) {
              final blocker = n.radioStatus.blocker;
              final granted = n.started && blocker != RadioAvailability.unauthorized;
              return _PermissionRow(
                key: const Key('permission-bluetooth'),
                icon: Icons.bluetooth_rounded,
                title: context.l10n.setPermBluetooth,
                subtitle: context.l10n.setPermBluetoothWhy,
                trailing: granted
                    ? StatusPill(label: context.l10n.setAllowed, color: context.palette.direct, dense: true)
                    : TextButton(
                        onPressed: c.requestPermissions,
                        child: Text(context.l10n.commonAllow),
                      ),
              );
            },
          ),
          for (final p in AppPermission.values) ...[
            const Divider(),
            Builder(builder: (context) {
              final (icon, title, why) = _info(context.l10n, p);
              final s = _state[p];
              return _PermissionRow(
                key: Key('permission-${p.name}'),
                icon: icon,
                title: title,
                subtitle: why,
                trailing: switch (s) {
                  null => const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  PermissionOutcome.granted =>
                    StatusPill(label: context.l10n.setAllowed, color: context.palette.direct, dense: true),
                  PermissionOutcome.unavailable => StatusPill(
                      label: context.l10n.permNotAvailable, color: context.palette.offline, dense: true),
                  PermissionOutcome.denied || PermissionOutcome.permanentlyDenied => TextButton(
                      key: Key('allow-${p.name}'),
                      onPressed: () => _allow(p),
                      child: Text(s == PermissionOutcome.permanentlyDenied
                          ? context.l10n.settingsTitle
                          : context.l10n.commonAllow),
                    ),
                },
              );
            }),
          ],
        ],
      ),
    );
  }
}

/// One permission: what it is for, and its state or the button to allow it.
///
/// The button (or the "Allowed" pill) sits beside the words when there is room and
/// below them when there is not - a narrow phone, large system text, or a language
/// with long words - so the explanation never shrinks to a sliver.
class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return LayoutBuilder(builder: (context, constraints) {
      final stacked = scale > 1.3 || constraints.maxWidth < 300;
      final words = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: TextStyle(color: context.palette.textMuted, fontSize: 13.5, height: 1.3)),
        ],
      );
      final lead = Padding(
        padding: const EdgeInsetsDirectional.only(end: 16),
        child: Icon(icon, color: context.palette.textMuted),
      );
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 10),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [lead, Expanded(child: words)],
                  ),
                  Align(alignment: AlignmentDirectional.centerEnd, child: trailing),
                ],
              )
            : Row(
                children: [
                  lead,
                  Expanded(child: words),
                  const SizedBox(width: 8),
                  trailing,
                ],
              ),
      );
    });
  }
}

// =============================================================================
// Chats and Bluetooth
// =============================================================================

/// How the phone looks for others and behaves in the mesh: how hard it searches,
/// whether it passes messages on for other people, whether it keeps going with the
/// screen off - and the test that says whether Bluetooth works at all.
class ChatSettingsPage extends StatelessWidget {
  const ChatSettingsPage({super.key});

  static String _modeHelp(AppLocalizations l, DiscoveryMode m) => switch (m) {
        DiscoveryMode.balanced => l.modeBalancedHelp,
        DiscoveryMode.lowPower => l.modeLowPowerHelp,
        DiscoveryMode.aggressive => l.modeAggressiveHelp,
      };

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = context.l10n;
    return SettingsPage(
      title: l.setChatsBluetooth,
      children: [
        SettingsHeading(l.setBluetooth),
        Card(
          child: Column(
            children: [
              ChoiceRow<DiscoveryMode>(
                icon: Icons.radar_rounded,
                title: l.setSearchHow,
                subtitle: _modeHelp(l, c.discoveryMode),
                dropdownKey: const Key('discovery-mode'),
                value: c.discoveryMode,
                choices: {for (final m in DiscoveryMode.values) m: m.localized(l)},
                onChanged: c.setDiscoveryMode,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: Text(l.setSelfTest),
                subtitle: Text(l.setSelfTestBody),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => const DiagnosticsScreen())),
              ),
              const Divider(),
              const _NetworkRow(),
            ],
          ),
        ),
        SettingsHeading(l.setMeshBackground),
        const _MeshCard(),
      ],
    );
  }
}

/// Relaying for other people, and keeping the mesh alive with the screen off.
class _MeshCard extends StatelessWidget {
  const _MeshCard();

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return Card(
      child: Column(
        children: [
          SettingSwitch(
            key: const Key('relay-switch'),
            icon: Icons.share_outlined,
            title: context.l10n.setRelayTitle,
            subtitle: c.relayEnabled ? context.l10n.setRelayOn : context.l10n.setRelayOff,
            value: c.relayEnabled,
            onChanged: c.setRelayEnabled,
          ),
          const _RelayActivity(),
          const Divider(),
          if (c.keepAliveSupported)
            SettingSwitch(
              key: const Key('keepalive-switch'),
              icon: Icons.bluetooth_connected_rounded,
              title: context.l10n.setKeepAliveTitle,
              subtitle: context.l10n.setKeepAliveBody,
              value: c.keepAliveEnabled,
              onChanged: (on) async {
                final messenger = ScaffoldMessenger.of(context);
                final refused = context.l10n.setKeepAliveRefused;
                final ok = await c.setKeepAlive(on);
                if (!ok) {
                  messenger.showSnackBar(SnackBar(content: Text(refused)));
                }
              },
            ),
          if (c.keepAliveSupported) const _BatteryHint(),
          if (!c.keepAliveSupported)
            ListTile(
              key: const Key('keepalive-unsupported'),
              leading: const Icon(Icons.bluetooth_disabled_rounded),
              title: Text(context.l10n.setBackgroundUse),
              subtitle: Text(context.l10n.setBackgroundUseBody),
            ),
        ],
      ),
    );
  }
}

/// Under the background switch (Android): whether the phone's battery
/// optimisation still applies to the app. Many phones stop an optimised app's
/// Bluetooth work in the background whatever else it does, so this says so and
/// opens the page where it can be turned off. Read again when the person comes
/// back from that page. Says nothing when the phone would not tell.
class _BatteryHint extends StatefulWidget {
  const _BatteryHint();

  @override
  State<_BatteryHint> createState() => _BatteryHintState();
}

class _BatteryHintState extends State<_BatteryHint> with WidgetsBindingObserver {
  bool? _restricted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final restricted = await AppScope.read(context).io.keepAlive.batteryRestricted();
    if (mounted) setState(() => _restricted = restricted);
  }

  Future<void> _open() async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.setBatteryCouldNotOpen;
    final opened = await AppScope.read(context).io.keepAlive.openBatterySettings();
    if (!opened) messenger.showSnackBar(SnackBar(content: Text(failed)));
  }

  @override
  Widget build(BuildContext context) {
    final restricted = _restricted;
    if (restricted == null) return const SizedBox.shrink();
    final l = context.l10n;
    final color = restricted ? context.palette.pending : context.palette.direct;
    return Padding(
      key: const Key('battery-hint'),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 8, 8),
      child: AppPanel(
        radius: AppRadii.md,
        tint: color,
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    restricted ? Icons.battery_alert_rounded : Icons.battery_full_rounded,
                    size: 18,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.setBatteryTitle,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        restricted ? l.setBatteryRestricted : l.setBatteryUnrestricted,
                        style: const TextStyle(fontSize: 13, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (restricted)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  key: const Key('battery-open'),
                  onPressed: _open,
                  child: Text(l.setBatteryOpen),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// How much this phone has carried for others since the app started, so
/// relaying is never hidden: it says what the switch above has done.
class _RelayActivity extends StatefulWidget {
  const _RelayActivity();

  @override
  State<_RelayActivity> createState() => _RelayActivityState();
}

class _RelayActivityState extends State<_RelayActivity> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = AppScope.read(context).routerStats;
    final l = context.l10n;
    return Padding(
      key: const Key('relay-activity'),
      padding: const EdgeInsetsDirectional.fromSTEB(72, 0, 16, 10),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          stats.relayRefused > 0
              ? l.relayActivityRefused(stats.relayedIn, stats.relayRefused)
              : l.relayActivity(stats.relayedIn),
          style: TextStyle(color: context.palette.textMuted, fontSize: 12.5, height: 1.3),
        ),
      ),
    );
  }
}

/// A setting with a fixed set of choices. The dropdown sits under the
/// explanation instead of beside it, so the row holds up on narrow screens and
/// at large system font sizes (a trailing dropdown squeezes the text out).
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.dropdownKey,
    required this.value,
    required this.choices,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Key dropdownKey;
  final T value;
  final Map<T, String> choices;
  final Future<void> Function(T) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: context.palette.textMuted),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(color: context.palette.textMuted, fontSize: 13.5, height: 1.3)),
                DropdownButton<T>(
                  key: dropdownKey,
                  value: value,
                  isExpanded: true,
                  dropdownColor: context.palette.surfaceHigh,
                  underline: const SizedBox.shrink(),
                  onChanged: (v) {
                    if (v != null) onChanged(v);
                  },
                  items: [
                    for (final e in choices.entries)
                      DropdownMenuItem<T>(
                        value: e.key,
                        child: Text(e.value, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows what the phone's Wi-Fi / mobile data are doing, purely so someone
/// testing "does it work offline?" can see that they are off.
class _NetworkRow extends StatefulWidget {
  const _NetworkRow();

  @override
  State<_NetworkRow> createState() => _NetworkRowState();
}

class _NetworkRowState extends State<_NetworkRow> {
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
    final offline = kind == NetworkKind.none;
    return ListTile(
      leading: Icon(offline ? Icons.wifi_off_rounded : Icons.wifi_rounded),
      title: Text(context.l10n.setInternet),
      subtitle: Text(
        kind == null
            ? context.l10n.setChecking
            : context.l10n.setInternetBody(describeNetwork(kind, context.l10n)),
      ),
    );
  }
}
