import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../protocol/protocol_constants.dart';
import '../theme/app_theme.dart';
import 'settings_pages.dart';

/// Settings > Help and instructions: what the app does and, as plainly, what it cannot.
/// This is where the explanations live that used to sit in the chats and on the first
/// page - each one a line that opens.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static List<(String, String)> _items(AppLocalizations l) => [
        (l.honestyNoInternetTitle, l.honestyNoInternetBody),
        (
          l.honestyRangeTitle,
          l.honestyRangeBody(
            Protocol.directHopLimit,
            Protocol.groupHopLimit,
            Protocol.directMessageTtl.inHours,
            Protocol.roomMessageTtl.inHours,
          ),
        ),
        (l.honestyMediaTitle, l.honestyMediaBody(Protocol.maxVoiceDuration.inSeconds)),
        (l.helpPermissionsTitle, l.helpPermissionsBody),
        (l.honestyBackgroundTitle, l.honestyBackgroundBody),
        (l.honestyPrivateTitle, l.honestyPrivateBody),
        (l.honestyGroupsTitle, l.honestyGroupsBody),
        (l.honestyRoomsTitle, l.honestyRoomsBody),
        (l.honestyDeleteTitle, l.honestyDeleteBody),
        (l.honestyVerifyTitle, l.honestyVerifyBody),
        (l.honestyStoredTitle, l.honestyStoredBody),
        (l.honestyAuditTitle, l.honestyAuditBody),
      ];

  @override
  Widget build(BuildContext context) {
    final items = _items(context.l10n);
    return SettingsPage(
      title: context.l10n.setHelp,
      children: [
        SettingsHeading(context.l10n.setHonesty),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(),
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    expandedAlignment: AlignmentDirectional.centerStart,
                    title: Text(items[i].$1,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                    children: [
                      Text(items[i].$2,
                          style: TextStyle(
                              color: context.palette.textMuted, fontSize: 13.5, height: 1.45)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
