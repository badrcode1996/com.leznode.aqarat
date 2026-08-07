import 'package:flutter_test/flutter_test.dart';

import 'package:aqarat/l10n/app_language.dart';
import 'package:aqarat/ui/contracts/doc_lang_field.dart';

/// The interface language and the DOCUMENT language are deliberately not the
/// same setting. Kurdish paperwork is the house standard, and an English
/// interface does not change that — only an Arabic interface does.
void main() {
  group('document language default', () {
    test('Kurdish interface issues Kurdish paperwork', () {
      expect(docLangFor(AppLanguage.ku, arabicAvailable: true), 'ku');
      expect(docLangFor(AppLanguage.ku, arabicAvailable: false), 'ku');
    });

    test('English interface still issues Kurdish paperwork', () {
      // An English-speaking agent in Erbil hands over the same Kurdish contract
      // as everyone else.
      expect(docLangFor(AppLanguage.en, arabicAvailable: true), 'ku');
      expect(docLangFor(AppLanguage.en, arabicAvailable: false), 'ku');
    });

    test('Arabic interface issues Arabic paperwork', () {
      expect(docLangFor(AppLanguage.ar, arabicAvailable: true), 'ar');
    });

    test('Arabic interface falls back when Arabic is not available', () {
      // The plan may not include Arabic contracts, or the company may have no
      // Arabic clauses for this contract type. Defaulting to Arabic anyway
      // would fail at render time — the Cloud Function re-checks the plan.
      expect(docLangFor(AppLanguage.ar, arabicAvailable: false), 'ku');
    });

    test('only ever returns a language the renderer knows', () {
      for (final app in AppLanguage.values) {
        for (final available in [true, false]) {
          expect(docLangFor(app, arabicAvailable: available),
              anyOf('ku', 'ar'));
        }
      }
    });
  });
}
