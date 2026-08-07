import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_language.dart';

const _prefsKey = 'app_language';

/// The interface language, persisted on the device.
///
/// Stored locally for the same reasons as the theme (see ThemeModeController):
/// it has to be right on the first frame, and it is a per-device choice — the
/// Kurdish-speaking owner and an Arabic-speaking agent may share one account's
/// company but never one phone.
class LanguageController extends StateNotifier<AppLanguage> {
  LanguageController() : super(AppLanguage.ku) {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey);
      if (stored != null) state = AppLanguage.fromWire(stored);
    } catch (e) {
      // Falls back to Kurdish, which is the source language anyway.
      debugPrint('Could not read the stored language: $e');
    }
  }

  Future<void> set(AppLanguage language) async {
    state = language;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, language.wire);
    } catch (e) {
      debugPrint('Could not store the language: $e');
    }
  }
}

final languageProvider =
    StateNotifierProvider<LanguageController, AppLanguage>(
        (ref) => LanguageController());
