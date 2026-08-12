import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mars_thoughts/data/local_storage_service.dart';
import 'package:mars_thoughts/domain/thought.dart';
import 'package:mars_thoughts/logic/thoughts_manager.dart';
import 'package:mars_thoughts/pages/settings_screen.dart';
import 'package:mars_thoughts/pages/widgets/thought_row.dart';
import 'package:mars_thoughts/services/service_locator.dart';
import 'package:mars_thoughts/theme/theme_constants.dart';

/// Four panels stacked on one continuous vertical axis, top to bottom:
/// Settings, Pinned, Write, All. The whole stack moves together as a single
/// filmstrip — whichever direction the finger drags, both the current panel
/// and its neighbour travel that same direction by the same distance, so the
/// visible motion always matches the gesture. The app opens on the blank
/// Write panel — tap it to start typing. Dragging **up** pulls All in from
/// below — the direction your thoughts pile up in — and dragging **down**
/// pulls Pinned in from above, then keeps going into Settings if you keep
/// pulling past the top of the pinned list. One axis, one direction, no gear
/// icon. The keyboard is never raised on its own, so arriving on Write stays
/// calm rather than feeling pushy.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _manager = getIt<ThoughtsManager>();
  final _storage = getIt<LocalStorageService>();

  final _editorController = TextEditingController();
  final _editorScroll = ScrollController();
  final _editorFocus = FocusNode();
  final _searchController = TextEditingController();
  final _pinnedScroll = ScrollController();
  final _allScroll = ScrollController();

  // Position along the four-panel filmstrip: -2 = Settings, -1 = Pinned,
  // 0 = Write, 1 = All. Each panel is painted at `(slot - value) * height`,
  // so the whole stack shifts together as `value` changes.
  late final AnimationController _navController;

  static const _slotSettings = -2.0;
  static const _slotPinned = -1.0;
  static const _slotWrite = 0.0;
  static const _slotAll = 1.0;

  static const _dragSensitivity = 300.0;
  static const _openThreshold = 0.35;
  static const _flingVelocity = 700.0;

  /// Snaps `_navController` straight to [target] — a plain cut, no motion in
  /// between. This is the end-of-gesture landing regardless of the
  /// "Animations" toggle in Settings; that toggle only controls whether the
  /// panel visibly follows the finger *during* the drag itself (see
  /// `_animateDrag`) — the release always lands here instantly.
  void _animateNavTo(double target) {
    _cancelSelection();
    _navController.value = target;
  }

  static const _tutorialText =
      "Welcome to Mars Thoughts.\n\n"
      "Just start typing — there's no save button, this is already saved.\n\n"
      "Swipe up for all your thoughts, swipe down for pinned ones — keep "
      "pulling down past Pinned to reach Settings.\n\n"
      "On a thought: swipe left to delete, swipe right to copy. Long-press to "
      "select — then pin, copy, or delete from the bar. Tap to open it and "
      "edit right there.\n\n"
      "Tap + when you're ready to file this away and start fresh.";

  String _query = '';

  /// Multi-select state, live only within Pinned/All (rows are the only thing
  /// that can start it). Cleared whenever the panel changes underneath it —
  /// see [_cancelSelection] and its call sites.
  bool _selectionModeOn = false;
  Set<String> _selectedIds = {};

  /// The thought currently loaded into the write panel, if any. `null` means
  /// the editor holds a brand-new draft. An existing thought is edited in the
  /// very same field, so every gesture here works the same either way.
  String? _editingId;

  // Persists the draft to disk a little after typing settles, so an OS kill
  // in the background can't lose it — but not on every keystroke.
  Timer? _draftSaveTimer;

  /// One-time nudge, shown the first time Pinned is opened, that the same
  /// downward pull continues into Settings.
  bool _settingsHintVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _navController = AnimationController(
      vsync: this,
      lowerBound: _slotSettings,
      upperBound: _slotAll,
      value: _slotWrite,
    );
    _editingId = _storage.getDraftEditingId();
    final draft = _storage.getDraftText();
    if (draft.isNotEmpty) {
      _editorController.text = draft;
    } else if (_manager.active.isEmpty && !_storage.getTutorialSeen()) {
      // Nothing saved yet and nothing typed yet: this is a fresh install, so
      // seed the editor with a short tutorial instead of leaving it blank. It
      // behaves exactly like any other draft from here on — overwritten by
      // typing, filed away by `+`, or left as-is.
      _editorController.text = _tutorialText;
      _storage.setTutorialSeen();
    }
    _editorController.addListener(_scheduleDraftSave);
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftSaveTimer?.cancel();
    _navController.dispose();
    _editorController.dispose();
    _editorScroll.dispose();
    _editorFocus.dispose();
    _searchController.dispose();
    _pinnedScroll.dispose();
    _allScroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _fileDraftOnBackground();
  }

  /// Debounced so a fast typist doesn't hit SharedPreferences on every
  /// keystroke — only once things settle for a moment.
  void _scheduleDraftSave() {
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 400), () {
      _storage.setDraft(_editorController.text, _editingId);
    });
  }

  /// Files whatever is in the editor away and clears it — writing back to the
  /// thought being edited, or creating a new one. Called from the new-thought
  /// button and when switching to editing another thought, never just from
  /// moving between panels or leaving the app.
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
    _draftSaveTimer?.cancel();
    _storage.clearDraft();
  }

  /// Writes an in-progress edit back without ending it, so the list you swipe
  /// to never shows stale text. A new draft has nowhere to go yet and waits
  /// for `+`; an emptied thought waits too, so passing through the list can't
  /// silently trash it mid-edit.
  void _saveInPlace() {
    _draftSaveTimer?.cancel();
    _storage.setDraft(_editorController.text, _editingId);
    final id = _editingId;
    if (id == null || _editorController.text.trim().isEmpty) return;
    _manager.update(id, _editorController.text);
  }

  /// Called when the app is backgrounded — as opposed to just moving between
  /// panels inside it. Unlike a normal draft, this actually files a new,
  /// never-committed draft away into the thought list (mirroring `+`) rather
  /// than leaving it pending, and clears the persisted draft entry. So if the
  /// process is later killed while backgrounded, the thought isn't lost, but
  /// a cold relaunch finds no draft and opens blank rather than reopening it.
  /// If the app merely resumes without ever having been killed, none of this
  /// is visible: the in-memory editor and [_editingId] are left untouched, so
  /// it looks exactly like it did before backgrounding — now simply backed by
  /// a real thought instead of a pending draft, same as editing an existing
  /// one already works.
  void _fileDraftOnBackground() {
    final text = _editorController.text;
    if (text.trim().isNotEmpty) {
      final id = _editingId;
      if (id != null) {
        _manager.update(id, text);
      } else {
        final thought = _manager.create(text);
        setState(() => _editingId = thought?.id);
      }
    }
    _draftSaveTimer?.cancel();
    _storage.clearDraft();
  }

  // ── Multi-select ────────────────────────────────────────────────────────

  void _enterSelection(String id) {
    setState(() {
      _selectionModeOn = true;
      _selectedIds = {id};
    });
  }

  void _toggleSelected(String id) {
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  /// Exits selection without acting. Deselecting down to zero items does
  /// *not* call this on its own — only an explicit Cancel, a completed
  /// action, or leaving the panel does.
  void _cancelSelection() {
    if (!_selectionModeOn) return;
    setState(() {
      _selectionModeOn = false;
      _selectedIds = {};
    });
  }

  void _selectionPin() {
    _manager.togglePinMany(_selectedIds);
    _cancelSelection();
  }

  void _selectionCopy() {
    final texts = _manager.thoughtsNotifier.value
        .where((t) => _selectedIds.contains(t.id))
        .map((t) => t.text)
        .join('\n\n');
    Clipboard.setData(ClipboardData(text: texts));
    _cancelSelection();
  }

  void _selectionDelete() {
    _manager.deleteMany(_selectedIds);
    _cancelSelection();
  }

  void _openThought(Thought thought) {
    // Already loaded in the write panel — reveal it and pick up where you
    // left off, rather than reloading the stored (possibly stale) text.
    if (thought.id == _editingId) {
      _returnToWrite(focus: true);
      return;
    }
    _editInWritePanel(thought);
    _animateNavTo(_slotWrite);
  }

  /// Loads an existing thought into the write panel. From here on it behaves
  /// exactly like a fresh draft — same field, same reveal gestures, same `+`.
  /// The keyboard is deliberately left alone: opening a thought is calm, not
  /// pushy, so it only appears once the user taps into the field themselves.
  void _editInWritePanel(Thought thought) {
    _commitDraft();
    setState(() => _editingId = thought.id);
    _editorController.text = thought.text;
    _editorController.selection = TextSelection.collapsed(
      offset: thought.text.length,
    );
  }

  void _returnToWrite({required bool focus}) {
    _animateNavTo(_slotWrite);
    if (focus) _editorFocus.requestFocus();
  }

  /// Files the current draft and keeps you writing on a blank page.
  void _startNewThought() {
    _commitDraft();
    _editorFocus.requestFocus();
  }

  void _openSettings() {
    _animateNavTo(_slotSettings);
  }

  // ── Vertical reveal navigation ─────────────────────────────────────────

  /// Whether a drag on the write editor should reveal a panel rather than
  /// scroll the draft. The editor keeps the axis for as long as it has text
  /// left to show in that direction; once it is pinned against that end, the
  /// gesture belongs to navigation. Only used by Write/Settings — Pinned/All
  /// are plain `ListView`s, whose own scroll recognizer reliably wins a
  /// competing raw drag once there's real content to scroll, so those two
  /// are driven by their overscroll instead (see [_onPinnedScrollHandoff]).
  bool _canRevealFrom(ScrollController controller, double dy) {
    if (!controller.hasClients) return true;
    final position = controller.position;
    if (position.maxScrollExtent <= 0) return true;
    // Dragging up reveals the panel below, so the scrollable must have
    // nothing left below it; dragging down reveals the one above.
    return dy < 0
        ? position.pixels >= position.maxScrollExtent - 0.5
        : position.pixels <= position.minScrollExtent + 0.5;
  }

  // Overscroll accounting for revealing a panel once the editor's own scroll
  // runs out of room, mirroring _onAllScroll/_onPinnedScroll below.
  double _editorTopOverscroll = 0;
  double _editorBottomOverscroll = 0;
  bool _revealingFromEditor = false;

  /// Picks up where [_RevealDragRecognizer] leaves off: that recognizer only
  /// decides once, right as a drag starts, so a long draft that isn't already
  /// scrolled to the edge you're pulling toward keeps the whole gesture for
  /// itself. This lets the editor's own scroll run all the way to the top or
  /// bottom first — same as any other scrollable — and only once you keep
  /// pulling past that edge, the same "pull past the end" distance used
  /// everywhere else in this file, does it hand off to the panel reveal.
  bool _onEditorScroll(ScrollNotification n) {
    if (n is OverscrollNotification) {
      if (n.overscroll < 0) {
        _editorTopOverscroll += -n.overscroll;
        if (_editorTopOverscroll > 90 && !_revealingFromEditor) {
          _revealingFromEditor = true;
          _revealFromEditor(_slotPinned);
        }
      } else {
        _editorBottomOverscroll += n.overscroll;
        if (_editorBottomOverscroll > 90 && !_revealingFromEditor) {
          _revealingFromEditor = true;
          _revealFromEditor(_slotAll);
        }
      }
    } else if (n is ScrollEndNotification) {
      _editorTopOverscroll = 0;
      _editorBottomOverscroll = 0;
    } else if (n is ScrollUpdateNotification) {
      final delta = n.scrollDelta ?? 0;
      if (delta < 0) _editorTopOverscroll = 0;
      if (delta > 0) _editorBottomOverscroll = 0;
    }
    return false;
  }

  void _revealFromEditor(double target) {
    _cancelSelection();
    _saveInPlace();
    _editorFocus.unfocus();
    if (target == _slotPinned) _maybeShowSettingsHint();
    _navController.value = target;
    _revealingFromEditor = false;
  }

  // Tracks how far the current drag has travelled along the full filmstrip
  // (-2..1), independent of whether that's actually mirrored onto
  // `_navController`. With animations off this is the only record of drag
  // progress — the panel itself doesn't move until the gesture resolves.
  // Shared between Write's and Settings' own raw drags — only one of them is
  // ever interactive at a time, since only one panel is ever at rest.
  double _dragProgress = 0;
  bool _animateDrag = false;

  void _onDragStart(DragStartDetails d) {
    // Take over from a snap animation still running from the last drag.
    _navController.stop();
    _dragProgress = _navController.value;
    // Cached for the duration of the drag so a mid-drag toggle flip (not
    // reachable in the UI today, but cheap to guard against) can't produce a
    // half-followed gesture.
    _animateDrag = _storage.getAnimationsEnabled();
  }

  /// [min]/[max] bound the drag to the dragging panel's own immediate
  /// neighbours, so an unusually long drag can't overshoot past them into a
  /// panel that was never revealed on the way — e.g. Write shouldn't be able
  /// to preview Settings without passing through a visible Pinned first.
  void _onDragUpdate(
    DragUpdateDetails d, {
    double min = _slotPinned,
    double max = _slotAll,
  }) {
    _dragProgress = (_dragProgress - d.delta.dy / _dragSensitivity).clamp(
      min,
      max,
    );
    // Animations off (the default): the panel stays put — no fingered
    // reveal — until the gesture resolves in the matching *DragEnd, which
    // then cuts straight to the result instead of easing into it.
    if (_animateDrag) _navController.value = _dragProgress;
  }

  void _onSettingsDragUpdate(DragUpdateDetails d) {
    _onDragUpdate(d, min: _slotSettings, max: _slotPinned);
  }

  /// Shared end-of-drag decision for Write's and Settings' own raw reveal
  /// drag: pick whichever neighbour the gesture committed to — by fling
  /// velocity, or by distance dragged past [_openThreshold] — or spring
  /// back to [home] otherwise. [above]/[below] are the neighbours revealed
  /// by dragging down/up respectively; leave either null where a panel has
  /// no neighbour on that side (nothing above Settings). Pinned/All don't
  /// have their own raw drag recognizer — a `ListView`'s own scroll
  /// recognizer reliably wins the gesture arena over a competing raw drag
  /// once it has real scroll content — so those two panels feed this same
  /// method from their `ScrollNotification`s instead (see
  /// [_onPinnedScroll]/[_onAllScroll]).
  void _onPanelDragEnd(
    DragEndDetails d, {
    required double home,
    double? above,
    double? below,
  }) {
    final velocity = d.primaryVelocity ?? 0;
    double target;
    if (velocity.abs() > _flingVelocity) {
      target = (velocity > 0 ? above : below) ?? home;
    } else {
      final progress = _dragProgress - home;
      if (progress <= -_openThreshold && above != null) {
        target = above;
      } else if (progress >= _openThreshold && below != null) {
        target = below;
      } else {
        target = home;
      }
    }
    if (target == home && _navController.value == home) return;
    // Leaving Write only drops the keyboard — the draft stays put, so
    // looking something up and coming back doesn't cost you the
    // half-written thought. Arriving back at Write deliberately does *not*
    // raise the keyboard again.
    if (home == _slotWrite && target != _slotWrite) {
      _saveInPlace();
      _editorFocus.unfocus();
    }
    if (target == _slotPinned) _maybeShowSettingsHint();
    _animateNavTo(target);
  }

  void _onWriteDragEnd(DragEndDetails d) =>
      _onPanelDragEnd(d, home: _slotWrite, above: _slotPinned, below: _slotAll);

  void _onSettingsDragEnd(DragEndDetails d) =>
      _onPanelDragEnd(d, home: _slotSettings, below: _slotPinned);

  void _closeToWrite() {
    _cancelSelection();
    _navController.value = _slotWrite;
  }

  // Pinned/All are plain `ListView`s, so — unlike Write/Settings — a
  // competing raw drag recognizer doesn't work here: a `ListView`'s built-in
  // scroll recognizer reliably wins that race once it has real content. But
  // `ScrollNotification`s carry the same raw `dragDetails` (DragStart/
  // Update/EndDetails) that the recognizer-driven panels use, once the list
  // is pulled past its own edge into overscroll — so these two panels can
  // listen in on that and feed the exact same shared drag machinery as
  // Write/Settings, live-follow and fling included, without ever competing
  // for the gesture.
  bool _onPinnedScroll(ScrollNotification n) {
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _onDragStart(n.dragDetails!);
    } else if (n is OverscrollNotification && n.dragDetails != null) {
      _onDragUpdate(n.dragDetails!, min: _slotSettings, max: _slotWrite);
    } else if (n is ScrollEndNotification) {
      // `dragDetails` is null here when the release had enough residual
      // velocity for the list's own physics to start a ballistic settle —
      // this notification then arrives only after that settle completes.
      // Committing regardless (with zero velocity, i.e. threshold-only) is
      // required, or a drag released that way leaves the panel stuck
      // mid-reveal forever, since no other notification follows.
      _onPanelDragEnd(
        n.dragDetails ?? DragEndDetails(),
        home: _slotPinned,
        above: _slotSettings,
        below: _slotWrite,
      );
    }
    return false;
  }

  bool _onAllScroll(ScrollNotification n) {
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _onDragStart(n.dragDetails!);
    } else if (n is OverscrollNotification && n.dragDetails != null) {
      _onDragUpdate(n.dragDetails!, min: _slotWrite, max: _slotAll);
    } else if (n is ScrollEndNotification) {
      _onPanelDragEnd(
        n.dragDetails ?? DragEndDetails(),
        home: _slotAll,
        above: _slotWrite,
      );
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

  /// System back mirrors swipe-back at whatever level you're at: cancel a
  /// selection first, then step one level back through the stack — Settings
  /// to Pinned, Pinned/All to Write — the same neighbour a pull-past-the-edge
  /// gesture would land on. Only once both are already settled does back
  /// fall through to its default behaviour (leaving the app).
  void _stepBack() {
    if (_navController.value == _slotSettings) {
      _animateNavTo(_slotPinned);
    } else {
      _closeToWrite();
    }
  }

  /// Positions [child] on the filmstrip at [slot]: on-screen exactly when
  /// `_navController.value == slot`, and offset by one full panel height for
  /// every step of distance from it. Every panel uses this same formula, so
  /// the whole stack always moves together, by the same distance, in the
  /// direction the finger drags — never just the incoming panel sliding over
  /// a static one.
  Widget _positioned(double slot, double height, Widget child) {
    return AnimatedBuilder(
      animation: _navController,
      child: child,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (slot - _navController.value) * height),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Re-evaluated on every nav change via the AnimatedBuilder below, since
    // dragging a panel open doesn't otherwise trigger a rebuild of this
    // widget.
    return AnimatedBuilder(
      animation: _navController,
      builder: (context, child) {
        final canPop = !_selectionModeOn && _navController.value == _slotWrite;
        return PopScope(
          canPop: canPop,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (_selectionModeOn) {
              _cancelSelection();
            } else {
              _stepBack();
            }
          },
          child: child!,
        );
      },
      // No bottom SafeArea: the panels have to paint all the way to the
      // screen edge, or the panel underneath shows through the translucent
      // system navigation bar while one slides over it. The lists and the
      // settings strip carry the inset themselves instead.
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final height = constraints.maxHeight;
              return Stack(
                fit: StackFit.expand,
                children: [
                  _positioned(_slotSettings, height, _buildSettingsPanel()),
                  _positioned(_slotPinned, height, _buildPinnedPanel()),
                  _positioned(_slotWrite, height, _buildWritePanel()),
                  _positioned(_slotAll, height, _buildAllPanel()),
                  _buildSelectionBar(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Bottom-anchored bar shown while [_selectionModeOn] — plain text actions,
  /// no cards or elevation, a single hairline divider matching
  /// [_ThoughtDivider]. Sits above both list panels since only one is ever
  /// reachable at a time.
  Widget _buildSelectionBar() {
    final primary = Theme.of(context).colorScheme.primary;
    return IgnorePointer(
      ignoring: !_selectionModeOn,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedOpacity(
          opacity: _selectionModeOn ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(
                  color: primary.withValues(alpha: 0.08),
                  width: 0.5,
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                16,
                24,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Row(
                children: [
                  _selectionAction('Cancel', _cancelSelection),
                  const Spacer(),
                  _selectionAction(
                    'Pin',
                    _selectedIds.isEmpty ? null : _selectionPin,
                  ),
                  const SizedBox(width: 28),
                  _selectionAction(
                    'Copy',
                    _selectedIds.isEmpty ? null : _selectionCopy,
                  ),
                  const SizedBox(width: 28),
                  _selectionAction(
                    'Delete',
                    _selectedIds.isEmpty ? null : _selectionDelete,
                    color: COLOR_DELETE,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectionAction(String label, VoidCallback? onTap, {Color? color}) {
    final enabled = onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w300,
          color: enabled
              ? (color ?? Theme.of(context).colorScheme.primary)
              : COLOR_SECONDARY.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  // ── Write ───────────────────────────────────────────────────────────────

  Widget _buildWritePanel() {
    final field = NotificationListener<ScrollNotification>(
      onNotification: _onEditorScroll,
      child: Padding(
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
      ),
    );
    // The reveal drag stays available while you type — the editor just gets
    // first refusal on the vertical axis (see [_canRevealFrom]), so a long
    // draft scrolls and only hands the gesture over once it runs out of text.
    return RawGestureDetector(
      gestures: <Type, GestureRecognizerFactory>{
        _RevealDragRecognizer:
            GestureRecognizerFactoryWithHandlers<_RevealDragRecognizer>(
              () => _RevealDragRecognizer(
                canReveal: (dy) => _canRevealFrom(_editorScroll, dy),
              ),
              (instance) => instance
                ..onStart = _onDragStart
                ..onUpdate = _onDragUpdate
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

  // ── Settings ────────────────────────────────────────────────────────────

  /// Settings has no scrollable content of its own to give first refusal to,
  /// so unlike Write it only ever needs to accept upward drags (revealing
  /// Pinned below it) — pulling down does nothing, there's nothing above.
  Widget _buildSettingsPanel() {
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: <Type, GestureRecognizerFactory>{
        _RevealDragRecognizer:
            GestureRecognizerFactoryWithHandlers<_RevealDragRecognizer>(
              () => _RevealDragRecognizer(canReveal: (dy) => dy < 0),
              (instance) => instance
                ..onStart = _onDragStart
                ..onUpdate = _onSettingsDragUpdate
                ..onEnd = _onSettingsDragEnd,
            ),
      },
      child: const SettingsScreen(),
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
                    controller: _pinnedScroll,
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
                    controller: _allScroll,
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
    required ScrollController controller,
    required bool showPinIcon,
    required String emptyMessage,
    bool allowDelete = true,
    String query = '',
  }) {
    return ListView.separated(
      controller: controller,
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
          selected: _selectedIds.contains(thought.id),
          selectionMode: _selectionModeOn,
          onTap: _selectionModeOn
              ? () => _toggleSelected(thought.id)
              : () => _openThought(thought),
          onLongPress: _selectionModeOn
              ? () => _toggleSelected(thought.id)
              : () => _enterSelection(thought.id),
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
