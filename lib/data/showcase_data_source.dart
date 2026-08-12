import 'package:flutter/foundation.dart';
import 'package:mars_thoughts/domain/thought.dart';

/// Curated example thoughts used to fill the app for Play Store screenshots.
///
/// Hard-gated by [enabled]: only active in `kDebugMode`, and only ever
/// written once per install (see `LocalStorageService.getShowcaseSeeded`) —
/// not on every relaunch, or manual edits made while testing would get wiped
/// out each time the app restarts. This can never load in a profile or
/// release build.
class ShowcaseDataSource {
  const ShowcaseDataSource._();

  static bool get enabled => kDebugMode;

  /// Sorted newest-first is not required — `ThoughtsManager` re-sorts by
  /// `updatedAt` on load — but the ids/timestamps below are chosen so the
  /// list reads naturally in that order, oldest (the onboarding thought) last.
  static List<Thought> build() {
    final now = DateTime.now();
    DateTime ago(Duration d) => now.subtract(d);

    final tNow = now;
    final t2h = ago(const Duration(hours: 2));
    final t22h = ago(const Duration(hours: 22));
    final t26h = ago(const Duration(hours: 26));
    final t2d = ago(const Duration(days: 2));
    final t3d = ago(const Duration(days: 3));
    final t4d = ago(const Duration(days: 4));
    final t7d = ago(const Duration(days: 7));
    final t30d = ago(const Duration(days: 30));

    return [
      Thought(
        id: 'showcase-1',
        text: "the best interfaces feel like they're not there at all",
        createdAt: tNow,
        updatedAt: tNow,
        pinnedAt: tNow,
      ),
      Thought(
        id: 'showcase-2',
        text:
            "Been thinking about why I reach for my phone the second there's "
            "a gap. It's never about the phone. It's about not wanting to sit "
            "in the empty moment. The gap is the point.",
        createdAt: t2h,
        updatedAt: t2h,
      ),
      Thought(
        id: 'showcase-3',
        text:
            "“We are what we repeatedly do.”\n — caught this somewhere, want to keep it",
        createdAt: t22h,
        updatedAt: t22h,
        pinnedAt: ago(const Duration(hours: 21)),
      ),
      Thought(
        id: 'showcase-4',
        text: "app idea:\na clock that only shows how much daylight is left",
        createdAt: t26h,
        updatedAt: t26h,
      ),
      Thought(
        id: 'showcase-5',
        text:
            "Manifesto note:\nPeople aren't weak, they're unarmed. The systems "
            "are engineered to win. Willpower against a billion-dollar "
            "budget — that's not a fair fight.",
        createdAt: t2d,
        updatedAt: t2d,
        pinnedAt: ago(const Duration(days: 2, hours: 1)),
      ),
      Thought(
        id: 'showcase-6',
        text:
            "On wanting less\n"
            "I keep trying to make every empty moment useful. "
            "Maybe that's the habit I actually want to break.",
        createdAt: t3d,
        updatedAt: t3d,
      ),
      Thought(
        id: 'showcase-7',
        text:
            "opening line, don't lose it:\n"
            "\"The morning the satellites went quiet, nobody noticed until "
            "noon.\"",
        createdAt: t4d,
        updatedAt: t4d,
      ),
      Thought(
        id: 'showcase-8',
        text: "maybe nothing is missing.",
        createdAt: t7d,
        updatedAt: t7d,
      ),
      Thought(
        id: 'showcase-9',
        text:
            "that little café near the harbor\nflat white was perfect, no "
            "wifi on purpose. go back.",
        createdAt: t7d.subtract(const Duration(hours: 2)),
        updatedAt: t7d.subtract(const Duration(hours: 2)),
      ),
      Thought(
        id: 'showcase-10',
        text:
            "Anicca\n"
            "Everything I keep trying to hold onto is already changing. "
            "Weird that this is obvious and still feels like news.",
        createdAt: t7d.subtract(const Duration(days: 1)),
        updatedAt: t7d.subtract(const Duration(days: 1)),
      ),
      Thought(
        id: 'showcase-11',
        text:
            "sometimes the mind doesn't need an answer.\n"
            "it just needs somewhere quiet to finish the thought.",
        createdAt: t7d.subtract(const Duration(days: 2)),
        updatedAt: t7d.subtract(const Duration(days: 2)),
      ),
      Thought(
        id: 'showcase-12',
        text:
            "Welcome to Mars Thoughts.\n\n"
            "Just start typing — there's no save button, this is already "
            "saved.\n\n"
            "Swipe up for all your thoughts, swipe down for pinned ones — "
            "keep pulling down past Pinned to reach Settings.\n\n"
            "On a thought: swipe left to delete, swipe right to copy. "
            "Long-press to select — then pin, copy, or delete from the bar. "
            "Tap to open it and edit right there.\n\n"
            "Tap + when you're ready to file this away and start fresh.",
        createdAt: t30d,
        updatedAt: t30d,
      ),
    ];
  }
}
