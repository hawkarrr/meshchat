import 'package:flutter/material.dart';

import '../core/app_info.dart';
import '../core/bidi.dart';
import '../l10n/l10n.dart';
import '../protocol/protocol_constants.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import 'settings_pages.dart';

/// Settings > About: the name and the mark, the version, and the licences of what the
/// app is made with (the bundled font among them).
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SettingsPage(
      title: l.setAboutTitle(AppInfo.name),
      children: [
        const SizedBox(height: AppSpace.l),
        const Center(child: AppLogo(size: 96)),
        const SizedBox(height: AppSpace.l),
        const Text(
          AppInfo.name,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          l.obHeadline,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.palette.textSecondary, fontSize: 14.5, height: 1.4),
        ),
        const SizedBox(height: AppSpace.s),
        Text(
          // The name is its own block, so the version stays after it in this left-to-right line.
          l.setVersionLine(
              '$firstStrongIsolate${AppInfo.name}$isolateEnd', AppInfo.version, Protocol.version),
          key: const Key('about-version'),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.palette.textMuted, fontSize: 12.5),
        ),
        const SizedBox(height: AppSpace.xl),
        Card(
          child: ListTile(
            key: const Key('open-licences'),
            leading: const Icon(Icons.description_outlined),
            title: Text(l.setLicenses),
            subtitle: Text(l.setLicensesBody),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showLicensePage(
              context: context,
              applicationName: AppInfo.name,
              applicationVersion: AppInfo.version,
              applicationLegalese: l.setLicensesLegalese,
            ),
          ),
        ),
      ],
    );
  }
}
