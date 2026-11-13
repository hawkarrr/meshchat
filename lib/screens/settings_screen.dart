import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../core/app_info.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../theme/surfaces.dart';
import '../widgets/peer_avatar.dart';
import 'about_screen.dart';
import 'appearance_page.dart';
import 'help_screen.dart';
import 'settings_pages.dart';

/// The Settings place of the home screen: a short menu, as in Telegram's, whose rows
/// each open a page of one subject - the profile at the top, then language,
/// notifications, privacy and security, chats and Bluetooth, help, and what the app
/// is. Everything the app can be set to is on one of those pages; the menu itself
/// holds no explanations.
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final l = context.l10n;
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpace.m, AppSpace.m, AppSpace.m, AppSpace.xl),
      children: [
        _ProfileRow(onTap: () => _open(context, const ProfilePage())),
        const SizedBox(height: AppSpace.l),
        _Group(children: [
          _Row(
            key: const Key('settings-language'),
            icon: Icons.translate_rounded,
            tone: context.palette.accent,
            title: l.setLanguage,
            // The language's own name, in its own writing direction.
            value: Directionality(
              textDirection: c.language.direction,
              child: Text(c.language.nativeName,
                  style: TextStyle(color: context.palette.textMuted, fontSize: 14.5)),
            ),
            onTap: () => _open(context, const LanguagePage()),
          ),
          _Row(
            key: const Key('settings-appearance'),
            icon: Icons.palette_rounded,
            tone: context.palette.accentSoft,
            title: l.setAppearance,
            // The current choice, in words; only this listens to the theme.
            value: ListenableBuilder(
              listenable: c.theme,
              builder: (context, _) => Text(
                switch (c.theme.mode) {
                  ThemeMode.system => l.appearanceSystem,
                  ThemeMode.light => l.appearanceLight,
                  ThemeMode.dark => l.appearanceDark,
                },
                style: TextStyle(color: context.palette.textMuted, fontSize: 14.5),
              ),
            ),
            onTap: () => _open(context, const AppearancePage()),
          ),
          _Row(
            key: const Key('settings-notifications'),
            icon: Icons.notifications_rounded,
            tone: context.palette.pending,
            title: l.setNotifications,
            onTap: () => _open(context, const NotificationsPage()),
          ),
          _Row(
            key: const Key('settings-privacy'),
            icon: Icons.lock_rounded,
            tone: context.palette.direct,
            title: l.setPrivacy,
            onTap: () => _open(context, const PrivacyPage()),
          ),
          _Row(
            key: const Key('settings-chat'),
            icon: Icons.bluetooth_rounded,
            tone: context.palette.accent,
            title: l.setChatsBluetooth,
            onTap: () => _open(context, const ChatSettingsPage()),
          ),
        ]),
        const SizedBox(height: AppSpace.l),
        _Group(children: [
          _Row(
            key: const Key('settings-help'),
            icon: Icons.help_outline_rounded,
            tone: context.palette.accentSoft,
            title: l.setHelp,
            onTap: () => _open(context, const HelpScreen()),
          ),
          _Row(
            key: const Key('settings-about'),
            icon: Icons.info_outline_rounded,
            tone: context.palette.textSecondary,
            title: l.setAboutTitle(AppInfo.name),
            onTap: () => _open(context, const AboutScreen()),
          ),
        ]),
      ],
    );
  }
}

/// The person at the top of the menu: picture, name and short id. It opens the profile.
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return AppPanel(
      child: InkWell(
        key: const Key('settings-profile'),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Row(
            children: [
              PeerAvatar(name: c.nickname, seed: c.identityId, size: 60),
              const SizedBox(width: AppSpace.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('#${c.identityId.substring(0, 8)}',
                        textDirection: TextDirection.ltr,
                        style: monoStyle(color: context.palette.textMuted, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: context.palette.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// A block of rows on one charcoal panel, with a hairline between them.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: 64, endIndent: 0),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One row of the menu: a tinted square with the icon, the title, and (for some) the
/// current value, then the arrow.
class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.icon,
    required this.tone,
    required this.title,
    required this.onTap,
    this.value,
  });

  final IconData icon;
  final Color tone;
  final String title;
  final Widget? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // With large system text the value goes under the title: side by side they would not fit.
    final stacked = value != null && MediaQuery.textScalerOf(context).scale(16) / 16 > 1.25;
    final titleText =
        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16));
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.l, vertical: AppSpace.s),
          child: Row(
            children: [
              AppPanel(
                radius: 10,
                tint: tone,
                width: 36,
                height: 36,
                child: Icon(icon, color: tone, size: 20),
              ),
              const SizedBox(width: AppSpace.l),
              Expanded(
                child: stacked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [titleText, value!],
                      )
                    : titleText,
              ),
              if (value != null && !stacked) ...[const SizedBox(width: AppSpace.s), value!],
              const SizedBox(width: AppSpace.xs),
              Icon(Icons.chevron_right_rounded, color: context.palette.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
