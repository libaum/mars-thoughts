import 'package:flutter/material.dart';

/// A route with no transition — a plain cut, matching the panel navigation's
/// current animation-free default (see [MainScreen]'s `_animateNavTo`).
/// [MaterialPageRoute] always plays the platform push animation regardless
/// of that setting, which is why it isn't used for in-app navigation here.
Route<T> instantRoute<T>(WidgetBuilder builder) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}
