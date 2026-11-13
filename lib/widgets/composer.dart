import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../app_scope.dart';
import '../core/bidi.dart';
import '../core/format.dart';
import '../device/device_io.dart';
import '../protocol/protocol_constants.dart';
import '../services/message_service.dart';
import '../theme/app_theme.dart';
import '../theme/surfaces.dart';
import 'composer_target.dart';
import 'media_views.dart';
import 'permission_prompt.dart';
import 'reveal.dart';
import '../l10n/l10n.dart';

/// What kind of conversation the composer is for.
enum ComposerStyle {
  /// A private chat or a group: pictures, videos, voice messages; a new line on enter.
  chat,

  /// A public room: pictures and voice messages only (a video would have to be carried
  /// by every phone in range); enter sends.
  public,
}

enum _Voice { idle, recording, recorded }

/// What the attach sheet can return.
enum _Attach { photoCamera, photoGallery, videoCamera, videoGallery }

/// The bar at the bottom of a conversation: type, send a picture, record a
/// voice message.
///
/// It owns its own state (text, recording, picture preparation), so typing or
/// recording never rebuilds the message list above it; only the small action
/// button next to the text field reacts to what is typed.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.hint,
    required this.onSendText,
    required this.onSendDraft,
    this.onError,
    this.enabled = true,
    this.disabledHint,
    this.style = ComposerStyle.chat,
    this.docked = true,
    this.target,
  });

  final String hint;

  /// Sends a text message; throws a [MessageError] the composer shows.
  final Future<void> Function(String text) onSendText;

  /// Sends a picture or voice message.
  final Future<void> Function(MediaDraft draft) onSendDraft;

  /// Reports a problem to the screen (shown as a banner).
  final void Function(String message)? onError;
  final bool enabled;
  final String? disabledHint;
  final ComposerStyle style;

  /// The bar sits on a charcoal strip that runs the width of the screen (a chat of its
  /// own). Off, the field floats on the page: the public room among the tabs, above the
  /// bottom bar.
  final bool docked;

  /// A message being answered or edited. The screen sets it (from a message's
  /// menu) and clears it once the message is sent; the composer shows it above the
  /// field, puts the text of an edited message into the field, and clears the
  /// target itself when the person cancels.
  final ValueNotifier<ComposerTarget?>? target;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final TextEditingController _input = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ValueNotifier<int> _bytes = ValueNotifier<int>(0);
  final ValueNotifier<_Voice> _voice = ValueNotifier<_Voice>(_Voice.idle);
  final ValueNotifier<Duration> _elapsed = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<List<double>> _levels = ValueNotifier<List<double>>(const <double>[]);
  final ValueNotifier<bool> _busy = ValueNotifier<bool>(false);

  StreamSubscription<double>? _levelSub;
  StreamSubscription<void>? _limitSub;
  Timer? _clock;
  RecordedVoice? _recorded;

  late final AppController _c;
  static final ValueNotifier<ComposerTarget?> _noTarget = ValueNotifier<ComposerTarget?>(null);
  bool _wasEditing = false;

  ValueNotifier<ComposerTarget?> get _target => widget.target ?? _noTarget;

  @override
  void initState() {
    super.initState();
    // Captured now: the context cannot be asked for it while disposing.
    _c = AppScope.read(context);
    _input.addListener(() {
      final n = utf8.encode(_input.text).length;
      if (n != _bytes.value) _bytes.value = n;
    });
    _target.addListener(_onTargetChanged);
    _wasEditing = _target.value is EditTarget;
  }

  /// An edit puts the old text in the field; leaving the edit takes it out again.
  void _onTargetChanged() {
    final t = _target.value;
    if (t is EditTarget) {
      final text = t.message.body;
      _input.value =
          TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
      _focus.requestFocus();
    } else if (t is ReplyTarget) {
      _focus.requestFocus();
    } else if (_wasEditing) {
      _input.clear();
    }
    _wasEditing = t is EditTarget;
  }

  void _cancelTarget() => _target.value = null;

  @override
  void dispose() {
    _target.removeListener(_onTargetChanged);
    _clock?.cancel();
    _levelSub?.cancel();
    _limitSub?.cancel();
    // Leaving the screen mid-recording throws the recording away.
    if (_voice.value == _Voice.recording) unawaited(_c.io.recorder.cancel());
    _input.dispose();
    _focus.dispose();
    _bytes.dispose();
    _voice.dispose();
    _elapsed.dispose();
    _levels.dispose();
    _busy.dispose();
    super.dispose();
  }

  /// The app's text, for what is said after an await (the controller knows the
  /// language without a [BuildContext]).
  AppLocalizations get _l => _c.l10n;

  void _error(String message) => widget.onError?.call(message);

  // ---- text ------------------------------------------------------------------

  Future<void> _sendText() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    // The field empties at once, as in every messenger: the message is on its
    // way. If it cannot be sent the text comes back, unless the person has
    // already started typing the next one.
    _input.clear();
    unawaited(HapticFeedback.lightImpact());
    try {
      await widget.onSendText(text);
    } on MessageError catch (e) {
      _restore(text);
      _error(e.message);
    } catch (e) {
      _restore(text);
      _error(_l.composerCouldNotSend('$e'));
    }
  }

  void _restore(String text) {
    if (!mounted || _input.text.isNotEmpty) return;
    _input.value =
        TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }

  // ---- pictures ----------------------------------------------------------------

  /// Whether this conversation can carry a video: private chats and groups can,
  /// a public room cannot (every phone in range would have to carry it).
  bool get _allowsVideo => widget.style != ComposerStyle.public;

  Future<void> _attach() async {
    final limit = _c.videoSendLimit;
    final choice = await showAppSheet<_Attach>(
      context: context,
      builder: (context) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(context.l10n.attachSendPicture,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            _SheetOption(
              key: const Key('attach-camera'),
              icon: Icons.photo_camera_rounded,
              label: context.l10n.attachTakePhoto,
              onTap: () => Navigator.pop(context, _Attach.photoCamera),
            ),
            _SheetOption(
              key: const Key('attach-gallery'),
              icon: Icons.photo_library_rounded,
              label: context.l10n.attachChoosePhoto,
              onTap: () => Navigator.pop(context, _Attach.photoGallery),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.attachPictureNote,
              style: TextStyle(color: context.palette.textMuted, fontSize: 12.5, height: 1.4),
            ),
            if (_allowsVideo) ...[
              const Divider(height: 24),
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(context.l10n.attachSendVideo,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              _SheetOption(
                key: const Key('attach-video-camera'),
                icon: Icons.videocam_rounded,
                label: context.l10n.attachRecordVideo,
                onTap: () => Navigator.pop(context, _Attach.videoCamera),
              ),
              _SheetOption(
                key: const Key('attach-video-gallery'),
                icon: Icons.video_library_rounded,
                label: context.l10n.attachChooseVideo,
                onTap: () => Navigator.pop(context, _Attach.videoGallery),
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.attachVideoNote(formatBytes(limit)),
                style: TextStyle(color: context.palette.textMuted, fontSize: 12.5, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case _Attach.photoCamera:
        await _pickPhoto(PhotoSource.camera);
      case _Attach.photoGallery:
        await _pickPhoto(PhotoSource.gallery);
      case _Attach.videoCamera:
        await _pickVideo(PhotoSource.camera);
      case _Attach.videoGallery:
        await _pickVideo(PhotoSource.gallery);
    }
  }

  Future<void> _pickPhoto(PhotoSource source) async {
    final permission =
        source == PhotoSource.camera ? AppPermission.camera : AppPermission.photos;
    if (!await ensurePermission(context, permission)) {
      if (mounted) _error(_l.composerAllowPicture);
      return;
    }
    if (!mounted) return;
    final c = _c;
    final Uint8List? raw;
    try {
      raw = await c.io.photos.pick(source);
    } catch (e) {
      _error(source == PhotoSource.camera
          ? _l.composerOpenCameraFailed('$e')
          : _l.composerOpenPhotosFailed('$e'));
      return;
    }
    if (raw == null || !mounted) return;
    _busy.value = true;
    final MediaDraft draft;
    try {
      draft = await c.prepareImage(raw);
    } on ImageCompressionException catch (e) {
      _busy.value = false;
      _error(e.text(_l));
      return;
    } catch (e) {
      _busy.value = false;
      _error(_l.composerPictureNotPrepared('$e'));
      return;
    }
    _busy.value = false;
    if (!mounted) return;
    final withCaption = await _previewPicture(draft);
    if (withCaption == null) return;
    await _sendDraft(withCaption);
  }

  Future<void> _pickVideo(PhotoSource source) async {
    final permission =
        source == PhotoSource.camera ? AppPermission.camera : AppPermission.photos;
    if (!await ensurePermission(context, permission)) {
      if (mounted) _error(_l.composerAllowVideo);
      return;
    }
    if (!mounted) return;
    final c = _c;
    final limit = c.videoSendLimit;
    final PickedVideo? picked;
    try {
      picked = await c.io.photos.pickVideo(source, maxBytes: limit);
    } catch (e) {
      _error(source == PhotoSource.camera
          ? _l.composerOpenCameraFailed('$e')
          : _l.composerOpenVideosFailed('$e'));
      return;
    }
    if (picked == null || !mounted) return;
    if (picked.tooLarge) {
      _error(_l.composerVideoTooBig(formatBytes(picked.length), formatBytes(limit), formatBytes(AppController.videoLimitChoices.last)));
      return;
    }
    final MediaDraft draft;
    try {
      draft = c.videoDraft(picked);
    } on MessageError catch (e) {
      _error(e.message);
      return;
    }
    final withCaption = await showDialog<MediaDraft>(
      context: context,
      barrierColor: context.palette.scrim,
      builder: (context) => _VideoPreview(draft: draft),
    );
    if (withCaption == null) return;
    await _sendDraft(withCaption);
  }

  Future<MediaDraft?> _previewPicture(MediaDraft draft) {
    return showDialog<MediaDraft>(
      context: context,
      barrierColor: context.palette.scrim,
      builder: (context) => _PicturePreview(draft: draft),
    );
  }

  Future<void> _sendDraft(MediaDraft draft) async {
    try {
      await widget.onSendDraft(draft);
      unawaited(HapticFeedback.lightImpact());
    } on MessageError catch (e) {
      _error(e.message);
    } catch (e) {
      _error(_l.composerCouldNotSend('$e'));
    }
  }

  // ---- voice -------------------------------------------------------------------

  Future<void> _startRecording() async {
    if (!await ensurePermission(context, AppPermission.microphone)) {
      if (mounted) _error(_l.composerAllowMic);
      return;
    }
    if (!mounted) return;
    final recorder = _c.io.recorder;
    try {
      await recorder.start();
    } on VoiceException catch (e) {
      _error(e.text(_l));
      return;
    } catch (e) {
      _error(_l.composerRecordFailed('$e'));
      return;
    }
    _levels.value = const <double>[];
    _elapsed.value = Duration.zero;
    _voice.value = _Voice.recording;
    _levelSub = recorder.levels.listen((l) {
      final next = [..._levels.value, l];
      _levels.value = next.length > _meterBars ? next.sublist(next.length - _meterBars) : next;
    });
    _limitSub = recorder.limitReached.listen((_) => unawaited(_finishAtLimit()));
    _clock = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _elapsed.value = recorder.elapsed;
    });
    unawaited(HapticFeedback.mediumImpact());
  }

  Future<void> _endClockAndStreams() async {
    _clock?.cancel();
    await _levelSub?.cancel();
    await _limitSub?.cancel();
    _levelSub = null;
    _limitSub = null;
  }

  Future<void> _finishAtLimit() async {
    await _endClockAndStreams();
    final v = await _c.io.recorder.stop();
    if (!mounted) return;
    if (v == null) {
      _voice.value = _Voice.idle;
      return;
    }
    _recorded = v;
    _elapsed.value = v.duration;
    _voice.value = _Voice.recorded;
  }

  Future<void> _cancelVoice() async {
    await _endClockAndStreams();
    if (_voice.value == _Voice.recording) await _c.io.recorder.cancel();
    _recorded = null;
    if (mounted) _voice.value = _Voice.idle;
  }

  Future<void> _sendVoice() async {
    await _endClockAndStreams();
    RecordedVoice? v = _recorded;
    if (_voice.value == _Voice.recording) v = await _c.io.recorder.stop();
    _recorded = null;
    if (!mounted) return;
    _voice.value = _Voice.idle;
    if (v == null) {
      _error(_l.composerVoiceTooShort);
      return;
    }
    await _sendDraft(_c.voiceDraft(v));
  }

  // ---- layout ------------------------------------------------------------------

  static const int _meterBars = 40;

  /// The level meter: always [_meterBars] bars, the newest on the right, so the
  /// bars do not change width as the recording gets longer.
  static List<int> _meter(List<double> levels) {
    final shown = levels.length > _meterBars ? levels.sublist(levels.length - _meterBars) : levels;
    return [
      for (var i = shown.length; i < _meterBars; i++) 0,
      for (final l in shown) (l * 255).round(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final public = widget.style == ComposerStyle.public;
    final bar = Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.s, 6, AppSpace.s, 6),
      child: ValueListenableBuilder<_Voice>(
        valueListenable: _voice,
        builder: (context, voice, _) {
          if (voice != _Voice.idle) return _recordingBar(voice);
          return ValueListenableBuilder<ComposerTarget?>(
            valueListenable: _target,
            builder: (context, target, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Reveal(
                  show: target != null,
                  child: target == null
                      ? const SizedBox.shrink()
                      : ComposerBanner(target: target, onCancel: _cancelTarget),
                ),
                _row(public: public),
              ],
            ),
          );
        },
      ),
    );
    return widget.docked
        ? Material(color: context.palette.surface, child: SafeArea(top: false, child: bar))
        : SafeArea(top: false, child: bar);
  }

  Widget _textField({required bool public}) {
    return ValueListenableBuilder<int>(
      valueListenable: _bytes,
      builder: (context, bytes, _) => TextField(
        key: const Key('composer-field'),
        controller: _input,
        focusNode: _focus,
        enabled: widget.enabled,
        // The field reads in the direction of what is typed, as a message does once it is
        // sent: English typed in a Kurdish app keeps its punctuation at its end, Kurdish
        // typed in an English app reads right to left. Empty, it follows the app.
        textDirection: textDirectionOf(_input.text),
        minLines: 1,
        maxLines: 5,
        textCapitalization: TextCapitalization.sentences,
        keyboardType: public ? TextInputType.text : TextInputType.multiline,
        textInputAction: public ? TextInputAction.send : TextInputAction.newline,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          hintText: widget.enabled ? widget.hint : (widget.disabledHint ?? widget.hint),
          hintMaxLines: 1,
          hintStyle: TextStyle(color: context.palette.textMuted, fontSize: 15),
          helperText: bytes > Protocol.maxTextBytes * 0.8 ? context.l10n.composerBytesCounter(bytes, Protocol.maxTextBytes) : null,
          errorText: bytes > Protocol.maxTextBytes ? context.l10n.composerTooLong : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        ),
        onSubmitted: public ? (_) => _sendText() : null,
      ),
    );
  }

  Widget _row({required bool public}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: _busy,
          builder: (context, busy, _) => busy
              ? const SizedBox(
                  width: AppSizes.tap,
                  height: AppSizes.tap,
                  child: Padding(
                    padding: EdgeInsets.all(11),
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              : RoundButton(
                  key: const Key('composer-attach'),
                  icon: Icons.attach_file_rounded,
                  tooltip: context.l10n.attachSendPicture,
                  flat: true,
                  color: context.palette.textSecondary,
                  onPressed: widget.enabled && _target.value is! EditTarget ? _attach : null,
                ),
        ),
        const SizedBox(width: 4),
        Expanded(child: _textField(public: public)),
        const SizedBox(width: 8),
        _actionButton(),
      ],
    );
  }

  /// Send when there is text, microphone otherwise.
  Widget _actionButton({double size = AppSizes.button}) {
    return ValueListenableBuilder<int>(
      valueListenable: _bytes,
      builder: (context, bytes, _) {
        final hasText = _input.text.trim().isNotEmpty;
        final editing = _target.value is EditTarget;
        if (hasText || editing) {
          return RoundButton(
            key: const Key('composer-send'),
            icon: editing ? Icons.check_rounded : Icons.arrow_upward_rounded,
            tooltip: editing ? context.l10n.composerSaveChanges : context.l10n.commonSend,
            filled: true,
            size: size,
            onPressed:
                widget.enabled && hasText && bytes <= Protocol.maxTextBytes ? _sendText : null,
          );
        }
        return RoundButton(
          key: const Key('composer-mic'),
          icon: Icons.mic_rounded,
          tooltip: context.l10n.composerRecord,
          filled: true,
          size: size,
          onPressed: widget.enabled ? _startRecording : null,
        );
      },
    );
  }

  Widget _recordingBar(_Voice voice) {
    final recording = voice == _Voice.recording;
    return AppPanel(
      radius: 26,
      raised: true,
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      child: Row(
        children: [
          RoundButton(
            key: const Key('voice-cancel'),
            icon: Icons.delete_outline_rounded,
            tooltip: context.l10n.composerDiscard,
            color: context.palette.danger,
            size: 44,
            onPressed: _cancelVoice,
          ),
          const SizedBox(width: 10),
          if (recording)
            const _PulsingDot()
          else
            Icon(Icons.mic_rounded, color: context.palette.accentSoft, size: 18),
          const SizedBox(width: 8),
          ValueListenableBuilder<Duration>(
            valueListenable: _elapsed,
            builder: (context, d, _) => Text(
              formatDuration(d),
              key: const Key('voice-timer'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ValueListenableBuilder<List<double>>(
              valueListenable: _levels,
              builder: (context, levels, _) => WaveformBars(
                samples: recording ? _meter(levels) : (_recorded?.waveform ?? const <int>[]),
                progress: 1,
                height: 26,
                active: context.palette.accentSoft,
                barCount: _meterBars,
              ),
            ),
          ),
          const SizedBox(width: 10),
          RoundButton(
            key: const Key('voice-send'),
            icon: Icons.arrow_upward_rounded,
            tooltip: context.l10n.composerSendVoice,
            filled: true,
            size: 44,
            onPressed: _sendVoice,
          ),
        ],
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: context.palette.accent, shape: BoxShape.circle),
        child: Icon(icon, color: context.palette.onAccent, size: 22),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

/// A red dot that breathes while recording.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Tests (and people who turned animations off) get a still dot.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_controller),
      child: Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(color: context.palette.danger, shape: BoxShape.circle),
      ),
    );
  }
}

/// "Send this picture?": the shrunk picture, its size, and a caption field.
class _PicturePreview extends StatefulWidget {
  const _PicturePreview({required this.draft});

  final MediaDraft draft;

  @override
  State<_PicturePreview> createState() => _PicturePreviewState();
}

class _PicturePreviewState extends State<_PicturePreview> {
  final TextEditingController _caption = TextEditingController();

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return AppDialogFrame(
      title: context.l10n.previewSendPicture,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: Image.memory(draft.bytes, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${formatBytes(draft.bytes.length)} · ${draft.width}×${draft.height}',
            style: TextStyle(color: context.palette.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('caption-field'),
            controller: _caption,
            maxLength: 80,
            decoration: InputDecoration(hintText: context.l10n.previewCaptionHint, counterText: ''),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.commonCancel)),
        FilledButton(
          key: const Key('picture-send'),
          onPressed: () => Navigator.pop(
            context,
            MediaDraft(
              kind: draft.kind,
              bytes: draft.bytes,
              width: draft.width,
              height: draft.height,
              caption: _caption.text,
            ),
          ),
          child: Text(context.l10n.commonSend),
        ),
      ],
    );
  }
}
/// "Send this video?": its size, an honest word about how long it takes, and a
/// caption field. There is no frame to show: the card says what will happen.
class _VideoPreview extends StatefulWidget {
  const _VideoPreview({required this.draft});

  final MediaDraft draft;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  final TextEditingController _caption = TextEditingController();

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return AppDialogFrame(
      title: context.l10n.previewSendVideo,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.videocam_rounded, size: 40, color: context.palette.accentSoft),
              const SizedBox(width: 12),
              Expanded(
                child: Text(formatBytes(draft.bytes.length),
                    key: const Key('video-size'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            context.l10n.previewVideoNote,
            style: TextStyle(color: context.palette.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('caption-field'),
            controller: _caption,
            maxLength: 80,
            decoration: InputDecoration(hintText: context.l10n.previewCaptionHint, counterText: ''),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.commonCancel)),
        FilledButton(
          key: const Key('video-send'),
          onPressed: () => Navigator.pop(context, draft.copyWith(caption: _caption.text)),
          child: Text(context.l10n.commonSend),
        ),
      ],
    );
  }
}
