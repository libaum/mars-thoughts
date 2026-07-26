import 'package:flutter_test/flutter_test.dart';
import 'package:mars_thoughts/domain/thought.dart';
import 'package:mars_thoughts/util/time_format.dart';

void main() {
  group('Thought.preview', () {
    Thought make(String text) => Thought(
          id: '1',
          text: text,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );

    test('uses the first non-empty line', () {
      expect(make('Hello\nworld').preview, 'Hello');
    });

    test('skips leading blank lines', () {
      expect(make('\n\n  Real thought\nmore').preview, 'Real thought');
    });

    test('is empty for whitespace-only text', () {
      expect(make('   \n  ').preview, '');
    });
  });

  group('Thought JSON', () {
    test('round-trips including pinnedAt', () {
      final original = Thought(
        id: 'abc',
        text: 'a thought',
        createdAt: DateTime(2026, 6, 1, 9),
        updatedAt: DateTime(2026, 6, 2, 10),
        pinnedAt: DateTime(2026, 6, 3, 11),
      );
      final restored = Thought.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.text, original.text);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
      expect(restored.pinnedAt, original.pinnedAt);
      expect(restored.isPinned, isTrue);
    });

    test('unpinned thought has null pinnedAt', () {
      final t = Thought(
        id: 'x',
        text: 't',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(Thought.fromJson(t.toJson()).pinnedAt, isNull);
      expect(t.isPinned, isFalse);
    });

    test('round-trips deletedAt for trashed thoughts', () {
      final trashed = Thought(
        id: 'd',
        text: 'gone',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        deletedAt: DateTime(2026, 6, 4, 12),
      );
      final restored = Thought.fromJson(trashed.toJson());
      expect(restored.deletedAt, trashed.deletedAt);
      expect(restored.isDeleted, isTrue);
    });

    test('legacy JSON without deletedAt loads as a live thought', () {
      final json = {
        'id': 'old',
        'text': 't',
        'createdAt': DateTime(2026).millisecondsSinceEpoch,
        'updatedAt': DateTime(2026).millisecondsSinceEpoch,
        'pinnedAt': null,
      };
      expect(Thought.fromJson(json).isDeleted, isFalse);
    });
  });

  group('Thought.copyWith', () {
    final t = Thought(
      id: '1',
      text: 'a',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      pinnedAt: DateTime(2026),
      deletedAt: DateTime(2026),
    );

    test('clearDeleted restores a thought', () {
      expect(t.copyWith(clearDeleted: true).isDeleted, isFalse);
    });

    test('clearPinned unpins a thought', () {
      expect(t.copyWith(clearPinned: true).isPinned, isFalse);
    });
  });

  group('formatThoughtTime', () {
    final now = DateTime(2026, 6, 22, 12);

    test('recent times are relative', () {
      expect(formatThoughtTime(now, now: now), 'now');
      expect(formatThoughtTime(now.subtract(const Duration(minutes: 5)), now: now), '5m');
      expect(formatThoughtTime(now.subtract(const Duration(hours: 3)), now: now), '3h');
      expect(formatThoughtTime(now.subtract(const Duration(days: 2)), now: now), '2d');
    });

    test('older than a week shows a short date', () {
      expect(formatThoughtTime(DateTime(2026, 5, 1), now: now), 'May 1');
    });

    test('a different year includes the year', () {
      expect(formatThoughtTime(DateTime(2025, 12, 30), now: now), 'Dec 30, 2025');
    });
  });
}
