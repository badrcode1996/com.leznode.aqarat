import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/company_model.dart';
import '../../models/contract_model.dart';

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
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(32),
        // Company name + logo repeat on every page; the title is in the body
        // (first line of page 1 only).
        header: (ctx) => _header(company, logo),
        footer: (ctx) => _footer(ctx, company),
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

  /// Repeating page header: company name + logo on EVERY page.
  static pw.Widget _header(Company? company, pw.ImageProvider? logo) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (company != null) _companyBand(company, logo),
        pw.SizedBox(height: 6),
        pw.Divider(thickness: 1.2),
      ],
    );
  }

  /// The big contract title — placed as the first line of page 1's body.
  static pw.Widget _title(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(text,
            textAlign: pw.TextAlign.center,
            style:
                pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
      );

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

  static pw.Widget _footer(pw.Context ctx, Company? company) {
    final phones = company == null
        ? ''
        : [company.phone1, company.phone2].where((p) => p.isNotEmpty).join(' / ');
    final address = company?.address ?? '';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Divider(thickness: 0.8, color: PdfColors.grey400),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // RTL: first child sits on the RIGHT → phones.
            if (phones.isNotEmpty)
              pw.Expanded(
                child: pw.Text('تەلەفۆن: $phones',
                    style: const pw.TextStyle(fontSize: 9)),
              ),
            if (address.isNotEmpty)
              pw.Expanded(
                child: pw.Text('ناونیشان: $address',
                    textAlign: pw.TextAlign.left,
                    style: const pw.TextStyle(fontSize: 9)),
              ),
          ],
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text('لاپەڕە ${ctx.pageNumber} لە ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ),
      ],
    );
  }

  // ----------------------------- SALE -----------------------------
  static List<pw.Widget> _saleContent(SaleContract s) {
    final cur = s.currency.label;
    String m(num v) => _money.format(v);
    return [
      _title('گرێبەستی فرۆشتن'),
      _card('زانیاری گرێبەست', [
        _row('ژمارەی گرێبەست:', '${s.contractNumber}'),
        _row('لایەنی یەکەم (فرۆشیار):', s.party1Name),
        _row('ژمارەی مۆبایل:', s.party1Mobile),
        _row('لایەنی دووەم (کڕیار):', s.party2Name),
        _row('ژمارەی مۆبایل:', s.party2Mobile),
        _row('جۆری موڵک:', s.propertyType),
        _row('پڕۆژە / گەڕەک:', s.projectName),
        _row('ژمارەی عەقار:', s.propertyNumber),
        _row('ڕووبەر:', '${s.area} م²'),
      ]),
      pw.SizedBox(height: 12),
      _card('وردەکاری دارایی', [
        _row('نرخی فرۆشتن:', '${m(s.totalPrice)} $cur'),
        _row('پێشەکی:', '${m(s.downPayment)} $cur'),
        _row('شێوازی پارەدان:', s.paymentMethod),
        _row('بڕی دواکەوتن بۆ ڕۆژێک:', '${m(s.lateFeePerDay)} $cur'),
        _row('بڕی پاشگەزبوونەوە:', '${m(s.withdrawalAmount)} $cur'),
        _row('پارێزەر:', s.lawyer),
        _row('ڕێکەوتی تەسلیم:', _date.format(s.deliveryDate)),
      ]),
      if (s.notes.trim().isNotEmpty) ...[
        pw.SizedBox(height: 8),
        pw.Text('تێبینی: ${s.notes}', style: const pw.TextStyle(fontSize: 11)),
      ],
      pw.SizedBox(height: 30),
      _partySignatures(s.party1Name, s.agentName, s.party2Name),
    ];
  }

  // ----------------------------- RENT -----------------------------
  static List<pw.Widget> _rentContent(RentContract c, Company? company) {
    return [
      _title('گرێبەستی کرێ'),
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
      pw.Text('هەردوو لایەن ڕێکەوتن لەسەر ئەم خاڵانەی خوارەوە (بەندەکان):',
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
        pw.Text('تێبینی: ${c.notes}', style: const pw.TextStyle(fontSize: 11)),
      ],
      pw.SizedBox(height: 24),
      _partySignatures(c.party1Name, c.agentName, c.party2Name),
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

  /// 3-column signature row: party1 · responsible employee (agent) · party2.
  static pw.Widget _partySignatures(
      String party1, String agent, String party2) {
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
        col('لایەنی یەکەم', party1),
        col('کارمەندی بەرپرس', agent),
        col('لایەنی دووەم', party2),
      ],
    );
  }

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

}
