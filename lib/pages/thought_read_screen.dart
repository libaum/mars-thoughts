import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mars_thoughts/data/local_storage_service.dart';
import 'package:mars_thoughts/domain/thought.dart';
import 'package:mars_thoughts/services/service_locator.dart';
import 'package:mars_thoughts/theme/theme_constants.dart';

/// Shows a thought for reading: the text is plain and selectable, so you can
/// read it — or select and copy — without the keyboard popping up.
///
/// Editing does not happen here. A double-tap pops this screen and hands back
/// the caret offset you tapped; `MainScreen` then loads the thought into the
/// write panel, so an old thought is edited in exactly the same field, with
/// exactly the same gestures, as a new one. Pull down past the top or swipe
/// left to close.
class ThoughtReadScreen extends StatefulWidget {
  final Thought thought;

  /// Called with the tapped caret offset the moment editing starts, *before*
  /// this screen finishes popping — the write panel is then already in place
  /// behind it, so the list never flashes past on the way back.
  final void Function(int caret) onEdit;

  const ThoughtReadScreen({
    super.key,
    required this.thought,
    required this.onEdit,
  });

  @override
  State<ThoughtReadScreen> createState() => _ThoughtReadScreenState();
}

class _ThoughtReadScreenState extends State<ThoughtReadScreen> {
  final _storage = getIt<LocalStorageService>();

  // Scroll + a key on the text area, used to map a double-tap's position to a
  // caret offset so editing picks up exactly where you tapped.
  final _readScroll = ScrollController();
  final _textKey = GlobalKey();
  int _caret = 0;

  /// First-run nudge that double-tap switches to editing. Shown once, then fades.
  bool _hintVisible = false;

  // Dismiss accounting: pulling down past the top, or swiping left.
  double _overscrollDown = 0;
  double _dragLeft = 0;
  bool _popping = false;
  static const _swipeBackThreshold = 96.0;

  @override
  void initState() {
    super.initState();
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
    _readScroll.dispose();
    super.dispose();
  }

  /// Records the caret offset under a double-tap so editing can resume there.
  void _onDoubleTapDown(TapDownDetails d) {
    final width = _textKey.currentContext?.size?.width;
    if (width == null) return;
    final painter = TextPainter(
      text: TextSpan(text: widget.thought.text, style: TEXT_STYLE_EDITOR),
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
    _caret = position.offset;
  }

  /// Hands the thought back to the write panel, cursor where you tapped.
  void _startEditing() {
    if (_popping) return;
    widget.onEdit(_caret);
    _close();
  }

  void _close() {
    if (_popping) return;
    _popping = true;
    Navigator.of(context).pop();
  }

  /// Pulling the text down past the top closes the thought — a calm way back
  /// to the list without reaching for the system back button.
  bool _onScroll(ScrollNotification notification) {
    if (notification is OverscrollNotification && notification.overscroll < 0) {
      _overscrollDown += -notification.overscroll;
      if (_overscrollDown > 90) _close();
    } else if (notification is ScrollEndNotification ||
        (notification is ScrollUpdateNotification &&
            (notification.scrollDelta ?? 0) > 0)) {
      _overscrollDown = 0;
    }
    return false;
  }

  /// A left swipe here closes the thought — the horizontal mirror of the
  /// pull-down dismiss above, a second calm way back to the list.
  void _onSwipeBackUpdate(DragUpdateDetails d) {
    setState(() => _dragLeft = (_dragLeft - d.delta.dx).clamp(0.0, 200.0));
  }

  void _onSwipeBackEnd(DragEndDetails d) {
    final shouldPop = _dragLeft >= _swipeBackThreshold;
    setState(() => _dragLeft = 0);
    if (shouldPop) _close();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    // Double-tap anywhere on the text → edit. Long-press still selects text for
    // copying, so reading and editing stay cleanly separate.
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
          child: RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: <Type, GestureRecognizerFactory>{
              _LeftwardDragRecognizer:
                  GestureRecognizerFactoryWithHandlers<_LeftwardDragRecognizer>(
                    () => _LeftwardDragRecognizer(),
                    (instance) => instance
                      ..onUpdate = _onSwipeBackUpdate
                      ..onEnd = _onSwipeBackEnd,
                  ),
            },
            child: Transform.translate(
              offset: Offset(-_dragLeft, 0),
              child: Stack(
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
                            widget.thought.text,
                            style: TEXT_STYLE_EDITOR.copyWith(color: primary),
                            strutStyle: STRUT_STYLE_EDITOR,
                            // Match the write panel's cursorWidth:
                            // RenderEditable reserves `caretGap + cursorWidth`
                            // of horizontal space before laying out text, so a
                            // differing cursorWidth wraps long lines at a
                            // different point than the editor does.
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A horizontal-drag recognizer that only ever claims *leftward* drags. A
/// rightward drag is rejected right away so it falls through to the text
/// below, where it still belongs to selection.
class _LeftwardDragRecognizer extends HorizontalDragGestureRecognizer {
  Offset? _origin;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _origin = event.position;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent && _origin != null) {
      final dx = event.position.dx - _origin!.dx;
      if (dx > kTouchSlop) {
        resolve(GestureDisposition.rejected);
        stopTrackingPointer(event.pointer);
        return;
      }
      if (dx < -kTouchSlop) {
        resolve(GestureDisposition.accepted);
      }
    }
    super.handleEvent(event);
  }
}
