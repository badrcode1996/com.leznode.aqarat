import 'package:flutter_test/flutter_test.dart';

import 'package:aqarat/l10n/app_language.dart';
import 'package:aqarat/l10n/app_strings.dart';

/// Catches the failure mode that actually happens when translating hundreds of
/// strings by hand: a block gets copied and one entry is never translated, so a
/// screen silently shows Kurdish inside an English UI.
void main() {
  /// Letters used by Central Kurdish (and Persian) but not by standard Arabic.
  ///
  /// Two failure modes: a whole entry copied over untranslated, and the subtler
  /// one — an Arabic word typed on a Kurdish keyboard, so it carries ک (U+06A9)
  /// where Arabic wants ك (U+0643). That renders as a slightly wrong letter
  /// which a non-Arabic speaker will not spot.
  const kurdishOnly = [
    'ێ', 'ۆ', 'ڕ', 'ڵ', // Kurdish-only vowels and trills
    'ک', 'گ', 'پ', 'چ', 'ژ', // Persian/Kurdish consonants
    'ی', 'ە', // Farsi yeh and Kurdish schwa (Arabic uses ي and ة/ه)
  ];

  /// Values that are the same in every language on purpose.
  const shared = {'—'};

  test('every catalogue has the same number of entries', () {
    final n = AppStrings.ku.values.length;
    expect(AppStrings.ar.values.length, n);
    expect(AppStrings.en.values.length, n);
    expect(n, greaterThan(100), reason: 'the values list looks out of date');
  });

  for (final language in AppLanguage.values) {
    final s = AppStrings.of(language);

    test('${language.wire}: no entry is blank', () {
      for (final v in s.values) {
        expect(v.trim(), isNotEmpty);
      }
    });
  }

  test('the Arabic catalogue contains no Kurdish-only letters', () {
    final ku = AppStrings.ku.values;
    final ar = AppStrings.ar.values;
    for (var i = 0; i < ar.length; i++) {
      for (final letter in kurdishOnly) {
        expect(ar[i].contains(letter), isFalse,
            reason: 'entry $i is still Kurdish: "${ar[i]}" (ku: "${ku[i]}")');
      }
    }
  });

  test('the English catalogue contains no Arabic script', () {
    final ku = AppStrings.ku.values;
    final en = AppStrings.en.values;
    final arabicScript = RegExp(r'[؀-ۿ]');
    for (var i = 0; i < en.length; i++) {
      expect(arabicScript.hasMatch(en[i]), isFalse,
          reason: 'entry $i was never translated: "${en[i]}" '
              '(ku: "${ku[i]}")');
    }
  });

  test('no entry is identical across all three languages', () {
    final ku = AppStrings.ku.values;
    final ar = AppStrings.ar.values;
    final en = AppStrings.en.values;
    for (var i = 0; i < ku.length; i++) {
      if (shared.contains(ku[i])) continue;
      expect(ku[i] == ar[i] && ar[i] == en[i], isFalse,
          reason: 'entry $i is the same everywhere: "${ku[i]}"');
    }
  });

  test('interpolated strings differ per language and keep their value', () {
    for (final language in AppLanguage.values) {
      final s = AppStrings.of(language);
      expect(s.error('boom'), contains('boom'));
      expect(s.hoursAgo(3), contains('3'));
      expect(s.daysAgo(5), contains('5'));
      expect(s.perMonth('100 IQD'), contains('100 IQD'));
      expect(s.areaSqm(120), contains('120'));
      expect(s.roomsCount(4), contains('4'));
      expect(s.deleteListingConfirm('Ahmed'), contains('Ahmed'));
      expect(s.callWithNumber('0770'), contains('0770'));
      expect(s.contractNumber(12), contains('12'));
      expect(s.monthNumber(3), contains('3'));
      expect(s.daysOverdue(9), contains('9'));
      expect(s.allRightsReserved(2026), contains('2026'));
      expect(s.receiptCreated(s.receiptRentReceive, 12), contains('12'));
      expect(s.receiptCreated(s.receiptRentReceive, 12),
          contains(s.receiptRentReceive));
    }
    expect(AppStrings.en.error('x'), isNot(AppStrings.ku.error('x')));
    expect(AppStrings.ar.error('x'), isNot(AppStrings.ku.error('x')));
  });

  test('each language reports its own direction', () {
    expect(AppLanguage.ku.isRtl, isTrue);
    expect(AppLanguage.ar.isRtl, isTrue);
    expect(AppLanguage.en.isRtl, isFalse);
  });
}
