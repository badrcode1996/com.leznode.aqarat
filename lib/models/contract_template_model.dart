import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'company_model.dart';
import 'contract_model.dart';

/// Per-company document template (collection: `templates`, doc id == company_id).
///
/// Covers both the **contract** PDF (clauses + design) and the **receipt**
/// (وەصڵ) PDF design. Clauses are stored as strings containing `{token}`
/// placeholders substituted with the contract's data at render time (see
/// [tokensFor]). This lets a super admin customise clauses and a few design
/// knobs per company without touching code. Any missing field falls back to
/// [ContractTemplate.defaults] — the built-in clauses + design.
class ContractTemplate {
  const ContractTemplate({
    required this.rentClauses,
    required this.saleClauses,
    required this.rentTitle,
    required this.saleTitle,
    required this.primaryColorHex,
    required this.clauseFontSize,
    required this.receiptColorHex,
    required this.receiptFontSize,
    this.rentClausesAr = const [],
    this.saleClausesAr = const [],
    this.rentTitleAr = '',
    this.saleTitleAr = '',
    this.rentClausesEn = const [],
    this.saleClausesEn = const [],
    this.rentTitleEn = '',
    this.saleTitleEn = '',
  });

  final List<String> rentClauses;
  final List<String> saleClauses;
  final String rentTitle;
  final String saleTitle;

  /// The Arabic edition of the same document, with its own clause list so a
  /// company can tune the two languages independently.
  final List<String> rentClausesAr;
  final List<String> saleClausesAr;
  final String rentTitleAr;
  final String saleTitleAr;

  /// The English edition, mirroring the Arabic one above.
  final List<String> rentClausesEn;
  final List<String> saleClausesEn;
  final String rentTitleEn;
  final String saleTitleEn;

  /// True when THIS contract type can be rendered in Arabic. Clause lists are
  /// filled from the built-in Arabic defaults by [fromJson], so this is only
  /// false if a company deliberately cleared them.
  bool arabicReadyFor(Contract c) =>
      (c is RentContract ? rentClausesAr : saleClausesAr).isNotEmpty;

  /// The same for the English edition.
  bool englishReadyFor(Contract c) =>
      (c is RentContract ? rentClausesEn : saleClausesEn).isNotEmpty;

  /// 6-digit RRGGBB hex (no leading #).
  final String primaryColorHex;
  final double clauseFontSize;

  /// Receipt (وەصڵ) design: banner/footer colour + field font size.
  final String receiptColorHex;
  final double receiptFontSize;

  ContractTemplate copyWith({
    List<String>? rentClauses,
    List<String>? saleClauses,
    String? rentTitle,
    String? saleTitle,
    String? primaryColorHex,
    double? clauseFontSize,
    String? receiptColorHex,
    double? receiptFontSize,
    List<String>? rentClausesAr,
    List<String>? saleClausesAr,
    String? rentTitleAr,
    String? saleTitleAr,
    List<String>? rentClausesEn,
    List<String>? saleClausesEn,
    String? rentTitleEn,
    String? saleTitleEn,
  }) =>
      ContractTemplate(
        rentClauses: rentClauses ?? this.rentClauses,
        saleClauses: saleClauses ?? this.saleClauses,
        rentTitle: rentTitle ?? this.rentTitle,
        saleTitle: saleTitle ?? this.saleTitle,
        primaryColorHex: primaryColorHex ?? this.primaryColorHex,
        clauseFontSize: clauseFontSize ?? this.clauseFontSize,
        receiptColorHex: receiptColorHex ?? this.receiptColorHex,
        receiptFontSize: receiptFontSize ?? this.receiptFontSize,
        rentClausesAr: rentClausesAr ?? this.rentClausesAr,
        saleClausesAr: saleClausesAr ?? this.saleClausesAr,
        rentTitleAr: rentTitleAr ?? this.rentTitleAr,
        saleTitleAr: saleTitleAr ?? this.saleTitleAr,
        rentClausesEn: rentClausesEn ?? this.rentClausesEn,
        saleClausesEn: saleClausesEn ?? this.saleClausesEn,
        rentTitleEn: rentTitleEn ?? this.rentTitleEn,
        saleTitleEn: saleTitleEn ?? this.saleTitleEn,
      );

  /// Reads a stored template, filling every absent/empty field from
  /// [defaults] so the renderer always has a complete template.
  factory ContractTemplate.fromJson(Map<String, dynamic> json) {
    final d = ContractTemplate.defaults();
    List<String> list(String key, List<String> fallback) {
      final raw = json[key];
      if (raw is! List || raw.isEmpty) return fallback;
      final items = raw.map((e) => e.toString()).toList();
      return items.isEmpty ? fallback : items;
    }

    String str(String key, String fallback) {
      final v = json[key];
      return (v is String && v.trim().isNotEmpty) ? v : fallback;
    }

    /// [str], but a heading a rename has retired counts as unset — see
    /// [legacyTitles]. A stored title otherwise wins over the default, which
    /// left every company that had ever saved its template on the old wording.
    String title(String key, String fallback) {
      final v = str(key, fallback);
      return legacyTitles.contains(v.trim()) ? fallback : v;
    }

    return ContractTemplate(
      // Migration shim: templates saved while clauses were split per property
      // kind still carry `rent_clauses_house` as their newest edit, with a
      // stale `rent_clauses` alongside it. Prefer the former, then the plain
      // list, then the defaults. Drop once every template has been re-saved.
      rentClauses: list('rent_clauses_house', list('rent_clauses', d.rentClauses)),
      saleClauses: list('sale_clauses', d.saleClauses),
      rentTitle: title('rent_title', d.rentTitle),
      saleTitle: title('sale_title', d.saleTitle),
      primaryColorHex: str('primary_color', d.primaryColorHex),
      clauseFontSize: (json['clause_font_size'] as num?)?.toDouble() ??
          d.clauseFontSize,
      receiptColorHex: str('receipt_color', d.receiptColorHex),
      receiptFontSize: (json['receipt_font_size'] as num?)?.toDouble() ??
          d.receiptFontSize,
      rentClausesAr: list('rent_clauses_ar', d.rentClausesAr),
      saleClausesAr: list('sale_clauses_ar', d.saleClausesAr),
      rentTitleAr: title('rent_title_ar', d.rentTitleAr),
      saleTitleAr: title('sale_title_ar', d.saleTitleAr),
      rentClausesEn: list('rent_clauses_en', d.rentClausesEn),
      saleClausesEn: list('sale_clauses_en', d.saleClausesEn),
      rentTitleEn: title('rent_title_en', d.rentTitleEn),
      saleTitleEn: title('sale_title_en', d.saleTitleEn),
    );
  }

  Map<String, dynamic> toJson() => {
        'rent_clauses': rentClauses,
        'sale_clauses': saleClauses,
        'rent_title': rentTitle,
        'sale_title': saleTitle,
        'primary_color': primaryColorHex,
        'clause_font_size': clauseFontSize,
        'receipt_color': receiptColorHex,
        'receipt_font_size': receiptFontSize,
        'rent_clauses_ar': rentClausesAr,
        'sale_clauses_ar': saleClausesAr,
        'rent_title_ar': rentTitleAr,
        'sale_title_ar': saleTitleAr,
        'rent_clauses_en': rentClausesEn,
        'sale_clauses_en': saleClausesEn,
        'rent_title_en': rentTitleEn,
        'sale_title_en': saleTitleEn,
        'updated_at': FieldValue.serverTimestamp(),
      };

  // ---------------------------------------------------------------------------
  // Token substitution
  // ---------------------------------------------------------------------------

  static final _money = NumberFormat.decimalPattern();
  static final _date = DateFormat('yyyy/MM/dd');

  /// All `{token}` → value pairs available for a given contract. Tokens not
  /// relevant to the contract type resolve to an empty string.
  static Map<String, String> tokensFor(Contract c, Company? company) {
    String money(num v) => _money.format(v);
    final cn = (company?.nameKu.isNotEmpty ?? false)
        ? company!.nameKu
        : 'کۆمپانیا';

    final common = <String, String>{
      'company': cn,
      'contract_number': '${c.contractNumber}',
      'party1': _party1(c),
      'party2': _party2(c),
      'property_type': _propertyType(c),
      'project': _project(c),
      'property_number': _propertyNumber(c),
      'area': '${_area(c)} م²',
    };

    if (c is RentContract) {
      return {
        ...common,
        'currency': c.currency.label,
        'rent_amount': money(c.rentAmount),
        'period_months': '${c.rentalPeriodMonths}',
        'start_date': _date.format(c.startDate),
        'end_date': _date.format(c.handoverDate),
        'down_payment': money(c.downPayment),
        'down_payment_months': '${c.downPaymentMonths}',
        'payment_frequency': '${c.paymentFrequencyMonths}',
        'guarantee': money(c.guaranteeAmount),
        'purpose': c.rentalPurpose,
        'grace_period': c.gracePeriod,
        'late_fee': money(c.lateFeePerDay),
      };
    }
    final s = c as SaleContract;
    return {
      ...common,
      'currency': s.currency.label,
      'total_price': money(s.totalPrice),
      'down_payment': money(s.downPayment),
      'payment_method': s.paymentMethod,
      'delivery_date': _date.format(s.deliveryDate),
      'late_fee': money(s.lateFeePerDay),
      'withdrawal': money(s.withdrawalAmount),
      'lawyer': s.lawyer,
    };
  }

  /// Replaces every `{token}` in [clause] with its value from [tokens].
  /// Unknown tokens are left untouched so mistakes are visible, not silent.
  static String apply(String clause, Map<String, String> tokens) {
    return clause.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) {
      final key = m.group(1)!;
      return tokens.containsKey(key) ? tokens[key]! : m.group(0)!;
    });
  }

  static String _party1(Contract c) =>
      c is RentContract ? c.party1Name : (c as SaleContract).party1Name;
  static String _party2(Contract c) =>
      c is RentContract ? c.party2Name : (c as SaleContract).party2Name;
  static String _propertyType(Contract c) =>
      c is RentContract ? c.propertyType : (c as SaleContract).propertyType;
  static String _project(Contract c) =>
      c is RentContract ? c.projectName : (c as SaleContract).projectName;
  static String _propertyNumber(Contract c) =>
      c is RentContract ? c.propertyNumber : (c as SaleContract).propertyNumber;
  static num _area(Contract c) =>
      c is RentContract ? c.area : (c as SaleContract).area;

  /// Human-readable token reference shown in the editor.
  static const tokenHelp = <String, String>{
    '{company}': 'ناوی کۆمپانیا',
    '{contract_number}': 'ژمارەی گرێبەست',
    '{party1}': 'لایەنی یەکەم',
    '{party2}': 'لایەنی دووەم',
    '{property_type}': 'جۆری موڵک',
    '{project}': 'پڕۆژە / گەڕەک',
    '{property_number}': 'ژمارەی موڵک',
    '{area}': 'ڕووبەر',
    '{currency}': 'دراو',
    '{rent_amount}': 'بڕی کرێ',
    '{period_months}': 'ماوەی کرێ (مانگ)',
    '{start_date}': 'بەرواری دەستپێک',
    '{end_date}': 'بەرواری کۆتایی',
    '{down_payment}': 'پێشەکی',
    '{down_payment_months}': 'پێشەکی چەند مانگ',
    '{payment_frequency}': 'کرێدان چەند مانگ جارێک',
    '{guarantee}': 'بڕی دڵنیایی',
    '{purpose}': 'مەبەستی بەکارهێنان',
    '{grace_period}': 'ماوەی ڕێپێدان',
    '{late_fee}': 'غەرامەی دواکەوتن',
    '{total_price}': 'نرخی فرۆشتن',
    '{payment_method}': 'شێوازی پارەدان',
    '{delivery_date}': 'ڕێکەوتی تەسلیم',
    '{withdrawal}': 'بڕی پاشگەزبوونەوە',
    '{lawyer}': 'پارێزەر',
    // Each money token has a `_words` twin that spells the amount out, so a
    // signed figure cannot be altered afterwards. KURDISH ONLY: an Arabic
    // clause that uses one prints the token itself, because Arabic numerals
    // inflect and a wrong ending on a filed document is worse than none —
    // see functions/number_words.js. The currency is NOT included. The figure
    // goes in the brackets and the wording carries the sentence, as the office
    // writes it: «({total_price}) {total_price_words} {currency}» →
    // (٥٠٠,٠٠٠) پێنج سەد هەزار دیناری عێراقی.
    '{rent_amount_words}': 'بڕی کرێ بە نووسین',
    '{down_payment_words}': 'پێشەکی بە نووسین',
    '{guarantee_words}': 'بڕی دڵنیایی بە نووسین',
    '{late_fee_words}': 'غەرامەی دواکەوتن بە نووسین',
    '{total_price_words}': 'نرخی فرۆشتن بە نووسین',
    '{withdrawal_words}': 'بڕی پاشگەزبوونەوە بە نووسین',
  };

  // ---------------------------------------------------------------------------
  // Built-in default template
  // ---------------------------------------------------------------------------

  /// Headings a template may still carry from before a rename.
  ///
  /// A stored title always wins over the default, so a company that had ever
  /// saved its template kept the old wording forever. These are read as unset
  /// instead. Mirrored in `functions/contract_defaults.js` (LEGACY_TITLES),
  /// which the PDF renderer reads — both must list the same strings. Drop an
  /// entry once every template has been re-saved.
  static const List<String> legacyTitles = [
    'گرێبەستی کڕین و فرۆشتن',
    'عقد بيع وشراء',
  ];

  static ContractTemplate defaults() => const ContractTemplate(
        rentTitle: 'گرێبەستی کرێ',
        saleTitle: 'گرێبەستی فرۆشتن',
        primaryColorHex: '0F2C59',
        clauseFontSize: 16,
        receiptColorHex: '1E4D8B',
        receiptFontSize: 10,
        rentClauses: _defaultRentClauses,
        saleClauses: _defaultSaleClauses,
        rentTitleAr: 'عقد إيجار',
        saleTitleAr: 'عقد بيع',
        rentClausesAr: _defaultRentClausesAr,
        saleClausesAr: _defaultSaleClausesAr,
        rentTitleEn: 'Tenancy Agreement',
        saleTitleEn: 'Sale Agreement',
        rentClausesEn: _defaultRentClausesEn,
        saleClausesEn: _defaultSaleClausesEn,
      );

  static const List<String> _defaultRentClauses = [
    'لایەنی یەکەم ڕەزامەندە لەسەر بەکرێدانی موڵکی دیاریکراوی سەرەوە بە لایەنی دووەم بۆ ماوەی ({period_months}) مانگ.',
    'هەردوو لایەن ڕەزامەندن لەسەر کرێی مانگانە بە بڕی ({rent_amount}) {rent_amount_words} {currency}.',
    'ئەم گرێبەستە دەست پێدەکات لە بەرواری: {start_date} تاکو {end_date}.',
    'لایەنی دووەم بڕی ({down_payment}) {down_payment_words} دەداتە لایەنی یەکەم وەک پێشەکی {down_payment_months} مانگ و دوای پێشەکی کرێیەکە بەمشێوەیە دەدریێت: {payment_frequency} مانگ جارێک.',
    'لایەنی دووەم لەسەریەتی بڕی ({guarantee}) {guarantee_words} وەک دڵنیایی دابنێ لای {company}، کە لە دوای ڕادەستکردنەوەی موڵکەکە بە لایەنی یەکەم بێ هیچ کەم و کوڕییەک دەدرێتەوە بە لایەنی دووەم.',
    'لایەنی دووەم ئەم موڵکە بەکاردێنێت بۆ مەبەستی {purpose}، بە پێچەوانەوە بۆ هەر مەبەستێکی تر پێویستە ڕەزامەندی {company} و لایەنی یەکەم وەربگرێت.',
    'لایەنی دووەم بۆی نیە داوای کلیلی موڵکەکە بکات تا ڕێپێدانی ئاسایش وەرنەگرێت، گەر لە ماوەی {grace_period} ڕۆژ نەیتوانی ڕێپێدان لە لایەنی پەیوەندیدار وەربگرێت گرێبەستەکە ڕاستەوخۆ هەڵدەوەشێتەوە و پارەکان دەگەڕێتەوە بۆ لایەنی دووەم.',
    'لایەنی دووەم پێش ڕاخستنی (تاثیث) موڵکەکە پێویستە لەسەر ئەستۆی خۆی قوفڵی دەرگا دەرەکیەکان بگۆڕێت، بەپێچەوانەوە هەر کێشەیەک ڕووبدات خۆی بەرپرسیارە لێی.',
    'دوای تەواو بوونی ماوەی گرێبەستەکە ئەگەر لایەنی دووەم پابەند نەبوو بە چۆڵکردنی موڵکەکە یان نوێکردنەوەی ئەم گرێبەستە ئەوا پابەند دەکرێت بە دانێ بڕی ({late_fee}) {late_fee_words} {currency} بۆ هەر ڕۆژێک دواکەوتن، تاکوو گرێبەستەکە یەکلایی دەبێتەوە.',
    'خزمەتگوزاری ئاو کارەبا و هەرخزمەتگوزاریەکی تر پەیوەندی بەم موڵکە هەبێت لە ماوەی جێبەجێکردنی ئەم گرێبەستە لە ئەستۆی لایەنی دووەمە.',
    'هەر گۆڕانکاریەک لەبەشی دەرەوە و ناوەوەی ئەم موڵکە بکرێت دەبێ بەڕەزامەندی لایەنی یەکەم {company} بکرێت، وە لایەنی یەکەم تەنها لەو تێچووانە بەرپرسە کە ئەنجام دەدرێت لە چاککردنەوەی کەم و کوڕیەک یان گۆڕانکاریەکی پێویست لە موڵکەکەدا بە پێچەوانەوە هەر گۆڕانکاریەکی جوانکاری و ناپێویست بۆ موڵکەکە بکرێت دەکەوێتە ئەستۆی لایەنی دووەم.',
    'لایەنی دووەم بە هیچ شێوەیەک بۆی نیە ئەم موڵکە (هەمووی یان بەشێکی) بەکرێ بداتەوە لایەنی تر بە بێ ئاگادارکردنەوەی {company} و ڕەزامەندی لایەنی یەکەم.',
    'ئەگەر لایەنی یەکەم موڵکەکەی فرۆشت ئەوا لایەنی دووەم بۆی هەیە لە ناو موڵکەکەی بمێنێتەوە تا کۆتایی وادەی گرێبەستەکە، وە خاوەنە نوێیەکەش پابەند دەبێت بە ناوەڕۆکی ئەم گرێبەستە.',
    'ئەگەر لایەنی دووەم پێش کۆتایی هاتنی گرێبەستەکە زووتر دەرچوو لە موڵکەکە، {company} هاوکار دەبێ بۆ گێڕانەوەی (بەشێک یان هەموو) کرێی ماوەی چۆڵکردنی موڵکەکە، ئەگەر بەکرێدرایەوە لەلایەن {company}.',
    'ئەگەر موڵکەکە ڕاخراو (مؤثث) بوو ئەوا لەسەر لایەنی یەکەم پێویستە لیستی کەلوپەلەکانی ناو موڵکەکە ئامادە بکات وە لە لایەن لایەنی دووەم چێک بکرێتەوە و دواتر واژۆ بکرێت و هاوپێچ بکرێت بەم گرێبەستە.',
    'لایەنی دووەم پێویستە پارێزگاری لە کەلوپەلەکان بکات و لەکاتی دەرچوونی وەک خۆی ڕادەستی لایەنی یەکەمی بکاتەوە، بەپێچەوانەوە لایەنی دووەم بەرپرسە لە چاککردنەوە یان گۆڕینی لەسەر ئەرکی خۆی.',
    'لایەنی یەکەم دەبێت پێش بە کرێدانی موڵکەکە ئەستۆپاکی بۆ موڵکەکە بکات و پارەی کرێی ئاو و کارەبا هەر خزمەتگوزاریەکی تر بدات کە پەیوەندی بە موڵکەکە هەبێت، وە بەرپرسە لە چاککردنەوەی هەر کەم و کوڕیەک کە پەیوەندی بە ژێرخانی موڵکەکە بێت.',
    'لەکاتی هاتنی کرێیەکە پێویستە لایەنی یەکەم بە زووترین کات بێتە {company} و کرێیەکە وەربگرێت، بە پێچەوانەوە پارەکە دەخرێتە ناو حساب بانکی {company} دواتر بە چەک بۆی سەرف دەکرێت.',
    'هەریەک لە لایەنی یەکەم و دووەم پێویستە بڕی کرێی نیو مانگ بۆ هەر ساڵێک بدەن بە {company} لەجیاتی کرێی ڕێکخستنی ئەم گرێبەستە.',
    'لایەنی دووەم لەسەریەتی (مانگێک) پێش وادەی کۆتایی هاتنی گرێبەستەکە، ئاگاداری {company} بکاتەوە ئەگەر نیازی نوێکردنەوە یان چۆڵکردنی موڵکەکەی هەبوو، بە پێچەوانەوە کرێی (مانگێک) دەکەوێتە ئەستۆی لایەنی دووەم.',
    'پێش چۆڵکردنی موڵکەکە لایەنی دووەم لەسەریەتی چۆن موڵکەکەی وەرگرتووە وەک خۆی بێ کەم و کوڕی ڕادەستی لایەنی یەکەم بکاتەوە، بە پێچەوانەوە بەرپرسە لە چاکردنەوەی کەم و کوڕیەکان بە زووترین کات، وە ئەستۆپاکی بۆ موڵکەکە بکات و پارەی کرێی ئاو و کارەبا هەر خزمەتگوزاریەکی تر بدات کە پەیوەندی بە موڵکەکە هەبێت.',
    'دوای کۆتایی هاتنی وادەی گرێبەستەکە، ئەم گرێبەستە نوێ دەکرێتەوە بە نرخی ڕۆژ بە ڕەزامەندی هەردوولا بە نێوەندگیری {company} بۆ نرخ دانان و شێوازی کرێدانەکە، یان موڵکەکە چۆڵدەکرێت و ڕادەستی خاوەنەکەی دەکرێتەوە.',
    'لە کاتی نوێکردنەوەی گرێبەستەکە هەر یەکێک لە دوولایەنەکە پابەند دەبێت بە پێدانی کرێی نیو مانگ بۆ یەک ساڵ بە {company}.',
    'لەسەر لایەنی دووەم پێویستە موڵکەکە بۆ ئەو مەبەستە بەکاربهێنێت کە لەسەری ڕێکەوتوون، کە نەبێتە مایەی ئەزیەت و ئازار بۆ هاوسێیەکانی، بە پێچەوانەوە بەرپرسیار دەبێت بەرامبەر یاسا و گرێبەستەکە هەڵدەوەشێتەوە.',
    'لەکاتی چارەسەر نەبوونی کێشەی نێوان دوو لایەنەکە (ئەگەر هەبوو) {company} بەرپرس نیە و کێشەکە دەبردرێتە دادگا بۆ چارەسەرکردنی بە شاهێدی کارمەندانی بەرپرس.',
    'ئەگەر لایەنی یەکەم خۆی کڕیی وەرگرت لە کرێچی ئەوا {company} بەرپرس نیە لە هیچ جۆرە کێشەیەک.',
  ];

  static const List<String> _defaultSaleClauses = [
    'ئەم گرێبەستە ڕێکخرا بە مەبەستی فرؤشتنی موڵکی ئاماژە بۆکراوی سەرەوە کە خاوەنداریەکەی دەگەرێتەوە بۆ لایەنی یەکەم بە لایەنی دووەم بە نرخی ({total_price}) {total_price_words} {currency} بۆ ئەم مەبەستەش هەردوو لا ڕەزامەندی تەواوی خۆیان دەربڕی..',
    '{company} بڕی ({down_payment}) {down_payment_words} {currency} وەردەگرێت وەکو پێشەکی لە جیاتی لایەنی یەکەم.',
    'بڕی پارەی ماوە بەم شێوەی خوارەوە دەدرێت: {payment_method}',
    'لەسەر لایەنی یەکەم پێویستە ئەم موڵکە ڕادەستی لایەنی دووەم بکات لە ڕێکەوتی {delivery_date} دوای گەیشتنی بە شایستە داراییەکان.',
    'ئەگەر لایەنی یەکەم لە بەرواری دیاریکراودا ئەم موڵکەی ڕادەستی لایەنی دووەم نەکرد ئەوا دەبێت پابەند بێت بە پێدانی بڕی ({late_fee}) {late_fee_words} {currency} بۆ هەر ڕۆژ دواکەوتن.',
    'ئەگەر هاتوو هەر لایەنێک بە هەر هۆیەک پاشەگەزبێتەوە لەم گرێبەستە دەبێت پابەندبێت بە پێدانی بڕی ({withdrawal}) {withdrawal_words} {currency} بۆ لایەنەکەی تر بەبێ ئاگادار کردنەوەی لایەنی فەرمی.',
    'ڕسووماتی فرۆشتن و گواستنەوە و جیاکردنەوە و یەخستن و ڕاستکردنەوە و باجی خانووبەرە لەسەر لایەنی یەکەمە بیدات بەپێی یاسا ئەگەر تاپۆ بوو، وە ئەگەر تاپۆ نەبوو لایەنی یەکەم پابەندە بە پێدانی بڕی پارەی بەناوکردنی خۆی.',
    'ڕسووماتی کەشف و تۆماری عەقار دەکەوێتە سەر لایەنی دووەم بەگوێرەی یاسا ئەگەر تاپۆ بوو، وە ئەگەر تاپۆ نەبوو لایەنی دووەم پابەندە بە بڕی پارەی بەناوکردن.',
    'لەسەر لایەنی یەکەم پێویستە دەسەڵات بدات بە پارێزەر {lawyer} بە بریکارنامەی تایبەت بەم موڵکە لە فەرمانگەی دادنووس بە مەبەستی ڕایکردنی مامەڵەکان و بەناوکردنی لە بەڕیوبەرایەتی تۆماری خانووبەرە بۆ لایەنی دووەم.',
    'لەسەر لایەنی یەکەم پێویستە بڕی ٪١ لە نرخی ئەم موڵکەی سەرەوە بدات بە {company} لە بەرامبەر فرۆشتنی ئەم موڵکە.',
    'لەسەر لایەنی دووەم پێویستە بڕی ٪١ لە نرخی ئەم موڵکەی سەرەوە بدات بە {company} لە بەرامبەر کڕینی ئەم موڵکە.',
  ];

  // ---------------------------------------------------------------------------
  // Arabic edition — DRAFT translation, pending review by the company's lawyer.
  //
  // Clause order and {token} placement mirror the Kurdish lists above line for
  // line, so the two editions can be compared side by side. Kept byte-identical
  // to RENT_CLAUSES_AR / SALE_CLAUSES_AR in functions/contract_defaults.js —
  // the server renders from its own copy, so the two must not drift.
  // ---------------------------------------------------------------------------

  static const List<String> _defaultRentClausesAr = [
    'يوافق الطرف الأول على تأجير العقار الموصوف أعلاه إلى الطرف الثاني لمدة ({period_months}) شهراً.',
    'اتفق الطرفان على أن يكون بدل الإيجار الشهري مبلغ {rent_amount} {currency}.',
    'يبدأ سريان هذا العقد من تاريخ: {start_date} ولغاية {end_date}.',
    'يدفع الطرف الثاني إلى الطرف الأول مبلغ {down_payment} كمقدَّم عن ({down_payment_months}) شهراً، وبعد المقدَّم يُدفع الإيجار كل ({payment_frequency}) شهراً.',
    'على الطرف الثاني أن يودع مبلغ {guarantee} لدى {company} كتأمينات، تُعاد إليه بعد تسليم العقار إلى الطرف الأول خالياً من أي نقص أو ضرر.',
    'يستخدم الطرف الثاني هذا العقار لغرض {purpose}، وأي استخدام لغير هذا الغرض يستوجب موافقة {company} والطرف الأول.',
    'ليس للطرف الثاني المطالبة بمفاتيح العقار قبل حصوله على موافقة الأمن، وإذا لم يتمكن من الحصول على الموافقة خلال {grace_period} يوماً يُفسخ العقد تلقائياً وتُعاد المبالغ إلى الطرف الثاني.',
    'على الطرف الثاني قبل تأثيث العقار تبديل أقفال الأبواب الخارجية على نفقته الخاصة، وبخلافه يتحمل مسؤولية أي مشكلة تحدث.',
    'بعد انتهاء مدة العقد، إذا لم يلتزم الطرف الثاني بإخلاء العقار أو تجديد هذا العقد، يلتزم بدفع مبلغ {late_fee} {currency} عن كل يوم تأخير لحين حسم العقد.',
    'تقع خدمات الماء والكهرباء وأي خدمة أخرى تتعلق بهذا العقار خلال مدة تنفيذ هذا العقد على عاتق الطرف الثاني.',
    'أي تغيير في القسم الخارجي أو الداخلي من هذا العقار يجب أن يتم بموافقة الطرف الأول و{company}، ولا يتحمل الطرف الأول إلا التكاليف الناشئة عن إصلاح نقص أو تغيير ضروري في العقار، أما أي تغيير تجميلي أو غير ضروري فيقع على عاتق الطرف الثاني.',
    'لا يحق للطرف الثاني بأي شكل من الأشكال تأجير هذا العقار (كله أو جزء منه) إلى طرف آخر دون إشعار {company} وموافقة الطرف الأول.',
    'إذا باع الطرف الأول العقار، يحق للطرف الثاني البقاء في العقار حتى نهاية مدة العقد، ويلتزم المالك الجديد بمضمون هذا العقد.',
    'إذا أخلى الطرف الثاني العقار قبل انتهاء مدة العقد، تساعد {company} في إعادة (جزء أو كل) إيجار المدة المتبقية بعد إخلاء العقار، إذا أُعيد تأجيره من قبل {company}.',
    'إذا كان العقار مؤثثاً، فعلى الطرف الأول إعداد قائمة بمحتويات العقار، يدققها الطرف الثاني ثم توقَّع وتُرفق بهذا العقد.',
    'على الطرف الثاني المحافظة على المحتويات وتسليمها إلى الطرف الأول عند الإخلاء كما استلمها، وبخلافه يكون مسؤولاً عن إصلاحها أو تبديلها على نفقته.',
    'على الطرف الأول قبل تأجير العقار تسوية ذمة العقار ودفع أجور الماء والكهرباء وأي خدمة أخرى تتعلق بالعقار، ويكون مسؤولاً عن إصلاح أي نقص يتعلق ببنية العقار.',
    'عند حلول موعد الإيجار، على الطرف الأول الحضور إلى {company} في أقرب وقت لاستلام بدل الإيجار، وبخلافه يُودع المبلغ في الحساب المصرفي لـ{company} ثم يُصرف له بصك.',
    'على كل من الطرف الأول والطرف الثاني دفع بدل نصف شهر عن كل سنة إلى {company} مقابل أجور تنظيم هذا العقد.',
    'على الطرف الثاني إشعار {company} قبل (شهر) من موعد انتهاء العقد برغبته في التجديد أو إخلاء العقار، وبخلافه يتحمل الطرف الثاني بدل إيجار (شهر).',
    'قبل إخلاء العقار، على الطرف الثاني تسليمه إلى الطرف الأول كما استلمه دون نقص، وبخلافه يكون مسؤولاً عن إصلاح النواقص في أقرب وقت، وعليه تسوية ذمة العقار ودفع أجور الماء والكهرباء وأي خدمة أخرى تتعلق بالعقار.',
    'بعد انتهاء مدة العقد، يُجدَّد هذا العقد بسعر اليوم بموافقة الطرفين وبوساطة {company} في تحديد السعر وطريقة الدفع، أو يُخلى العقار ويُسلَّم إلى مالكه.',
    'عند تجديد العقد يلتزم كل من الطرفين بدفع بدل إيجار نصف شهر عن سنة واحدة إلى {company}.',
    'على الطرف الثاني استخدام العقار للغرض المتفق عليه، وبما لا يسبب أذى أو إزعاجاً لجيرانه، وبخلافه يكون مسؤولاً أمام القانون ويُفسخ العقد.',
    'في حال عدم حل الخلاف بين الطرفين (إن وُجد)، لا تتحمل {company} أي مسؤولية، ويُحال الخلاف إلى المحكمة لحسمه بشهادة الموظفين المسؤولين.',
    'إذا استلم الطرف الأول بدل الإيجار من المستأجر بنفسه، فلا تتحمل {company} أي مسؤولية عن أي مشكلة.',
  ];

  static const List<String> _defaultSaleClausesAr = [
    'أُبرم هذا العقد لغرض بيع العقار المشار إليه أعلاه، والعائدة ملكيته إلى الطرف الأول، إلى الطرف الثاني بمبلغ {total_price} {currency}، وقد أبدى الطرفان موافقتهما التامة على ذلك.',
    'تستلم {company} مبلغ {down_payment} {currency} كعربون نيابة عن الطرف الأول.',
    'يُدفع المبلغ المتبقي وفق الآتي: {payment_method}',
    'على الطرف الأول تسليم هذا العقار إلى الطرف الثاني بتاريخ {delivery_date} بعد استيفائه المستحقات المالية.',
    'إذا لم يسلّم الطرف الأول العقار إلى الطرف الثاني في التاريخ المحدد، يلتزم بدفع مبلغ {late_fee} {currency} عن كل يوم تأخير.',
    'إذا نكل أي من الطرفين عن هذا العقد لأي سبب، يلتزم بدفع مبلغ {withdrawal} {currency} إلى الطرف الآخر دون حاجة إلى إنذار رسمي.',
    'رسوم البيع والتسجيل والإفراز والدمج والتصحيح وضريبة العقار تقع على الطرف الأول وفق القانون إذا كان العقار مسجلاً في الطابو، وإن لم يكن مسجلاً يلتزم الطرف الأول بدفع بدل تسجيله بإسمه.',
    'رسوم الكشف وتسجيل العقار تقع على الطرف الثاني وفق القانون إذا كان العقار مسجلاً في الطابو، وإن لم يكن مسجلاً يلتزم الطرف الثاني بدفع بدل التسجيل.',
    'على الطرف الأول تخويل المحامي {lawyer} بوكالة خاصة بهذا العقار لدى دائرة الكاتب العدل لغرض متابعة المعاملات وتسجيله بإسم الطرف الثاني لدى مديرية التسجيل العقاري.',
    'على الطرف الأول دفع ما نسبته ١٪ من سعر العقار الموصوف أعلاه إلى {company} مقابل بيع هذا العقار.',
    'على الطرف الثاني دفع ما نسبته ١٪ من سعر العقار الموصوف أعلاه إلى {company} مقابل شراء هذا العقار.',
  ];

  // ---------------------------------------------------------------------------
  // English edition. GENERATED from functions/contract_defaults.js — the two
  // copies must stay verbatim-identical, so edit there and regenerate rather
  // than retyping here.
  // ---------------------------------------------------------------------------

  static const List<String> _defaultRentClausesEn = [
    'The first party agrees to let the property described above to the second party for a term of ({period_months}) months.',
    'Both parties agree a monthly rent of ({rent_amount}) {rent_amount_words} {currency}.',
    'This contract runs from {start_date} until {end_date}.',
    'The second party pays ({down_payment}) {down_payment_words} to the first party in advance for {down_payment_months} months; thereafter the rent is paid every {payment_frequency} months.',
    'The second party shall lodge ({guarantee}) {guarantee_words} with {company} as a deposit, returnable to the second party once the property has been handed back to the first party in good order.',
    'The second party shall use the property for {purpose}. Any other use requires the consent of {company} and of the first party.',
    'The second party may not ask for the keys before security clearance has been granted. If clearance cannot be obtained from the authority concerned within {grace_period} days, this contract is dissolved forthwith and the monies are returned to the second party.',
    'Before furnishing the property, the second party shall change the locks on the external doors at their own cost; failing that, they are answerable for anything that follows.',
    'If, at the end of the term, the second party neither vacates the property nor renews this contract, they shall pay ({late_fee}) {late_fee_words} {currency} for each day of delay until the matter is settled.',
    'Water, electricity and any other service connected to the property are the second party\'s charge for the duration of this contract.',
    'Any alteration to the property, inside or out, requires the consent of the first party and of {company}. The first party bears only the cost of repairing a defect or of a change the property requires; any decorative or unnecessary change is at the second party\'s cost.',
    'The second party may not sublet the property, in whole or in part, without notice to {company} and the consent of the first party.',
    'If the first party sells the property, the second party may remain until the end of the term, and the new owner is bound by this contract.',
    'If the second party leaves before the term ends, {company} will assist in recovering part or all of the rent for the unoccupied period, should the property be let again through {company}.',
    'If the property is furnished, the first party shall draw up an inventory of its contents, to be checked by the second party, signed, and attached to this contract.',
    'The second party shall keep the contents in good order and return them as received on leaving; failing that, the second party bears the cost of repair or replacement.',
    'Before letting the property, the first party shall clear it of any liability and settle the water, electricity and other service accounts attaching to it, and is answerable for repairing any defect in the fabric of the property.',
    'When the rent falls due, the first party shall attend {company} promptly to collect it; failing that, the sum is paid into {company}\'s bank account and released to them by cheque.',
    'The first party and the second party shall each pay {company} half a month\'s rent for each year, as the fee for arranging this contract.',
    'The second party shall give {company} one month\'s notice before the end of the term of an intention to renew or to vacate; failing that, one month\'s rent falls to the second party.',
    'Before vacating, the second party shall return the property to the first party as received and in good order; failing that, they are answerable for putting right any defect without delay, and shall clear the property of liability and settle the water, electricity and other service accounts attaching to it.',
    'At the end of the term this contract may be renewed at the rate of the day, by agreement of both parties and with {company} mediating on the rent and the manner of payment; otherwise the property is vacated and returned to its owner.',
    'On renewal, each of the two parties shall pay {company} half a month\'s rent for the year.',
    'The second party shall use the property for the purpose agreed, and in a manner that causes no harm or nuisance to the neighbours; failing that, they answer before the law and this contract is dissolved.',
    'Should a dispute between the two parties not be settled, {company} bears no responsibility, and the matter goes to court to be decided on the testimony of the responsible staff.',
    'If the first party collects the rent from the tenant directly, {company} bears no responsibility for any difficulty arising.',
  ];

  static const List<String> _defaultSaleClausesEn = [
    'This contract is made for the sale of the property described above, owned by the first party, to the second party at a price of ({total_price}) {total_price_words} {currency}, to which both parties have given their full consent.',
    '{company} receives ({down_payment}) {down_payment_words} {currency} as a deposit on behalf of the first party.',
    'The balance is paid as follows: {payment_method}',
    'The first party shall hand the property to the second party on {delivery_date}, once the sums due have been received.',
    'If the first party does not hand the property to the second party on the date set, they shall pay ({late_fee}) {late_fee_words} {currency} for each day of delay.',
    'If either party withdraws from this contract for any reason, they shall pay ({withdrawal}) {withdrawal_words} {currency} to the other party, without need of formal notice.',
    'The fees for sale, transfer, partition, merger, correction and property tax fall to the first party under the law where the property is registered; where it is not registered, the first party shall pay the cost of registering it in their own name.',
    'The fees for survey and registration fall to the second party under the law where the property is registered; where it is not registered, the second party shall pay the cost of registration.',
    'The first party shall grant the lawyer {lawyer} a special power of attorney for this property before the notary public, for the purpose of pursuing the formalities and registering it in the name of the second party at the land registry.',
    'The first party shall pay {company} 1% of the price of the property described above, for the sale of this property.',
    'The second party shall pay {company} 1% of the price of the property described above, for the purchase of this property.',
  ];

}
