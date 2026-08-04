import 'package:flutter/widgets.dart';

/// Splits [text] into spans, styling case-insensitive matches of [query] with
/// [matchStyle] and everything else with [baseStyle]. An empty [query] returns
/// a single plain span.
List<TextSpan> highlightSpans(
  String text,
  String query, {
  required TextStyle baseStyle,
  required TextStyle matchStyle,
}) {
  if (query.isEmpty) {
    return [TextSpan(text: text, style: baseStyle)];
  }

  final spans = <TextSpan>[];
  final lower = text.toLowerCase();
  var start = 0;
  while (true) {
    final index = lower.indexOf(query, start);
    if (index < 0) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
      break;
    }
    if (index > start) {
      spans.add(TextSpan(text: text.substring(start, index), style: baseStyle));
    }
    spans.add(
      TextSpan(
        text: text.substring(index, index + query.length),
        style: matchStyle,
      ),
    );
    start = index + query.length;
  }
  return spans;
}
