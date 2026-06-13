import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/company_model.dart';
import '../../models/contract_model.dart';
import '../../models/enums.dart';

/// On-device PDF generator for contracts.
///
/// * RTL (Kurdish/Arabic) is forced via [pw.Directionality] + the SPEDA `.ttf`.
/// * Dynamic form data is mixed with static, hardcoded legal clauses.
/// * Uses the `printing` package to print over Wi-Fi or share the file.
class ContractPdfService {
  // Cache the parsed fonts so we don't re-read the asset for every contract.
  static pw.Font? _regular;
  static pw.Font? _bold;

  static final _money = NumberFormat.decimalPattern();
  static final _date = DateFormat('yyyy/MM/dd');

  /// Loads the PDF fonts bundled in assets (once). Vazirmatn is used for the
  /// PDF because it covers Kurdish/Arabic and subsets cleanly — the SPEDA file
  /// crashes the pdf package's TTF subsetter. (The app UI still uses SPEDA.)
  static Future<void> _ensureFonts() async {
    if (_regular != null && _bold != null) return;
    final reg = await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf');
    _regular = pw.Font.ttf(reg);
    _bold = pw.Font.ttf(bold);
  }

  /// Builds the PDF bytes for any contract. Pass [company] to render the
  /// branded header (logo, name, phones, address).
  static Future<Uint8List> build(Contract contract, {Company? company}) async {
    await _ensureFonts();

    // Fetch the logo image once. A hanging/offline fetch must not block the
    // print dialog forever, so we time out and degrade gracefully to no logo.
    pw.ImageProvider? logo;
    if (company != null && company.logoUrl.isNotEmpty) {
      try {
        logo = await networkImage(company.logoUrl)
            .timeout(const Duration(seconds: 6));
      } catch (_) {
        logo = null;
      }
    }

    final theme = pw.ThemeData.withFont(
      base: _regular!,
      bold: _bold!,
      fontFallback: [pw.Font.helvetica()],
    );

    final doc = pw.Document(theme: theme);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl, // whole document is RTL
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _header(contract, company, logo),
        footer: (ctx) => _footer(ctx),
        build: (ctx) => switch (contract) {
          RentContract r => _rentContent(r, company),
          SaleContract s => _saleContent(s),
        },
      ),
    );

    return doc.save();
  }

  /// Sends the contract straight to a printer (Wi-Fi / system print dialog).
  static Future<void> printContract(Contract contract, {Company? company}) async {
    final bytes = await build(contract, company: company);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  /// Opens the OS share sheet (save / send via WhatsApp, email, etc.).
  static Future<void> shareContract(Contract contract, {Company? company}) async {
    final bytes = await build(contract, company: company);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'contract_${contract.id}.pdf',
    );
  }

  // ----------------------------- sections -----------------------------

  static pw.Widget _header(
    Contract contract,
    Company? company,
    pw.ImageProvider? logo,
  ) {
    final title = contract.type == ContractType.rent
        ? 'گرێبەستی کرێ'
        : 'گرێبەستی فرۆشتن';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (company != null) _companyBand(company, logo),
        if (company != null) pw.SizedBox(height: 6),
        pw.Text(
          title,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Divider(thickness: 1.2),
      ],
    );
  }

  /// Branded company strip: company name in all 3 languages on the right
  /// (RTL start), logo on the left.
  static pw.Widget _companyBand(Company company, pw.ImageProvider? logo) {
    final names = [company.nameKu, company.nameAr, company.nameEn]
        .where((n) => n.isNotEmpty)
        .toList();
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (final n in names)
                pw.Text(n,
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
        if (logo != null)
          pw.Container(
            width: 56,
            height: 56,
            margin: const pw.EdgeInsets.only(right: 10),
            child: pw.Image(logo, fit: pw.BoxFit.contain),
          ),
      ],
    );
  }

  static pw.Widget _footer(pw.Context ctx) => pw.Container(
        alignment: pw.Alignment.center,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          'لاپەڕە ${ctx.pageNumber} لە ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      );

  // ----------------------------- SALE -----------------------------
  static List<pw.Widget> _saleContent(SaleContract s) => [
        _partiesSection(s),
        pw.SizedBox(height: 12),
        _saleBody(s),
        pw.SizedBox(height: 18),
        _legalClauses(s),
        pw.SizedBox(height: 30),
        _signatures(),
      ];

  // ----------------------------- RENT -----------------------------
  static List<pw.Widget> _rentContent(RentContract c, Company? company) {
    return [
      _card('زانیاری گرێبەست', [
        _row('ژمارەی گرێبەست:', '${c.contractNumber}'),
        _row('لایەنی یەکەم (خاوەن موڵک):', c.party1Name),
        _row('لایەنی دووەم (کرێچی):', c.party2Name),
        _row('جۆری موڵک:', c.propertyType),
        _row('پڕۆژە / گەڕەک:', c.projectName),
        _row('ژمارەی عەقار:', c.propertyNumber),
        _row('ڕووبەر:', '${c.area} م²'),
      ]),
      pw.SizedBox(height: 12),
      pw.Text('هەردوو لایەن ڕێکەوتن لەسەر ئەم خاڵانەی خوارەوە:',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
      pw.SizedBox(height: 4),
      pw.Text('بەندەکان:',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
      pw.SizedBox(height: 6),
      ..._rentClauses(c, company).asMap().entries.map(
            (e) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Text('${e.key + 1}- ${e.value}',
                  textAlign: pw.TextAlign.justify,
                  style: const pw.TextStyle(fontSize: 11, lineSpacing: 2)),
            ),
          ),
      if (c.notes.trim().isNotEmpty) ...[
        pw.SizedBox(height: 8),
        pw.Text('تێبینی: ${c.notes}',
            style: const pw.TextStyle(fontSize: 11)),
      ],
      pw.SizedBox(height: 30),
      _rentSignatures(c),
    ];
  }

  /// The 27 rent clauses with placeholders filled. `companyname` uses the
  /// company's Kurdish name.
  static List<String> _rentClauses(RentContract c, Company? company) {
    final cn = company?.nameKu ?? 'کۆمپانیا';
    final cur = c.currency.label;
    String m(num v) => _money.format(v);
    return [
      'لایەنی یەکەم ڕەزامەندە لەسەر بەکرێدانی ئەم موڵکەی سەرەوە بە لایەنی دووەم بۆ ماوەی (${c.rentalPeriodMonths}) مانگ.',
      'هەردوو لایەن ڕەزامەندن لەسەر کرێی مانگانە بە بڕی ${m(c.rentAmount)} $cur.',
      'ئەم گرێبەستە دەست پێدەکات لە بەرواری: ${_date.format(c.startDate)} تاکو ${_date.format(c.handoverDate)}.',
      'لایەنی دووەم بڕی ${m(c.downPayment)} دەداتە لایەنی یەکەم وەک پێشەکی ${c.downPaymentMonths} مانگ و دوای پێشەکی کرێیەکە بەمشێوەیە دەدریێت: ${c.paymentFrequencyMonths} مانگ جارێک.',
      'لایەنی دووەم لەسەریەتی بڕی ${m(c.guaranteeAmount)} وەک دڵنیایی دابنێ لای $cn، ئەم بڕە پارەیە دەگەڕێتەوە بۆ لایەنی دووەم دوای ڕادەستکردنی موڵکەکە بێ هیچ کەم و کوڕییەک.',
      'لایەنی دووەم ئەم موڵکە بەکاردێنێت بۆ مەبەستی ${c.rentalPurpose}، بە پێچەوانەوە بۆ هەر مەبەستێکی تر پێویستە ئاگاداری $cn و ڕەزامەندی لایەنی یەکەم بە نوسراوێک وەربگرێت.',
      'لایەنی دووەم بۆی نیە داوای کلیلی موڵکەکە بکات بۆ هەر مەبەستێک بێت تا ڕێپێدان لە لایەنی پەیوەندیدار یان ئاسایش وەرنەگرێت، گەر لە ماوەی ${c.gracePeriod} ڕۆژ نەیتوانی ڕێپێدان لە لایەنی پەیوەندیدار وەربگرێت گرێبەستەکە ڕاستەوخۆ هەڵدەوەشێتەوە و پارەکان دەگەڕێتەوە بۆ لایەنی دووەم.',
      'لایەنی دووەم پێش ڕاخراوکردنی (تاثیث) موڵکەکە پێویستە لەسەر ئەستۆی خۆی قوفڵی دەرگا دەرەکیەکان بگۆڕێت، بەپێچەوانەوە هەر کێشەیەک ڕووبدات خۆی بەرپرسیارە لێی.',
      'لایەنی دووەم پابەند دەبێت بە پێدانی کرێیەکە (٧) ڕۆژ پێش ڕێکەوتی دیاریکراو، وە ئەگەر (٧) ڕۆژ لە وادەی دیاریکراو دواکەوت ئەوا لایەنی دووەم بەرپرسیار دەبێت بەرامبەر یاسا.',
      'دوای تەواوبوونی ماوەی گرێبەستەکە ئەگەر لایەنی دووەم پابەند نەبێ بە چۆڵکردنی یان نوێکردنەوەی ئەم گرێبەستە ئەوا کرێی موڵکەکە دەبێت ڕۆژانە بە بڕی ${m(c.lateFeePerDay)} بۆ هەر ڕۆژێک تا یەکلا دەبێتەوە.',
      'خزمەتگوزاری پڕۆژە و شارەوانی و کارەبا و ئاو و هەر خزمەتگوزاریەکی تر هەبێت لە ماوەی ئەم گرێبەستە لە ئەستۆی لایەنی دووەمە.',
      'ئەگەر لایەنی دووەم بیەوێت هەر جۆرە گۆڕانکاریەک لە دەرەوە یان ناوەوەی ئەم موڵکە بکات پێویستە بە ئاگاداری $cn و ڕەزامەندی لایەنی یەکەم بێت، وە بە نوسراوێک گۆڕانکاریەکان دیاری بکرێت و بۆی نیە داوای گەڕانەوەی تێچووی گۆڕانکاریەکان بکات لە لایەنی یەکەم دوای دەرچوون.',
      'لایەنی دووەم بە هیچ شێوەیەک بۆی نیە ئەم موڵکە (هەمووی یان بەشێکی) بەکرێ بداتەوە لایەنی تر بە بێ ئاگادارکردنەوەی $cn و ڕەزامەندی لایەنی یەکەم.',
      'ئەگەر لایەنی یەکەم موڵکەکەی فرۆشت ئەوا لایەنی دووەم بۆی هەیە لە ناو موڵکەکەی بمێنێتەوە تا کۆتایی وادەی گرێبەستەکە، وە خاوەنە نوێیەکەش پابەند دەبێت بە ناوەڕۆکی ئەم گرێبەستە.',
      'ئەگەر لایەنی دووەم پێش کۆتایی هاتنی گرێبەستەکە زووتر دەرچوو لە موڵکەکە، $cn هاوکار دەبێ بۆ گێڕانەوەی (بەشێک یان هەموو) کرێی ماوەی چۆڵکردنی موڵکەکە، ئەگەر بەکرێدرایەوە لەلایەن $cn.',
      '$cn هاوکار دەبێت (نەک بەرپرس) لە نێوان هەردوولایەن لە ماوەی گرێبەستەکە بۆ بەردەوام بوون و مانەوەیان و چارەسەرکردنی کێشە ئەگەر هەبوو.',
      'ئەگەر موڵکەکە ڕاخراو بوو (مؤثث) لەسەر هەردوولا پێویستە کەل و پەلەکان ئەژمار بکەن (جرد) و وێنەی بگرن هاوپێچی گرێبەستەکە بکرێت بۆ بەرچاو ڕوونی هەردوولا، و لایەنی دووەم پێویستە پارێزگاری لە کەلوپەلەکان بکات و لەکاتی دەرچوونی وەک خۆی ڕادەستی لایەنی یەکەمی بکاتەوە، بەپێچەوانەوە لایەنی دووەم بەرپرسە لە چاککردنەوە یان گۆڕینی لەسەر ئەرکی خۆی.',
      'لایەنی یەکەم لەسەریەتی پارەی کارەبای حکومی و ئەهلی و خزمەتگوزاریەکان بدات و ئەستۆی پاکی بکات پێش بەکرێدان و بەرپرسە لە چاککردنەوەی هەر کەم و کوڕیەک کە پەیوەندی بە ژێرخانی موڵکەکە بێت.',
      'لەکاتی هاتنی کرێیەکە پێویستە لایەنی یەکەم بە زووترین کات بێتە $cn و کرێیەکە وەربگرێت، بە پێچەوانەوە پارەکە دەخرێتە ناو حساب بانکی $cn دواتر بە چەک بۆی سەرف دەکرێت.',
      'هەریەک لە لایەنی یەکەم و دووەم پێویستە بڕی کرێی نیو مانگ بۆ هەر ساڵێک بدەن بە $cn لەجیاتی کرێی ڕێکخستنی ئەم گرێبەستە.',
      'لایەنی دووەم لەسەریەتی (مانگێک) پێش وادەی کۆتایی هاتنی گرێبەستەکە، ئاگاداری $cn بکاتەوە ئەگەر نیازی نوێکردنەوە یان چۆڵکردنی موڵکەکەی هەبوو، بە پێچەوانەوە کرێی (مانگێک) دەکەوێتە ئەستۆی لایەنی دووەم.',
      'لەکاتی چۆڵکردن لایەنی دووەم لەسەریەتی چۆن موڵکەکەی وەرگرتووە وەک خۆی بێ کەم و کوڕی ڕادەستی لایەنی یەکەم بکاتەوە، بە پێچەوانەوە بەرپرسە لە چاکردنەوەی کەم و کوڕیەکان بە زووترین کات و پابەندە بە پێدانی پارەی کارەبای نیشتیمانی لەگەڵ هاتنی پسوولەی کارەبا یان سەردانی فەرمانگەی کارەبای نیشتیمانی بکات و پابەندە بە پێدانی پارەی خزمەت گوزاری تا بەرواری چۆڵکردن.',
      'دوای کۆتایی هاتنی وادەی گرێبەستەکە، ئەم گرێبەستە نوێ دەکرێتەوە بە نرخی ڕۆژ بە ڕەزامەندی هەردوولا بە نێوەندگیری $cn بۆ نرخ دانان و شێوازی کرێدانەکە، یان موڵکەکە چۆڵدەکرێت و ڕادەستی خاوەنەکەی دەکرێتەوە.',
      'لە کاتی نوێکردنەوەی گرێبەستەکە هەر یەکێک لە دوولایەنەکە پابەند دەبێت بە پێدانی کرێی نیو مانگ بۆ یەک ساڵ بە $cn.',
      'لەسەر لایەنی دووەم پێویستە موڵکەکە بۆ ئەو مەبەستە بەکاربهێنێت کە لەسەری ڕێکەوتوون، کە نەبێتە مایەی ئەزیەت و ئازار بۆ هاوسێیەکانی، بە پێچەوانەوە بەرپرسیار دەبێت بەرامبەر یاسا و گرێبەستەکە هەڵدەوەشێتەوە.',
      'لەکاتی چارەسەر نەبوونی کێشەی نێوان دوو لایەنەکە (ئەگەر هەبوو) $cn بەرپرس نیە و کێشەکە دەبردرێتە دادگا بۆ چارەسەرکردنی بە شاهێدی کارمەندانی بەرپرس.',
      'ئەگەر لایەنی یەکەم خۆی کڕیی وەرگرت لە کرێچی ئەوا $cn بەرپرس نیە لە هیچ جۆرە کێشەیەک.',
    ];
  }

  static pw.Widget _rentSignatures(RentContract c) {
    pw.Widget col(String label, String name) => pw.Expanded(
          child: pw.Column(
            children: [
              pw.Text(label,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 18),
              pw.Container(width: 120, height: 1, color: PdfColors.black),
              pw.SizedBox(height: 4),
              pw.Text(name, style: const pw.TextStyle(fontSize: 11)),
            ],
          ),
        );
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        col('لایەنی یەکەم', c.party1Name),
        col('کارمەندی بەرپرس', c.agentName),
        col('لایەنی دووەم', c.party2Name),
      ],
    );
  }

  static pw.Widget _partiesSection(SaleContract s) {
    return _card('لایەنەکانی گرێبەست', [
      _row('ژمارەی گرێبەست:', '${s.contractNumber}'),
      _row('ناوی موشتەری:', s.clientName),
      _row('مۆبایل:', s.clientMobile),
      _row('موڵک:', s.propertyTitle),
      _row('بەروار:', _date.format(s.createdAt)),
    ]);
  }

  static pw.Widget _saleBody(SaleContract c) {
    final cur = c.currency.label;
    return _card('وردەکاری دارایی', [
      _row('کۆی نرخ:', '${_money.format(c.totalPrice)} $cur'),
      _row('پێشەکی:', '${_money.format(c.downPayment)} $cur'),
      _row('ماوە:', '${_money.format(c.remainingAmount)} $cur'),
      if (c.remainingDueDate != null)
        _row('بەرواری ماوە:', _date.format(c.remainingDueDate!)),
      _row('کۆمیشنی فرۆشیار:', '${_money.format(c.commissionSeller)} $cur'),
      _row('کۆمیشنی کڕیار:', '${_money.format(c.commissionBuyer)} $cur'),
    ]);
  }

  /// STATIC hardcoded legal clauses mixed with the dynamic data above.
  static pw.Widget _legalClauses(Contract contract) {
    final clauses = <String>[
      'ئەم گرێبەستە بە ڕەزامەندی هەردوو لایەن ئەنجامدراوە و لەژێر یاساکانی هەرێم ڕێکدەخرێت.',
      'هەر لایەنێک پابەندە بە جێبەجێکردنی ئەرکەکانی خۆی بەپێی مەرجەکانی ئەم گرێبەستە.',
      if (contract is RentContract)
        'کرێچی پابەندە بە پارەدانی قیستەکان لە کاتی دیاریکراودا؛ دواکەوتن مافی هەڵوەشاندنەوەی گرێبەست دەداتە خاوەن.'
      else
        'بڕی ماوە دەبێت لە بەرواری دیاریکراودا بدرێت، ئەگەرنا پێشەکییەکە بەپێی ڕێککەوتن مامەڵەی لەگەڵ دەکرێت.',
      'هەرگۆڕانکارییەک لەسەر ئەم گرێبەست دەبێت بە نووسراو و واژووی هەردوو لایەن بێت.',
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text('مەرجە یاساییەکان',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
        pw.SizedBox(height: 6),
        ...List.generate(
          clauses.length,
          (i) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text('${i + 1}. ${clauses[i]}',
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 2)),
          ),
        ),
      ],
    );
  }

  static pw.Widget _signatures() => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _signatureBox('واژووی لایەنی یەکەم'),
          _signatureBox('واژووی لایەنی دووەم'),
        ],
      );

  // ----------------------------- helpers -----------------------------

  static pw.Widget _card(String title, List<pw.Widget> rows) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(title,
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
            pw.SizedBox(height: 6),
            ...rows,
          ],
        ),
      );

  static pw.Widget _row(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          children: [
            pw.SizedBox(
              width: 120,
              child: pw.Text(label,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Expanded(child: pw.Text(value)),
          ],
        ),
      );

  static pw.Widget _signatureBox(String label) => pw.Column(
        children: [
          pw.Container(width: 160, height: 1, color: PdfColors.black),
          pw.SizedBox(height: 4),
          pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
        ],
      );
}
