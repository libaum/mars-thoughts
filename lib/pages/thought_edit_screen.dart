import 'package:flutter/material.dart';
import 'package:mars_thoughts/data/local_storage_service.dart';
import 'package:mars_thoughts/domain/thought.dart';
import 'package:mars_thoughts/logic/thoughts_manager.dart';
import 'package:mars_thoughts/services/service_locator.dart';
import 'package:mars_thoughts/theme/theme_constants.dart';

/// Opens a thought in read mode: the text is shown plainly and is selectable,
/// so you can read it — or select and copy — without the keyboard popping up.
/// Double-tap the text to start editing. Auto-saves on leave (back gesture or
/// backgrounding the app). Emptying the text moves the thought to the trash.
class ThoughtEditScreen extends StatefulWidget {
  final Thought thought;
  const ThoughtEditScreen({super.key, required this.thought});

  @override
  State<ThoughtEditScreen> createState() => _ThoughtEditScreenState();
}

class _ThoughtEditScreenState extends State<ThoughtEditScreen>
    with WidgetsBindingObserver {
  final _manager = getIt<ThoughtsManager>();
  final _storage = getIt<LocalStorageService>();
  late final TextEditingController _controller;
  final _focus = FocusNode();

  // Reader scroll + a key on the text area, used to map a double-tap's position
  // to a caret offset so editing starts exactly where you tapped.
  final _readScroll = ScrollController();
  final _textKey = GlobalKey();
  int? _pendingCaret;

  bool _editing = false;

  /// First-run nudge that double-tap switches to editing. Shown once, then fades.
  bool _hintVisible = false;

  // Pull-down-to-dismiss accounting for the read view.
  double _overscrollDown = 0;
  bool _popping = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = TextEditingController(text: widget.thought.text);
    if (!_storage.getEditHintSeen()) {
      _hintVisible = true;
      _storage.setEditHintSeen();
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _hintVisible = false);
      });
    }
  }

  @override
  void dispose() {
    // Saving here is unsafe: dispose runs during tree finalization, when the
    // manager's ValueNotifier can't rebuild its listeners. We save on pop (see
    // PopScope in build) and on app pause instead.
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _focus.dispose();
    _readScroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _save();
    }
  }

  void _save() => _manager.update(widget.thought.id, _controller.text);

  /// Records the caret offset under a double-tap so editing can resume there.
  void _onDoubleTapDown(TapDownDetails d) {
    final width = _textKey.currentContext?.size?.width;
    if (width == null) return;
    final painter = TextPainter(
      text: TextSpan(text: _controller.text, style: TEXT_STYLE_EDITOR),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      strutStyle: STRUT_STYLE_EDITOR,
    )..layout(maxWidth: width);
    // localPosition is relative to the visible text area; add the scroll offset
    // to land in the text's own coordinate space.
    final position = painter.getPositionForOffset(
      Offset(d.localPosition.dx, d.localPosition.dy + _readScroll.offset),
    );
    painter.dispose();
    _pendingCaret = position.offset;
  }

  void _startEditing() {
    if (_editing) return;
    setState(() => _editing = true);
    // Focus on the next frame so the field exists before the IME is raised.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final caret = _pendingCaret;
      if (caret != null) {
        _controller.selection = TextSelection.collapsed(
          offset: caret.clamp(0, _controller.text.length),
        );
        _pendingCaret = null;
      }
      _focus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Save as the route pops — system back and the pull-down dismiss both route
    // through here, and the tree is still live so the manager can notify safely.
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _save();
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
            child: _editing ? _buildEditor() : _buildReader(),
          ),
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      cursorWidth: 1.5,
      style: TEXT_STYLE_EDITOR,
      strutStyle: STRUT_STYLE_EDITOR,
      decoration: const InputDecoration(
        isCollapsed: true,
        border: InputBorder.none,
      ),
    );
  }

  /// Pulling the text down past the top closes the thought — a calm way back
  /// to the list without reaching for the system back button.
  bool _onScroll(ScrollNotification notification) {
    if (notification is OverscrollNotification && notification.overscroll < 0) {
      _overscrollDown += -notification.overscroll;
      if (_overscrollDown > 90 && !_popping) {
        _popping = true;
        Navigator.of(context).maybePop();
      }
    } else if (notification is ScrollEndNotification ||
        (notification is ScrollUpdateNotification &&
            (notification.scrollDelta ?? 0) > 0)) {
      _overscrollDown = 0;
    }
    return false;
  }

  Widget _buildReader() {
    final primary = Theme.of(context).colorScheme.primary;
    // Double-tap anywhere on the text → edit. Long-press still selects text for
    // copying, so reading and editing stay cleanly separate.
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTapDown: _onDoubleTapDown,
          onDoubleTap: _startEditing,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: SizedBox(
              key: _textKey,
              width: double.infinity,
              height: double.infinity,
              child: SingleChildScrollView(
                controller: _readScroll,
                physics: const AlwaysScrollableScrollPhysics(),
                child: SelectableText(
                  _controller.text,
                  style: TEXT_STYLE_EDITOR.copyWith(color: primary),
                  strutStyle: STRUT_STYLE_EDITOR,
                  // Match the editor's cursorWidth: RenderEditable reserves
                  // `caretGap + cursorWidth` of horizontal space before laying
                  // out text, so a differing cursorWidth wraps long lines at a
                  // different point than edit mode.
                  cursorWidth: 1.5,
                ),
              ),
            ),
          ),
        ),
        // First-run hint, fades out on its own.
        Positioned(
          left: 0,
          right: 0,
          bottom: 8,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _hintVisible ? 1 : 0,
              duration: const Duration(milliseconds: 600),
              child: Center(
                child: Text(
                  'Double-tap to edit',
                  style: TEXT_STYLE_EMPTY.copyWith(fontSize: 13),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
