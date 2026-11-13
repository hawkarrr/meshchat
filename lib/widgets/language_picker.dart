import 'dart:async';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// Chooses the language of the app: each language is named in itself, so a person
/// who cannot read the current one can still find theirs. The choice applies at
/// once, to every screen, and is remembered.
///
/// The names are chips that wrap onto a second line when there is no room (a
/// narrow screen, large system text); a segmented bar would run out of its box.
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key});

  Future<void> _choose(BuildContext context, AppLanguage language) async {
    final c = AppScope.read(context);
    if (c.language == language) return;
    await c.setLanguage(language);
    // The words above this picker change length with the language, so the page
    // below would shift under the person's finger: keep the picker where it was.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted || Scrollable.maybeOf(context) == null) return;
      unawaited(Scrollable.ensureVisible(context, alignment: 0.4));
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = AppScope.of(context).language;
    return Wrap(
      key: const Key('language-picker'),
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final language in AppLanguage.values)
          ChoiceChip(
            key: Key('language-${language.code}'),
            // The language's own name, in its own writing direction.
            label: Directionality(
              textDirection: language.direction,
              child: Text(language.nativeName, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            selected: current == language,
            showCheckmark: false,
            avatar: current == language
                ? Icon(Icons.check_rounded, size: 18, color: context.palette.accentSoft)
                : null,
            selectedColor: context.palette.accent.withValues(alpha: 0.3),
            materialTapTargetSize: MaterialTapTargetSize.padded,
            onSelected: (_) => _choose(context, language),
          ),
      ],
    );
  }
}
