import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/company_model.dart';
import '../../models/contract_model.dart';
import '../../models/contract_template_model.dart';

/// On-device PDF generator for contracts.
///
/// * RTL (Kurdish/Arabic) is forced via [pw.Directionality] + the SPEDA `.ttf`.
/// * Dynamic form data is mixed with static, hardcoded legal clauses.
/// * Uses the `printing` package to print over Wi-Fi or share the file.
class ContractPdfService {
  // Cache the parsed fonts so we don't re-read the asset for every contract.
  static pw.Font? _regular;
  static pw.Font? _bold;

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
  /// branded header (logo, name, phones, address) and [template] to use the
  /// company's custom clauses/design (defaults to [ContractTemplate.defaults]).
  static Future<Uint8List> build(
    Contract contract, {
    Company? company,
    ContractTemplate? template,
  }) async {
    await _ensureFonts();
    final tpl = template ?? ContractTemplate.defaults();

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

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      margin: const pw.EdgeInsets.all(32),
      theme: theme,
      // Force a solid white (#ffffff) page background.
      buildBackground: (ctx) => pw.FullPage(
        ignoreMargins: true,
        child: pw.Container(color: PdfColors.white),
      ),
    );

    doc.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        // Company name + logo repeat on every page; the title is in the body
        // (first line of page 1 only).
        header: (ctx) => _header(company, logo),
        footer: (ctx) => _footer(ctx, company),
        build: (ctx) => switch (contract) {
          RentContract r => _rentContent(r, company, tpl),
          SaleContract s => _saleContent(s, company, tpl),
        },
      ),
    );

    return doc.save();
  }

  /// Sends the contract straight to a printer (Wi-Fi / system print dialog).
  static Future<void> printContract(Contract contract,
      {Company? company, ContractTemplate? template}) async {
    final bytes = await build(contract, company: company, template: template);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  /// Opens the OS share sheet (save / send via WhatsApp, email, etc.).
  static Future<void> shareContract(Contract contract,
      {Company? company, ContractTemplate? template}) async {
    final bytes = await build(contract, company: company, template: template);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'contract_${contract.id}.pdf',
    );
  }

  /// Parses a `RRGGBB` hex string into an opaque [PdfColor].
  static PdfColor _hexColor(String hex) {
    final v = int.tryParse(hex.replaceAll('#', ''), radix: 16);
    return v == null ? PdfColors.black : PdfColor.fromInt(0xFF000000 | v);
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
  static pw.Widget _title(String text, PdfColor color) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(text,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
                fontSize: 22, fontWeight: pw.FontWeight.bold, color: color)),
      );

  /// The numbered clause list, built from template strings with `{token}`s
  /// substituted for the contract's values.
  static List<pw.Widget> _clauses(
    List<String> clauses,
    Map<String, String> tokens,
    double fontSize,
  ) =>
      clauses.asMap().entries.map((e) {
        final text = ContractTemplate.apply(e.value, tokens);
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Text('${e.key + 1}- $text',
              textAlign: pw.TextAlign.justify,
              style: pw.TextStyle(fontSize: fontSize, lineSpacing: 2)),
        );
      }).toList();

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
  static List<pw.Widget> _saleContent(
      SaleContract s, Company? company, ContractTemplate tpl) {
    final color = _hexColor(tpl.primaryColorHex);
    return [
      _title(tpl.saleTitle, color),
      _card('زانیاری گرێبەست', color, [
        _row('ژمارەی گرێبەست:', '${s.contractNumber}'),
        _row('لایەنی یەکەم (فرۆشیار):', s.party1Name),
        _row('لایەنی دووەم (کڕیار):', s.party2Name),
        _row('جۆری موڵک:', s.propertyType),
        _row('پڕۆژە / گەڕەک:', s.projectName),
        _row('ژمارەی عەقار:', s.propertyNumber),
        _row('ڕووبەر:', '${s.area} م²'),
      ]),
      pw.SizedBox(height: 12),
      pw.Text('هەردوو لایەن ڕێکەوتن لەسەر ئەم خاڵانەی خوارەوە (بەندەکان):',
          style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold, fontSize: 12, color: color)),
      pw.SizedBox(height: 6),
      ..._clauses(tpl.saleClauses, ContractTemplate.tokensFor(s, company),
          tpl.clauseFontSize),
      if (s.notes.trim().isNotEmpty) ...[
        pw.SizedBox(height: 8),
        pw.Text('تێبینی: ${s.notes}', style: const pw.TextStyle(fontSize: 11)),
      ],
      pw.SizedBox(height: 24),
      _partySignatures(s.party1Name, s.agentName, s.party2Name),
    ];
  }

  // ----------------------------- RENT -----------------------------
  static List<pw.Widget> _rentContent(
      RentContract c, Company? company, ContractTemplate tpl) {
    final color = _hexColor(tpl.primaryColorHex);
    return [
      _title(tpl.rentTitle, color),
      _card('زانیاری گرێبەست', color, [
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
          style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold, fontSize: 12, color: color)),
      pw.SizedBox(height: 6),
      ..._clauses(tpl.rentClauses, ContractTemplate.tokensFor(c, company),
          tpl.clauseFontSize),
      if (c.notes.trim().isNotEmpty) ...[
        pw.SizedBox(height: 8),
        pw.Text('تێبینی: ${c.notes}', style: const pw.TextStyle(fontSize: 11)),
      ],
      pw.SizedBox(height: 24),
      _partySignatures(c.party1Name, c.agentName, c.party2Name),
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

  static pw.Widget _card(String title, PdfColor color, List<pw.Widget> rows) =>
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: color),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(title,
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 13, color: color)),
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
