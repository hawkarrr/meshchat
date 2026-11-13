import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/surfaces.dart';

/// A line above the composer that says what went wrong with the last thing the person
/// tried (a message that could not be sent, a permission that is off), with a close
/// button. It is an announcement for screen readers too.
class ErrorStrip extends StatelessWidget {
  const ErrorStrip({super.key, required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.m, 4, AppSpace.m, 0),
      child: Semantics(
        liveRegion: true,
        child: AppPanel(
          radius: AppRadii.md,
          tint: context.palette.danger,
          padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 4, 4),
          child: Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 18, color: context.palette.danger),
              const SizedBox(width: AppSpace.s),
              Expanded(child: Text(message, style: const TextStyle(fontSize: 13, height: 1.3))),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
