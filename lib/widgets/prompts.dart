import 'package:flutter/material.dart';

import '../services/message_service.dart' show MessageError;
import '../theme/app_theme.dart';
import '../theme/surfaces.dart';
import '../l10n/l10n.dart';

/// Asks for one line of text. Returns it, or null if the person cancelled.
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  String? message,
  String? hint,
  String initial = '',
  int maxLength = 32,
  String? confirmLabel,
  Key? fieldKey,
  Key? confirmKey,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: context.palette.scrim,
    builder: (context) => _TextPrompt(
      title: title,
      message: message,
      hint: hint,
      initial: initial,
      maxLength: maxLength,
      confirmLabel: confirmLabel,
      fieldKey: fieldKey,
      confirmKey: confirmKey,
    ),
  );
}

class _TextPrompt extends StatefulWidget {
  const _TextPrompt({
    required this.title,
    this.message,
    this.hint,
    required this.initial,
    required this.maxLength,
    required this.confirmLabel,
    this.fieldKey,
    this.confirmKey,
  });

  final String title;
  final String? message;
  final String? hint;
  final String initial;
  final int maxLength;
  final String? confirmLabel;
  final Key? fieldKey;
  final Key? confirmKey;

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogFrame(
      title: widget.title,
      message: widget.message,
      content: TextField(
        key: widget.fieldKey,
        controller: _controller,
        autofocus: true,
        maxLength: widget.maxLength,
        decoration: InputDecoration(hintText: widget.hint, counterText: ''),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.commonCancel)),
        FilledButton(
          key: widget.confirmKey,
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(widget.confirmLabel ?? context.l10n.commonSave),
        ),
      ],
    );
  }
}

/// A destructive confirmation, optionally asking the person to type a word
/// before the button works. Returns whether they confirmed.
Future<bool> showDangerConfirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  String? typeToConfirm,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: context.palette.scrim,
    builder: (context) => _DangerConfirm(
      title: title,
      body: body,
      action: action,
      typeToConfirm: typeToConfirm,
    ),
  );
  return ok ?? false;
}

class _DangerConfirm extends StatefulWidget {
  const _DangerConfirm({
    required this.title,
    required this.body,
    required this.action,
    this.typeToConfirm,
  });

  final String title;
  final String body;
  final String action;
  final String? typeToConfirm;

  @override
  State<_DangerConfirm> createState() => _DangerConfirmState();
}

class _DangerConfirmState extends State<_DangerConfirm> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final word = widget.typeToConfirm;
    final allowed = word == null || _controller.text.trim().toLowerCase() == word.toLowerCase();
    return AppDialogFrame(
      title: widget.title,
      message: widget.body,
      content: word == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.promptTypeToConfirm(word),
                    style: TextStyle(color: context.palette.textMuted, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('confirm-text'),
                  controller: _controller,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.commonCancel)),
        FilledButton(
          key: const Key('confirm-action'),
          style: dangerButtonStyle(context),
          onPressed: allowed ? () => Navigator.pop(context, true) : null,
          child: Text(widget.action),
        ),
      ],
    );
  }
}

/// Asks "are you sure?" and, if the person is, runs [run]; what a [MessageError] says
/// goes into a snack bar. For the actions of a list row: delete a chat, leave a room.
Future<void> confirmAndRun(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  required Future<void> Function() run,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await showAppDialog<bool>(
    context: context,
    title: title,
    message: message,
    actions: [
      TextButton(
          onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.commonCancel)),
      Builder(
        builder: (context) => FilledButton(
          key: const Key('confirm-action'),
          style: dangerButtonStyle(context),
          onPressed: () => Navigator.pop(context, true),
          child: Text(action),
        ),
      ),
    ],
  );
  if (ok != true) return;
  try {
    await run();
  } on MessageError catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}
