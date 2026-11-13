import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../device/device_io.dart';
import '../l10n/l10n.dart';
import '../theme/surfaces.dart';

class _Copy {
  const _Copy(this.title, this.why, this.privacy, this.icon, this.thing, this.offTitle);

  final String title;
  final String why;
  final String privacy;
  final IconData icon;

  /// How the permission is named inside a sentence ("... to use [thing].").
  final String thing;

  /// The title of the dialog that points to the settings.
  final String offTitle;
}

/// What each permission is for, in the words of the language being shown.
_Copy _copyFor(AppLocalizations l, AppPermission permission) => switch (permission) {
      AppPermission.microphone => _Copy(l.permMicTitle, l.permMicWhy, l.permMicPrivacy,
          Icons.mic_rounded, l.permMicThing, l.permMicOff),
      AppPermission.camera => _Copy(l.permCameraTitle, l.permCameraWhy, l.permCameraPrivacy,
          Icons.photo_camera_rounded, l.permCameraThing, l.permCameraOff),
      AppPermission.photos => _Copy(l.permPhotosTitle, l.permPhotosWhy, l.permPhotosPrivacy,
          Icons.photo_library_rounded, l.permPhotosThing, l.permPhotosOff),
      AppPermission.notifications => _Copy(l.permNotifTitle, l.permNotifWhy, l.permNotifPrivacy,
          Icons.notifications_rounded, l.permNotifThing, l.permNotifOff),
    };

/// Makes sure Damatqe may use [permission]. Never springs the system dialog
/// on the person: it first says, in plain words, what the permission is for
/// and what happens to the data; only if they agree does it ask the system. If
/// the permission was switched off for good, it offers to open the settings
/// instead. Returns whether the permission is granted now.
Future<bool> ensurePermission(BuildContext context, AppPermission permission) async {
  final io = AppScope.read(context).io;
  final l = context.l10n;
  final copy = _copyFor(l, permission);
  var status = await io.permissions.status(permission);
  if (status == PermissionOutcome.granted) return true;
  if (!context.mounted) return false;

  if (status == PermissionOutcome.unavailable) {
    await showAppDialog<void>(
      context: context,
      title: l.permNotAvailable,
      message: l.permUnavailableBody(copy.thing),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(context), child: Text(l.commonOk)),
      ],
    );
    return false;
  }

  if (status == PermissionOutcome.denied) {
    final agreed = await showAppDialog<bool>(
      context: context,
      title: copy.title,
      message: '${copy.why}\n\n${copy.privacy}',
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.permNotNow)),
        FilledButton(
          key: const Key('permission-continue'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.commonContinue),
        ),
      ],
    );
    if (agreed != true) return false;
    // Whatever the person answers to the system's own dialog is respected: no
    // second dialog right after they said no.
    return await io.permissions.request(permission) == PermissionOutcome.granted;
  }

  // Switched off for good earlier: only the settings can turn it on.
  final open = await showAppDialog<bool>(
    context: context,
    title: copy.offTitle,
    message: l.permTurnOnInSettings,
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.commonCancel)),
      FilledButton(
        key: const Key('permission-open-settings'),
        onPressed: () => Navigator.pop(context, true),
        child: Text(l.commonOpenSettings),
      ),
    ],
  );
  if (open == true) await io.permissions.openSettings();
  return false;
}
