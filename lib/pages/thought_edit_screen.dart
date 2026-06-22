import 'package:flutter/material.dart';
import 'package:mars_thoughts/domain/thought.dart';
import 'package:mars_thoughts/logic/thoughts_manager.dart';
import 'package:mars_thoughts/pages/widgets/double_tap_theme_toggle.dart';
import 'package:mars_thoughts/services/service_locator.dart';
import 'package:mars_thoughts/theme/theme_constants.dart';

/// Full-screen editor for an existing thought. Auto-saves on leave (back
/// gesture or backgrounding the app). Emptying the text deletes the thought.
class ThoughtEditScreen extends StatefulWidget {
  final Thought thought;
  const ThoughtEditScreen({super.key, required this.thought});

  @override
  State<ThoughtEditScreen> createState() => _ThoughtEditScreenState();
}

class _ThoughtEditScreenState extends State<ThoughtEditScreen>
    with WidgetsBindingObserver {
  final _manager = getIt<ThoughtsManager>();
  late final TextEditingController _controller;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = TextEditingController(text: widget.thought.text);
  }

  @override
  void dispose() {
    _save();
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _focus.dispose();
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

  @override
  Widget build(BuildContext context) {
    return DoubleTapThemeToggle(
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
            child: TextField(
              controller: _controller,
              focusNode: _focus,
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
