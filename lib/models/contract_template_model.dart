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
  });

  final List<String> rentClauses;
  final List<String> saleClauses;
  final String rentTitle;
  final String saleTitle;

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

    return ContractTemplate(
      rentClauses: list('rent_clauses', d.rentClauses),
      saleClauses: list('sale_clauses', d.saleClauses),
      rentTitle: str('rent_title', d.rentTitle),
      saleTitle: str('sale_title', d.saleTitle),
      primaryColorHex: str('primary_color', d.primaryColorHex),
      clauseFontSize: (json['clause_font_size'] as num?)?.toDouble() ??
          d.clauseFontSize,
      receiptColorHex: str('receipt_color', d.receiptColorHex),
      receiptFontSize: (json['receipt_font_size'] as num?)?.toDouble() ??
          d.receiptFontSize,
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
    '{property_number}': 'ژمارەی عەقار',
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
  };

  // ---------------------------------------------------------------------------
  // Built-in default template
  // ---------------------------------------------------------------------------

  static ContractTemplate defaults() => const ContractTemplate(
        rentTitle: 'گرێبەستی کرێ',
        saleTitle: 'گرێبەستی کڕین و فرۆشتن',
        primaryColorHex: '0F2C59',
        clauseFontSize: 16,
        receiptColorHex: '1E4D8B',
        receiptFontSize: 10,
        rentClauses: _defaultRentClauses,
        saleClauses: _defaultSaleClauses,
      );

  static const List<String> _defaultRentClauses = [
    'لایەنی یەکەم ڕەزامەندە لەسەر بەکرێدانی ئەم موڵکەی سەرەوە بە لایەنی دووەم بۆ ماوەی ({period_months}) مانگ.',
    'هەردوو لایەن ڕەزامەندن لەسەر کرێی مانگانە بە بڕی {rent_amount} {currency}.',
    'ئەم گرێبەستە دەست پێدەکات لە بەرواری: {start_date} تاکو {end_date}.',
    'لایەنی دووەم بڕی {down_payment} دەداتە لایەنی یەکەم وەک پێشەکی {down_payment_months} مانگ و دوای پێشەکی کرێیەکە بەمشێوەیە دەدریێت: {payment_frequency} مانگ جارێک.',
    'لایەنی دووەم لەسەریەتی بڕی {guarantee} وەک دڵنیایی دابنێ لای {company}، ئەم بڕە پارەیە دەگەڕێتەوە بۆ لایەنی دووەم دوای ڕادەستکردنی موڵکەکە بێ هیچ کەم و کوڕییەک.',
    'لایەنی دووەم ئەم موڵکە بەکاردێنێت بۆ مەبەستی {purpose}، بە پێچەوانەوە بۆ هەر مەبەستێکی تر پێویستە ئاگاداری {company} و ڕەزامەندی لایەنی یەکەم بە نوسراوێک وەربگرێت.',
    'لایەنی دووەم بۆی نیە داوای کلیلی موڵکەکە بکات بۆ هەر مەبەستێک بێت تا ڕێپێدان لە لایەنی پەیوەندیدار یان ئاسایش وەرنەگرێت، گەر لە ماوەی {grace_period} ڕۆژ نەیتوانی ڕێپێدان لە لایەنی پەیوەندیدار وەربگرێت گرێبەستەکە ڕاستەوخۆ هەڵدەوەشێتەوە و پارەکان دەگەڕێتەوە بۆ لایەنی دووەم.',
    'لایەنی دووەم پێش ڕاخراوکردنی (تاثیث) موڵکەکە پێویستە لەسەر ئەستۆی خۆی قوفڵی دەرگا دەرەکیەکان بگۆڕێت، بەپێچەوانەوە هەر کێشەیەک ڕووبدات خۆی بەرپرسیارە لێی.',
    'لایەنی دووەم پابەند دەبێت بە پێدانی کرێیەکە (٧) ڕۆژ پێش ڕێکەوتی دیاریکراو، وە ئەگەر (٧) ڕۆژ لە وادەی دیاریکراو دواکەوت ئەوا لایەنی دووەم بەرپرسیار دەبێت بەرامبەر یاسا.',
    'دوای تەواوبوونی ماوەی گرێبەستەکە ئەگەر لایەنی دووەم پابەند نەبێ بە چۆڵکردنی یان نوێکردنەوەی ئەم گرێبەستە ئەوا کرێی موڵکەکە دەبێت ڕۆژانە بە بڕی {late_fee} بۆ هەر ڕۆژێک تا یەکلا دەبێتەوە.',
    'خزمەتگوزاری پڕۆژە و شارەوانی و کارەبا و ئاو و هەر خزمەتگوزاریەکی تر هەبێت لە ماوەی ئەم گرێبەستە لە ئەستۆی لایەنی دووەمە.',
    'ئەگەر لایەنی دووەم بیەوێت هەر جۆرە گۆڕانکاریەک لە دەرەوە یان ناوەوەی ئەم موڵکە بکات پێویستە بە ئاگاداری {company} و ڕەزامەندی لایەنی یەکەم بێت، وە بە نوسراوێک گۆڕانکاریەکان دیاری بکرێت و بۆی نیە داوای گەڕانەوەی تێچووی گۆڕانکاریەکان بکات لە لایەنی یەکەم دوای دەرچوون.',
    'لایەنی دووەم بە هیچ شێوەیەک بۆی نیە ئەم موڵکە (هەمووی یان بەشێکی) بەکرێ بداتەوە لایەنی تر بە بێ ئاگادارکردنەوەی {company} و ڕەزامەندی لایەنی یەکەم.',
    'ئەگەر لایەنی یەکەم موڵکەکەی فرۆشت ئەوا لایەنی دووەم بۆی هەیە لە ناو موڵکەکەی بمێنێتەوە تا کۆتایی وادەی گرێبەستەکە، وە خاوەنە نوێیەکەش پابەند دەبێت بە ناوەڕۆکی ئەم گرێبەستە.',
    'ئەگەر لایەنی دووەم پێش کۆتایی هاتنی گرێبەستەکە زووتر دەرچوو لە موڵکەکە، {company} هاوکار دەبێ بۆ گێڕانەوەی (بەشێک یان هەموو) کرێی ماوەی چۆڵکردنی موڵکەکە، ئەگەر بەکرێدرایەوە لەلایەن {company}.',
    '{company} هاوکار دەبێت (نەک بەرپرس) لە نێوان هەردوولایەن لە ماوەی گرێبەستەکە بۆ بەردەوام بوون و مانەوەیان و چارەسەرکردنی کێشە ئەگەر هەبوو.',
    'ئەگەر موڵکەکە ڕاخراو بوو (مؤثث) لەسەر هەردوولا پێویستە کەل و پەلەکان ئەژمار بکەن (جرد) و وێنەی بگرن هاوپێچی گرێبەستەکە بکرێت بۆ بەرچاو ڕوونی هەردوولا، و لایەنی دووەم پێویستە پارێزگاری لە کەلوپەلەکان بکات و لەکاتی دەرچوونی وەک خۆی ڕادەستی لایەنی یەکەمی بکاتەوە، بەپێچەوانەوە لایەنی دووەم بەرپرسە لە چاککردنەوە یان گۆڕینی لەسەر ئەرکی خۆی.',
    'لایەنی یەکەم لەسەریەتی پارەی کارەبای حکومی و ئەهلی و خزمەتگوزاریەکان بدات و ئەستۆی پاکی بکات پێش بەکرێدان و بەرپرسە لە چاککردنەوەی هەر کەم و کوڕیەک کە پەیوەندی بە ژێرخانی موڵکەکە بێت.',
    'لەکاتی هاتنی کرێیەکە پێویستە لایەنی یەکەم بە زووترین کات بێتە {company} و کرێیەکە وەربگرێت، بە پێچەوانەوە پارەکە دەخرێتە ناو حساب بانکی {company} دواتر بە چەک بۆی سەرف دەکرێت.',
    'هەریەک لە لایەنی یەکەم و دووەم پێویستە بڕی کرێی نیو مانگ بۆ هەر ساڵێک بدەن بە {company} لەجیاتی کرێی ڕێکخستنی ئەم گرێبەستە.',
    'لایەنی دووەم لەسەریەتی (مانگێک) پێش وادەی کۆتایی هاتنی گرێبەستەکە، ئاگاداری {company} بکاتەوە ئەگەر نیازی نوێکردنەوە یان چۆڵکردنی موڵکەکەی هەبوو، بە پێچەوانەوە کرێی (مانگێک) دەکەوێتە ئەستۆی لایەنی دووەم.',
    'لەکاتی چۆڵکردن لایەنی دووەم لەسەریەتی چۆن موڵکەکەی وەرگرتووە وەک خۆی بێ کەم و کوڕی ڕادەستی لایەنی یەکەم بکاتەوە، بە پێچەوانەوە بەرپرسە لە چاکردنەوەی کەم و کوڕیەکان بە زووترین کات و پابەندە بە پێدانی پارەی کارەبای نیشتیمانی لەگەڵ هاتنی پسوولەی کارەبا یان سەردانی فەرمانگەی کارەبای نیشتیمانی بکات و پابەندە بە پێدانی پارەی خزمەت گوزاری تا بەرواری چۆڵکردن.',
    'دوای کۆتایی هاتنی وادەی گرێبەستەکە، ئەم گرێبەستە نوێ دەکرێتەوە بە نرخی ڕۆژ بە ڕەزامەندی هەردوولا بە نێوەندگیری {company} بۆ نرخ دانان و شێوازی کرێدانەکە، یان موڵکەکە چۆڵدەکرێت و ڕادەستی خاوەنەکەی دەکرێتەوە.',
    'لە کاتی نوێکردنەوەی گرێبەستەکە هەر یەکێک لە دوولایەنەکە پابەند دەبێت بە پێدانی کرێی نیو مانگ بۆ یەک ساڵ بە {company}.',
    'لەسەر لایەنی دووەم پێویستە موڵکەکە بۆ ئەو مەبەستە بەکاربهێنێت کە لەسەری ڕێکەوتوون، کە نەبێتە مایەی ئەزیەت و ئازار بۆ هاوسێیەکانی، بە پێچەوانەوە بەرپرسیار دەبێت بەرامبەر یاسا و گرێبەستەکە هەڵدەوەشێتەوە.',
    'لەکاتی چارەسەر نەبوونی کێشەی نێوان دوو لایەنەکە (ئەگەر هەبوو) {company} بەرپرس نیە و کێشەکە دەبردرێتە دادگا بۆ چارەسەرکردنی بە شاهێدی کارمەندانی بەرپرس.',
    'ئەگەر لایەنی یەکەم خۆی کڕیی وەرگرت لە کرێچی ئەوا {company} بەرپرس نیە لە هیچ جۆرە کێشەیەک.',
  ];

  static const List<String> _defaultSaleClauses = [
    'لایەنی یەکەم {party1} ڕەزامەندە لەسەر فرۆشتنی ئەم موڵکەی سەرەوە بە لایەنی دووەم بە نرخی {total_price} {currency}.',
    'لایەنی دووەم {party2} ڕەزامەندە لەسەر کڕینی ئەم موڵکەی سەرەوە بە نرخی {total_price} {currency}.',
    '{company} بڕی {down_payment} {currency} وەردەگرێت وەکو پێشەکی لە جیاتی لایەنی یەکەم.',
    'بڕی پارەی ماوە بەم شێوەی خوارەوە دەدرێت: {payment_method}',
    'لەسەر لایەنی یەکەم پێویستە ئەم موڵکە ڕادەستی لایەنی دووەم بکات لە ڕێکەوتی {delivery_date} دوای گەیشتنی بە شایستە داراییەکان.',
    'ئەگەر لایەنی یەکەم لە بەرواری دیاریکراودا ئەم موڵکەی ڕادەستی لایەنی دووەم نەکرد ئەوا دەبێت پابەند بێت بە پێدانی بڕی {late_fee} {currency} بۆ هەر ڕۆژ دواکەوتن.',
    'ئەگەر هاتوو هەر لایەنێک بە هەر هۆیەک پاشەگەزبێتەوە لەم گرێبەستە دەبێت پابەندبێت بە پێدانی بڕی {withdrawal} {currency} بۆ لایەنەکەی تر بەبێ ئاگادار کردنەوەی لایەنی فەرمی.',
    'ڕسووماتی فرۆشتن و گواستنەوە و جیاکردنەوە و یەخستن و ڕاستکردنەوە و باجی خانووبەرە لەسەر لایەنی یەکەمە بیدات بەپێی یاسا ئەگەر تاپۆ بوو، وە ئەگەر تاپۆ نەبوو لایەنی یەکەم پابەندە بە پێدانی بڕی پارەی بەناوکردنی خۆی.',
    'ڕسووماتی کەشف و تۆماری عەقار دەکەوێتە سەر لایەنی دووەم بەگوێرەی یاسا ئەگەر تاپۆ بوو، وە ئەگەر تاپۆ نەبوو لایەنی دووەم پابەندە بە بڕی پارەی بەناوکردن.',
    'لەسەر لایەنی یەکەم پێویستە دەسەڵات بدات بە پارێزەر {lawyer} بە بریکارنامەی تایبەت بەم موڵکە لە فەرمانگەی دادنووس بە مەبەستی ڕایکردنی مامەڵەکان و بەناوکردنی لە بەڕیوبەرایەتی تۆماری خانووبەرە بۆ لایەنی دووەم.',
    'لەسەر لایەنی یەکەم پێویستە قەرزی کارەبا و هەر خزمەتگوزاریەک لەسەر ئەم موڵکە هەبێت پاک بکاتەوە تا بەرواری ڕادەست کردنی موڵکەکە.',
    'لەسەر لایەنی یەکەم پێویستە بڕی ٪١ لە نرخی ئەم موڵکەی سەرەوە بدات بە {company} لە بەرامبەر فرۆشتنی ئەم موڵکە.',
    'لەسەر لایەنی دووەم پێویستە بڕی ٪١ لە نرخی ئەم موڵکەی سەرەوە بدات بە {company} لە بەرامبەر کڕینی ئەم موڵکە.',
  ];
}
