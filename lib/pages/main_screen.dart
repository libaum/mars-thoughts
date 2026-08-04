import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mars_thoughts/data/local_storage_service.dart';
import 'package:mars_thoughts/domain/thought.dart';
import 'package:mars_thoughts/logic/thoughts_manager.dart';
import 'package:mars_thoughts/pages/settings_screen.dart';
import 'package:mars_thoughts/pages/thought_read_screen.dart';
import 'package:mars_thoughts/pages/widgets/thought_row.dart';
import 'package:mars_thoughts/services/service_locator.dart';
import 'package:mars_thoughts/theme/theme_constants.dart';

/// Three panels stacked on one vertical axis: Pinned (above), Write (base),
/// All thoughts (below). The app opens on the blank Write panel — tap it to
/// start typing. Dragging **up** pulls the All/search panel in from below —
/// the direction your thoughts pile up in — and dragging **down** pulls
/// Pinned in from above. Both are fingered reveals that snap open or closed,
/// and each closes again by pulling further past its list's far edge.
///
/// Settings sit at the very top of that same axis: keep pulling down past the
/// top of the pinned list and they arrive. One axis, one direction, no gear
/// icon. The keyboard is never raised on its own, so arriving here stays calm
/// rather than feeling pushy.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _manager = getIt<ThoughtsManager>();
  final _storage = getIt<LocalStorageService>();

  final _editorController = TextEditingController();
  final _editorScroll = ScrollController();
  final _editorFocus = FocusNode();
  final _searchController = TextEditingController();

  // -1 = Pinned fully open (pulled down from above), 0 = Write,
  // 1 = All fully open (pulled up from below).
  late final AnimationController _navController;

  static const _dragSensitivity = 300.0;
  static const _openThreshold = 0.35;
  static const _flingVelocity = 700.0;

  String _query = '';

  /// The thought currently loaded into the write panel, if any. `null` means
  /// the editor holds a brand-new draft. An existing thought is edited in the
  /// very same field, so every gesture here works the same either way.
  String? _editingId;

  // Overscroll accounting for closing an open panel back to Write, mirroring
  // ThoughtReadScreen's pull-down-to-dismiss.
  double _allOverscroll = 0;
  double _pinnedOverscroll = 0;
  bool _closing = false;

  // Pinned is the top of the axis, and Settings sit above it: keep pulling
  // down past the top of the pinned list and they come in.
  double _pinnedTopOverscroll = 0;
  bool _openingSettings = false;

  /// One-time nudge, shown the first time Pinned is opened, that the same
  /// downward pull continues into Settings.
  bool _settingsHintVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _navController = AnimationController(
      vsync: this,
      lowerBound: -1,
      upperBound: 1,
      value: 0,
    );
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    // No commit here: didChangeAppLifecycleState already files the draft on
    // pause, and notifying the manager during tree finalization is unsafe.
    WidgetsBinding.instance.removeObserver(this);
    _navController.dispose();
    _editorController.dispose();
    _editorScroll.dispose();
    _editorFocus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Leaving the app files the draft away — open, type, close, done. That is
    // also what makes every launch start on a blank page: within a session the
    // draft survives everything, across sessions it never does.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _commitDraft();
    }
  }

  /// Files whatever is in the editor away and clears it — writing back to the
  /// thought being edited, or creating a new one. Called on leaving the app
  /// and from the new-thought button, never just from moving between panels.
  void _commitDraft() {
    final id = _editingId;
    final text = _editorController.text;
    if (id != null) {
      // An emptied thought goes to the trash; the manager handles that.
      _manager.update(id, text);
      setState(() => _editingId = null);
    } else if (text.trim().isNotEmpty) {
      _manager.create(text);
    }
    if (_editorController.text.isNotEmpty) {
      _editorController.clear();
    }
  }

  /// Writes an in-progress edit back without ending it, so the list you swipe
  /// to never shows stale text. A new draft has nowhere to go yet and waits
  /// for `+`; an emptied thought waits too, so passing through the list can't
  /// silently trash it mid-edit.
  void _saveInPlace() {
    final id = _editingId;
    if (id == null || _editorController.text.trim().isEmpty) return;
    _manager.update(id, _editorController.text);
  }

  // Guards against a fast double-tap pushing two edit screens for the same
  // thought — the hidden second one would later overwrite the first's save
  // with its stale, unedited snapshot when it's popped.
  bool _openingThought = false;

  void _openThought(Thought thought) async {
    if (_openingThought) return;
    // Already loaded in the write panel — a read view would show the stored
    // text, not what you're in the middle of typing. Go back to it instead.
    if (thought.id == _editingId) {
      _returnToWrite(focus: true);
      return;
    }
    _openingThought = true;
    var editing = false;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ThoughtReadScreen(
          thought: thought,
          onEdit: (caret) {
            editing = true;
            _editInWritePanel(thought, caret);
          },
        ),
      ),
    );
    _openingThought = false;
    // Focus only once the read screen is gone — raising the keyboard for a
    // route that is still on top would fight its exit transition.
    if (editing && mounted) _editorFocus.requestFocus();
  }

  /// Loads an existing thought into the write panel. From here on it behaves
  /// exactly like a fresh draft — same field, same reveal gestures, same `+`.
  ///
  /// Runs while the read screen is still popping, so the panel move has to
  /// snap rather than animate: by the time anything of MainScreen is visible
  /// again, Write is already the panel on screen.
  void _editInWritePanel(Thought thought, int caret) {
    _commitDraft();
    setState(() => _editingId = thought.id);
    _editorController.text = thought.text;
    _editorController.selection = TextSelection.collapsed(
      offset: caret.clamp(0, thought.text.length),
    );
    _navController.stop();
    _navController.value = 0;
  }

  void _returnToWrite({required bool focus}) {
    _navController.animateTo(
      0,
      curve: Curves.easeOut,
      duration: const Duration(milliseconds: 220),
    );
    if (focus) _editorFocus.requestFocus();
  }

  /// Files the current draft and keeps you writing on a blank page.
  void _startNewThought() {
    _commitDraft();
    _editorFocus.requestFocus();
  }

  void _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    _openingSettings = false;
    _pinnedTopOverscroll = 0;
  }

  // ── Vertical reveal navigation ─────────────────────────────────────────

  /// Whether a drag on the write panel should reveal a panel rather than
  /// scroll the draft. The editor keeps the axis for as long as it has text
  /// left to show in that direction; once it is pinned against that end, the
  /// gesture belongs to navigation. Without this the app would be stuck on
  /// Write for as long as the editor held focus.
  bool _canRevealFrom(double dy) {
    if (!_editorScroll.hasClients) return true;
    final position = _editorScroll.position;
    if (position.maxScrollExtent <= 0) return true;
    // Dragging up reveals All, so the editor must have nothing left below it.
    return dy < 0
        ? position.pixels >= position.maxScrollExtent - 0.5
        : position.pixels <= position.minScrollExtent + 0.5;
  }

  void _onWriteDragStart(DragStartDetails d) {
    // Take over from a snap animation still running from the last drag.
    _navController.stop();
  }

  void _onWriteDragUpdate(DragUpdateDetails d) {
    _navController.value =
        (_navController.value - d.delta.dy / _dragSensitivity).clamp(-1.0, 1.0);
  }

  void _onWriteDragEnd(DragEndDetails d) {
    final velocity = d.primaryVelocity ?? 0;
    double target;
    if (velocity.abs() > _flingVelocity) {
      target = velocity > 0 ? -1.0 : 1.0;
    } else {
      final v = _navController.value;
      target = v.abs() >= _openThreshold ? (v > 0 ? 1.0 : -1.0) : 0.0;
    }
    if (target == 0 && _navController.value == 0) return;
    // Leaving Write only drops the keyboard — the draft stays put, so looking
    // something up and coming back doesn't cost you the half-written thought.
    // Arriving back at Write deliberately does *not* raise the keyboard again.
    if (target != 0) {
      _saveInPlace();
      _editorFocus.unfocus();
    }
    if (target < 0) _maybeShowSettingsHint();
    _navController.animateTo(
      target,
      curve: Curves.easeOut,
      duration: const Duration(milliseconds: 220),
    );
  }

  void _closeToWrite() {
    _navController
        .animateTo(
          0,
          curve: Curves.easeOut,
          duration: const Duration(milliseconds: 220),
        )
        .then((_) => _closing = false);
  }

  /// All came up from below, so it goes back down the same way: pull past the
  /// top of the (already fully open) list and it sinks back to Write — the
  /// same "pull past the edge to go back" gesture used in ThoughtReadScreen.
  bool _onAllScroll(ScrollNotification n) {
    if (_navController.value < 0.99) return false;
    if (n is OverscrollNotification && n.overscroll < 0) {
      _allOverscroll += -n.overscroll;
      if (_allOverscroll > 90 && !_closing) {
        _closing = true;
        _closeToWrite();
      }
    } else if (n is ScrollEndNotification ||
        (n is ScrollUpdateNotification && (n.scrollDelta ?? 0) > 0)) {
      _allOverscroll = 0;
    }
    return false;
  }

  /// Both ends of the pinned list do something, and both continue the motion
  /// that got you here. Pulling past the **bottom** lifts the panel back up to
  /// Write, the way it came. Pulling further past the **top** keeps going in
  /// the original downward direction and brings in Settings — they live above
  /// everything, at the far end of the same axis, so there is no gear icon and
  /// no menu anywhere. Pinned lists stay short, so both edges are always in
  /// reach.
  bool _onPinnedScroll(ScrollNotification n) {
    if (_navController.value > -0.99) return false;
    if (n is OverscrollNotification) {
      if (n.overscroll > 0) {
        _pinnedOverscroll += n.overscroll;
        if (_pinnedOverscroll > 90 && !_closing) {
          _closing = true;
          _closeToWrite();
        }
      } else {
        _pinnedTopOverscroll += -n.overscroll;
        if (_pinnedTopOverscroll > 90 && !_openingSettings) {
          _openingSettings = true;
          _openSettings();
        }
      }
    } else if (n is ScrollEndNotification) {
      _pinnedOverscroll = 0;
      _pinnedTopOverscroll = 0;
    } else if (n is ScrollUpdateNotification) {
      final delta = n.scrollDelta ?? 0;
      if (delta < 0) _pinnedOverscroll = 0;
      if (delta > 0) _pinnedTopOverscroll = 0;
    }
    return false;
  }

  /// Shown once, the first time Pinned opens: the pull that got you here keeps
  /// going into Settings.
  void _maybeShowSettingsHint() {
    if (_settingsHintVisible || _storage.getSettingsHintSeen()) return;
    _storage.setSettingsHintSeen();
    setState(() => _settingsHintVisible = true);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _settingsHintVisible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    // No bottom SafeArea: the panels have to paint all the way to the screen
    // edge, or the panel underneath shows through the translucent system
    // navigation bar while one slides over it. The lists and the settings
    // strip carry the inset themselves instead.
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            return Stack(
              fit: StackFit.expand,
              children: [
                _buildWritePanel(),
                AnimatedBuilder(
                  animation: _navController,
                  child: _buildPinnedPanel(),
                  builder: (context, child) {
                    final v = _navController.value.clamp(-1.0, 0.0);
                    return Transform.translate(
                      offset: Offset(0, -height * (1 + v)),
                      child: child,
                    );
                  },
                ),
                AnimatedBuilder(
                  animation: _navController,
                  child: _buildAllPanel(),
                  builder: (context, child) {
                    final v = _navController.value.clamp(0.0, 1.0);
                    return Transform.translate(
                      offset: Offset(0, height * (1 - v)),
                      child: child,
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Write ───────────────────────────────────────────────────────────────

  Widget _buildWritePanel() {
    final field = Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
      child: TextField(
        controller: _editorController,
        focusNode: _editorFocus,
        scrollController: _editorScroll,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        cursorWidth: 1.5,
        style: TEXT_STYLE_EDITOR,
        decoration: const InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: "What's on your mind?",
          hintStyle: TEXT_STYLE_EMPTY,
        ),
      ),
    );
    // The reveal drag stays available while you type — the editor just gets
    // first refusal on the vertical axis (see [_canRevealFrom]), so a long
    // draft scrolls and only hands the gesture over once it runs out of text.
    return RawGestureDetector(
      gestures: <Type, GestureRecognizerFactory>{
        _RevealDragRecognizer:
            GestureRecognizerFactoryWithHandlers<_RevealDragRecognizer>(
              () => _RevealDragRecognizer(canReveal: _canRevealFrom),
              (instance) => instance
                ..onStart = _onWriteDragStart
                ..onUpdate = _onWriteDragUpdate
                ..onEnd = _onWriteDragEnd,
            ),
      },
      child: Stack(
        children: [
          field,
          Positioned(
            right: 20,
            bottom: 34 + MediaQuery.paddingOf(context).bottom,
            child: _buildNewThoughtButton(),
          ),
        ],
      ),
    );
  }

  /// Files the draft away and leaves you on a fresh blank page. It only shows
  /// up once there is something to file — an empty editor needs no button.
  Widget _buildNewThoughtButton() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _editorController,
      builder: (context, value, _) {
        // While editing an existing thought the button stays reachable even
        // when emptied — that's how you commit deleting it to the trash.
        final visible = value.text.trim().isNotEmpty || _editingId != null;
        return IgnorePointer(
          ignoring: !visible,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _startNewThought,
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Icon(Icons.add, size: 20, color: COLOR_SECONDARY),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Pinned ──────────────────────────────────────────────────────────────

  Widget _buildPinnedPanel() {
    return ValueListenableBuilder<List<Thought>>(
      valueListenable: _manager.thoughtsNotifier,
      builder: (context, _, _) {
        final pinned = _manager.pinned;
        return _PanelBackground(
          onLongPress: _openSettings,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 28, 32, 16),
                child: Row(
                  children: [
                    const Text('PINNED', style: TEXT_STYLE_PANEL_LABEL),
                    const Spacer(),
                    AnimatedOpacity(
                      opacity: _settingsHintVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 600),
                      child: Text(
                        'Keep pulling for settings',
                        style: TEXT_STYLE_EMPTY.copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onPinnedScroll,
                  child: _thoughtList(
                    pinned,
                    showPinIcon: false,
                    allowDelete: false,
                    emptyMessage: 'No pinned thoughts',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── All thoughts ────────────────────────────────────────────────────────

  Widget _buildAllPanel() {
    return ValueListenableBuilder<List<Thought>>(
      valueListenable: _manager.thoughtsNotifier,
      builder: (context, _, _) {
        final thoughts = _manager.active;
        final visible = _query.isEmpty
            ? thoughts
            : thoughts
                  .where((t) => t.text.toLowerCase().contains(_query))
                  .toList();
        return _PanelBackground(
          onLongPress: _openSettings,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
                child: TextField(
                  controller: _searchController,
                  style: TEXT_STYLE_SEARCH_INPUT,
                  cursorWidth: 1.5,
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: 'Search thoughts…',
                    hintStyle: TEXT_STYLE_EMPTY,
                  ),
                ),
              ),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onAllScroll,
                  child: _thoughtList(
                    visible,
                    showPinIcon: true,
                    query: _query,
                    emptyMessage: thoughts.isEmpty
                        ? 'No thoughts yet'
                        : 'Nothing found',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Shared list / states ───────────────────────────────────────────────

  Widget _thoughtList(
    List<Thought> thoughts, {
    required bool showPinIcon,
    required String emptyMessage,
    bool allowDelete = true,
    String query = '',
  }) {
    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const AlwaysScrollableScrollPhysics(),
      // Clears the system navigation bar the panels now paint behind.
      padding: EdgeInsets.only(
        bottom: 24 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: thoughts.isEmpty ? 1 : thoughts.length,
      separatorBuilder: (context, index) => _ThoughtDivider(),
      itemBuilder: (context, index) {
        if (thoughts.isEmpty) return _emptyState(emptyMessage);
        final thought = thoughts[index];
        return ThoughtRow(
          key: ValueKey(thought.id),
          thought: thought,
          showPinIcon: showPinIcon,
          query: query,
          onTap: () => _openThought(thought),
          onLongPress: () => _manager.togglePin(thought.id),
          onDelete: allowDelete ? () => _manager.delete(thought.id) : null,
        );
      },
    );
  }

  Widget _emptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(message, style: TEXT_STYLE_EMPTY),
      ),
    );
  }
}

/// Background that opens Settings on a long-press over empty space, and paints
/// an opaque backdrop so the panel fully hides Write when it slides over it.
/// Rows win their own long-press (toggle pin) via the gesture arena.
class _PanelBackground extends StatelessWidget {
  final Widget child;
  final VoidCallback onLongPress;
  const _PanelBackground({required this.child, required this.onLongPress});

  @override
  Widget build(BuildContext context) => GestureDetector(
    // Opaque, not translucent: the panels sit on top of Write in a Stack,
    // so anything falling through would reach Write's reveal drag as well.
    behavior: HitTestBehavior.opaque,
    onLongPress: onLongPress,
    child: ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    ),
  );
}

class _ThoughtDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Divider(
      height: 1,
      thickness: 0.5,
      color: primary.withValues(alpha: 0.08),
      indent: 32,
      endIndent: 32,
    );
  }
}

/// A vertical-drag recognizer that claims the gesture the moment the finger
/// clearly commits to the vertical axis. Without that eager claim the write
/// editor's own scrollable — a deeper competitor in the arena — wins as soon
/// as a draft overflows, and the panel reveal silently stops working. A tap
/// never travels far enough to trigger it, so tap-to-focus is unaffected.
class _RevealDragRecognizer extends VerticalDragGestureRecognizer {
  _RevealDragRecognizer({required this.canReveal});

  /// Asked once per drag, with the vertical distance travelled so far, to
  /// decide whether navigation may take the gesture off the write editor.
  final bool Function(double dy) canReveal;

  Offset? _origin;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _origin = event.position;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent && _origin != null) {
      final delta = event.position - _origin!;
      if (delta.dy.abs() > kTouchSlop && delta.dy.abs() > delta.dx.abs()) {
        if (canReveal(delta.dy)) {
          resolve(GestureDisposition.accepted);
        } else {
          resolve(GestureDisposition.rejected);
          stopTrackingPointer(event.pointer);
          return;
        }
      }
    }
    super.handleEvent(event);
  }
}
