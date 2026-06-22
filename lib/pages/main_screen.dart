import 'package:flutter/material.dart';
import 'package:mars_thoughts/domain/thought.dart';
import 'package:mars_thoughts/logic/thoughts_manager.dart';
import 'package:mars_thoughts/pages/settings_screen.dart';
import 'package:mars_thoughts/pages/thought_edit_screen.dart';
import 'package:mars_thoughts/pages/widgets/double_tap_theme_toggle.dart';
import 'package:mars_thoughts/pages/widgets/thought_row.dart';
import 'package:mars_thoughts/services/service_locator.dart';
import 'package:mars_thoughts/theme/theme_constants.dart';

/// Three panels: Pinned ← Write → All thoughts.
/// The app opens on Write with the cursor blinking — capture first.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  // PageView order: 0 = Pinned, 1 = Write (initial), 2 = All thoughts.
  static const _writeIndex = 1;

  final _manager = getIt<ThoughtsManager>();

  final _pageController = PageController(initialPage: _writeIndex);
  final _editorController = TextEditingController();
  final _editorFocus = FocusNode();
  final _searchController = TextEditingController();

  int _currentPage = _writeIndex;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _commitDraft();
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _editorController.dispose();
    _editorFocus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Leaving the app saves the current draft — open, type, close, done.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _commitDraft();
    }
  }

  /// Saves whatever is in the editor as a new thought, then clears it so the
  /// Write panel is always blank when you return to it.
  void _commitDraft() {
    final text = _editorController.text;
    if (text.trim().isNotEmpty) {
      _manager.create(text);
    }
    if (_editorController.text.isNotEmpty) {
      _editorController.clear();
    }
  }

  void _onPageChanged(int index) {
    if (_currentPage == _writeIndex && index != _writeIndex) {
      _commitDraft();
    }
    if (index == _writeIndex) {
      _editorFocus.requestFocus();
    } else {
      _editorFocus.unfocus();
    }
    setState(() => _currentPage = index);
  }

  void _openThought(Thought thought) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ThoughtEditScreen(thought: thought)),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DoubleTapThemeToggle(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  children: [
                    _buildPinnedPanel(),
                    _buildWritePanel(),
                    _buildAllPanel(),
                  ],
                ),
              ),
              _buildPageIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Write ────────────────────────────────────────────────────────────────

  Widget _buildWritePanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
      child: TextField(
        controller: _editorController,
        focusNode: _editorFocus,
        autofocus: true,
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
  }

  // ── Pinned ─────────────────────────────────────────────────────────────────

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
              const Padding(
                padding: EdgeInsets.fromLTRB(32, 28, 32, 16),
                child: Text('PINNED', style: TEXT_STYLE_PANEL_LABEL),
              ),
              Expanded(
                child: pinned.isEmpty
                    ? _emptyState('No pinned thoughts')
                    : _thoughtList(pinned, showPinIcon: false),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── All thoughts ───────────────────────────────────────────────────────────

  Widget _buildAllPanel() {
    return ValueListenableBuilder<List<Thought>>(
      valueListenable: _manager.thoughtsNotifier,
      builder: (context, thoughts, _) {
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
                child: thoughts.isEmpty
                    ? _emptyState('No thoughts yet')
                    : visible.isEmpty
                        ? _emptyState('Nothing found')
                        : _thoughtList(visible, showPinIcon: true),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Shared list / states ─────────────────────────────────────────────────

  Widget _thoughtList(List<Thought> thoughts, {required bool showPinIcon}) {
    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: thoughts.length,
      separatorBuilder: (context, index) => _ThoughtDivider(),
      itemBuilder: (context, index) {
        final thought = thoughts[index];
        return ThoughtRow(
          key: ValueKey(thought.id),
          thought: thought,
          showPinIcon: showPinIcon,
          onTap: () => _openThought(thought),
          onLongPress: () => _manager.togglePin(thought.id),
          onDismissed: () => _manager.delete(thought.id),
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

  Widget _buildPageIndicator() {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          final active = i == _currentPage;
          return Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? primary
                  : primary.withValues(alpha: 0.2),
            ),
          );
        }),
      ),
    );
  }
}

/// Background that opens Settings on a long-press over empty space. Rows win
/// their own long-press (toggle pin) via the gesture arena.
class _PanelBackground extends StatelessWidget {
  final Widget child;
  final VoidCallback onLongPress;
  const _PanelBackground({required this.child, required this.onLongPress});

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: onLongPress,
        child: child,
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
