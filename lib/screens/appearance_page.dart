import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../theme/surfaces.dart';
import '../theme/theme_host.dart';
import '../widgets/theme_toggle.dart';
import 'settings_pages.dart';

/// How the app looks: light, dark, or whatever the phone is set to. The choice applies at
/// once, with the new look spreading out in a circle from the row that was tapped, and is
/// remembered.
class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final themes = AppScope.read(context).theme;
    final options = <(ThemeMode, IconData, String, String)>[
      (ThemeMode.system, Icons.brightness_auto_rounded, l.appearanceSystem, l.appearanceSystemHelp),
      (ThemeMode.light, Icons.light_mode_rounded, l.appearanceLight, l.appearanceLightHelp),
      (ThemeMode.dark, Icons.dark_mode_rounded, l.appearanceDark, l.appearanceDarkHelp),
    ];
    return SettingsPage(
      title: l.setAppearance,
      children: [
        SettingsHeading(l.appearanceHeading),
        Card(
          // Only the ticks listen: the page itself is rebuilt by the reveal, not by the choice.
          child: ListenableBuilder(
            listenable: themes,
            builder: (context, _) => Column(
              children: [
                for (var i = 0; i < options.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 64),
                  // One switcher for each row, so the reveal starts at the row that was tapped.
                  ThemeSwitcher.switcher(
                    clipper: const EasedCircleClipper(),
                    builder: (context, switcher) => _ModeTile(
                      key: Key('appearance-${options[i].$1.name}'),
                      icon: options[i].$2,
                      title: options[i].$3,
                      help: options[i].$4,
                      selected: themes.mode == options[i].$1,
                      onTap: () => switchThemeMode(context, switcher, options[i].$1),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One choice: an icon, its name and what it does, and a tick when it is the chosen one.
class _ModeTile extends StatelessWidget {
  const _ModeTile({
    super.key,
    required this.icon,
    required this.title,
    required this.help,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String help;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      excludeSemantics: true,
      label: '$title. $help',
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.l, vertical: AppSpace.s),
            child: Row(
              children: [
                AppPanel(
                  radius: 10,
                  tint: p.accent,
                  width: 36,
                  height: 36,
                  child: Icon(icon, color: p.accentSoft, size: 20),
                ),
                const SizedBox(width: AppSpace.l),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(help,
                          style: TextStyle(color: p.textMuted, fontSize: 13.5, height: 1.3)),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.s),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  key: Key(selected ? 'appearance-selected' : 'appearance-unselected'),
                  color: selected ? p.accent : p.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
