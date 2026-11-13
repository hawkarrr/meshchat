import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../core/app_info.dart';
import '../theme/app_theme.dart';
import '../theme/surfaces.dart';
import '../widgets/app_logo.dart';
import '../l10n/l10n.dart';
import '../core/byte_limit.dart';
import '../widgets/language_picker.dart';
import '../widgets/theme_toggle.dart';

/// Shown once, before anything touches Bluetooth. It says what the app does,
/// which permissions it will ask for and when, and what it cannot do, so that
/// the system permission dialogs that follow are not a surprise.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final TextEditingController _name;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: AppScope.read(context).nickname);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final c = AppScope.read(context);
    setState(() => _busy = true);
    try {
      if (_name.text.trim() != c.nickname) await c.setNickname(_name.text);
      // Ask while this page, which explains why, is still on screen; the home
      // screen replaces it only once onboarding is marked done.
      await c.requestPermissions();
    } catch (_) {
      // Whatever went wrong, the home screen's banner explains it and offers
      // the fix; the user must not be stuck here.
    }
    try {
      await c.completeOnboarding();
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                    children: [
                      // First of all, the language: a person who cannot read the
                      // rest of the page can still find theirs here. Beside it, the
                      // switch between the light and the dark appearance (a picture
                      // of a sun or a moon needs no words).
                      const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: LanguagePicker()),
                          SizedBox(width: AppSpace.s),
                          ThemeToggleButton(),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Center(child: AppLogo(size: 92)),
                      const SizedBox(height: 18),
                      // No letter-spacing: it would pull the joined letters of the name apart.
                      Text(AppInfo.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: context.palette.accentSoft)),
                      const SizedBox(height: 6),
                      Text(context.l10n.obHeadline,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.25)),
                      const SizedBox(height: 22),
                      _Point(
                        Icons.phonelink_rounded,
                        context.l10n.obPoint1Title,
                        context.l10n.obPoint1Body,
                      ),
                      _Point(
                        Icons.groups_rounded,
                        context.l10n.obPoint3Title,
                        context.l10n.obPoint3Body,
                      ),
                      _Point(
                        Icons.lock_outline_rounded,
                        context.l10n.obPoint4Title,
                        context.l10n.obPoint4Body,
                      ),
                      _Point(
                        Icons.info_outline_rounded,
                        context.l10n.obPoint5Title,
                        context.l10n.obPoint5Body,
                        accent: context.palette.pending,
                      ),
                      const SizedBox(height: 10),
                      Text(context.l10n.setName,
                          style: TextStyle(color: context.palette.textMuted, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        key: const Key('onboarding-name'),
                        controller: _name,
                        inputFormatters: const [ByteLimitFormatter(32)],
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: context.l10n.obNameHint,
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.obNameNote,
                        style: TextStyle(color: context.palette.textMuted, fontSize: 12.5, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('onboarding-start'),
                    onPressed: _busy ? null : _start,
                    icon: _busy
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: context.palette.onAccent),
                          )
                        : const Icon(Icons.bluetooth_rounded),
                    label: Text(_busy ? context.l10n.obStarting : context.l10n.obStart),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point(this.icon, this.title, this.text, {this.accent});

  final IconData icon;
  final String title;
  final String text;

  /// The colour of the icon; the soft blue of the theme unless given.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? context.palette.accentSoft;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppPanel(
            radius: 14,
            tint: color,
            width: 42,
            height: 42,
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                const SizedBox(height: 3),
                Text(text,
                    style: TextStyle(
                        color: context.palette.textSecondary, fontSize: 13.5, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
