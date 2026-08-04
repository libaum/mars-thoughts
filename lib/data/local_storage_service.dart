import 'dart:convert';
import 'package:mars_thoughts/domain/thought.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around SharedPreferences for persisting app state.
/// Local only — no backend, no sync.
class LocalStorageService {
  static const _keyThoughts = 'thoughts';
  static const _keyThemeIsDark = 'theme_is_dark';
  static const _keyEditHintSeen = 'edit_hint_seen';
  static const _keySettingsHintSeen = 'settings_hint_seen';

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

  /// Whether the "double-tap to edit" hint has already been shown once.
  bool getEditHintSeen() => _prefs.getBool(_keyEditHintSeen) ?? false;

  Future<void> setEditHintSeen() async {
    await _prefs.setBool(_keyEditHintSeen, true);
  }

  /// Whether the "keep pulling for settings" hint has already been shown once.
  bool getSettingsHintSeen() => _prefs.getBool(_keySettingsHintSeen) ?? false;

  Future<void> setSettingsHintSeen() async {
    await _prefs.setBool(_keySettingsHintSeen, true);
  }
}
