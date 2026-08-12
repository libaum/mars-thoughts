import 'dart:convert';
import 'package:mars_thoughts/domain/thought.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around SharedPreferences for persisting app state.
/// Local only — no backend, no sync.
class LocalStorageService {
  static const _keyThoughts = 'thoughts';
  static const _keyThemeIsDark = 'theme_is_dark';
  static const _keySettingsHintSeen = 'settings_hint_seen';
  static const _keyDraftText = 'draft_text';
  static const _keyDraftEditingId = 'draft_editing_id';
  static const _keyTutorialSeen = 'tutorial_seen';
  static const _keyAnimationsEnabled = 'animations_enabled';
  static const _keyLightBackground = 'light_background';
  static const _keyDarkBackground = 'dark_background';

  final SharedPreferences _prefs;

  LocalStorageService._(this._prefs);

  static Future<LocalStorageService> getInstance() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStorageService._(prefs);
  }

  /// All thoughts (unordered as stored; ordering is the manager's concern).
  List<Thought> getThoughts() {
    final json = _prefs.getString(_keyThoughts);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list
          .map((e) => Thought.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> setThoughts(List<Thought> thoughts) async {
    final json = jsonEncode(thoughts.map((t) => t.toJson()).toList());
    await _prefs.setString(_keyThoughts, json);
  }

  /// Theme mode
  bool? getThemeIsDark() => _prefs.getBool(_keyThemeIsDark);

  Future<void> setThemeIsDark(bool isDark) async {
    await _prefs.setBool(_keyThemeIsDark, isDark);
  }

  /// Whether the "keep pulling for settings" hint has already been shown once.
  bool getSettingsHintSeen() => _prefs.getBool(_keySettingsHintSeen) ?? false;

  Future<void> setSettingsHintSeen() async {
    await _prefs.setBool(_keySettingsHintSeen, true);
  }

  /// The write panel's not-yet-filed-away draft, kept outside the thoughts
  /// list so it survives the process being killed in the background without
  /// showing up as a saved thought. `editingId` is set when the draft is an
  /// in-progress edit of an existing thought rather than a brand-new one.
  String getDraftText() => _prefs.getString(_keyDraftText) ?? '';

  String? getDraftEditingId() => _prefs.getString(_keyDraftEditingId);

  Future<void> setDraft(String text, String? editingId) async {
    await _prefs.setString(_keyDraftText, text);
    if (editingId == null) {
      await _prefs.remove(_keyDraftEditingId);
    } else {
      await _prefs.setString(_keyDraftEditingId, editingId);
    }
  }

  Future<void> clearDraft() async {
    await _prefs.remove(_keyDraftText);
    await _prefs.remove(_keyDraftEditingId);
  }

  /// Whether the first-launch tutorial draft has already been seeded once.
  bool getTutorialSeen() => _prefs.getBool(_keyTutorialSeen) ?? false;

  Future<void> setTutorialSeen() async {
    await _prefs.setBool(_keyTutorialSeen, true);
  }

  /// Whether panel drags follow the finger live instead of cutting straight
  /// to the result once the gesture resolves. Defaults off.
  bool getAnimationsEnabled() =>
      _prefs.getBool(_keyAnimationsEnabled) ?? false;

  Future<void> setAnimationsEnabled(bool enabled) async {
    await _prefs.setBool(_keyAnimationsEnabled, enabled);
  }

  /// Custom background colors, stored as ARGB ints. Null means "use the
  /// default pure black/white".
  int? getLightBackground() => _prefs.getInt(_keyLightBackground);

  Future<void> setLightBackground(int? argb) async {
    if (argb == null) {
      await _prefs.remove(_keyLightBackground);
    } else {
      await _prefs.setInt(_keyLightBackground, argb);
    }
  }

  int? getDarkBackground() => _prefs.getInt(_keyDarkBackground);

  Future<void> setDarkBackground(int? argb) async {
    if (argb == null) {
      await _prefs.remove(_keyDarkBackground);
    } else {
      await _prefs.setInt(_keyDarkBackground, argb);
    }
  }
}
