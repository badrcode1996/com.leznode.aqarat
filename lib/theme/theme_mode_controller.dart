import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';

const _prefsKey = 'theme_mode';

/// The light/dark choice, persisted on the device.
///
/// Deliberately NOT stored on the user's Firestore profile: the theme has to be
/// right on the very first frame, and a network read would mean opening in the
/// wrong brightness and flashing to the right one. It is also a per-device
/// preference — the same person may want dark on their phone and light on the
/// office desktop.
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.system) {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey);
      if (stored != null) state = _fromWire(stored);
    } catch (e) {
      // A device where prefs are unavailable simply follows the system theme.
      debugPrint('Could not read the stored theme: $e');
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode.name);
    } catch (e) {
      debugPrint('Could not store the theme: $e');
    }
  }

  static ThemeMode _fromWire(String value) => switch (value) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>(
        (ref) => ThemeModeController());

/// Label for each mode, in the interface language.
String themeModeLabel(ThemeMode mode) => switch (mode) {
      ThemeMode.light => S.themeLight,
      ThemeMode.dark => S.themeDark,
      ThemeMode.system => S.themeSystem,
    };

IconData themeModeIcon(ThemeMode mode) => switch (mode) {
      ThemeMode.light => Icons.light_mode_rounded,
      ThemeMode.dark => Icons.dark_mode_rounded,
      ThemeMode.system => Icons.brightness_auto_rounded,
    };
