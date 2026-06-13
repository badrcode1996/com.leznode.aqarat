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

  /// Loads the SPEDA fonts bundled in assets (once).
  static Future<void> _ensureFonts() async {
    if (_regular != null && _bold != null) return;
    final reg = await rootBundle.load('assets/fonts/SPEDA.ttf');
    final bold = await rootBundle.load('assets/fonts/SPEDA-Bold.ttf');
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
    );

    final doc = pw.Document(theme: theme);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl, // whole document is RTL
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _header(contract, company, logo),
        footer: (ctx) => _footer(ctx),
        build: (ctx) => [
          _partiesSection(contract),
          pw.SizedBox(height: 12),
          if (contract is RentContract) _rentBody(contract),
          if (contract is SaleContract) _saleBody(contract),
          pw.SizedBox(height: 18),
          _legalClauses(contract),
          pw.SizedBox(height: 30),
          _signatures(),
        ],
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

  /// Branded company strip: logo on one side, name + phones + address on the other.
  static pw.Widget _companyBand(Company company, pw.ImageProvider? logo) {
    final phones = [company.phone1, company.phone2]
        .where((p) => p.isNotEmpty)
        .join(' • ');
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (logo != null)
          pw.Container(
            width: 56,
            height: 56,
            margin: const pw.EdgeInsets.only(left: 10),
            child: pw.Image(logo, fit: pw.BoxFit.contain),
          ),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                company.displayName,
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              if (phones.isNotEmpty)
                pw.Text('تەلەفۆن: $phones',
                    style: const pw.TextStyle(fontSize: 10)),
              if (company.address.isNotEmpty)
                pw.Text('ناونیشان: ${company.address}',
                    style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
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

  static pw.Widget _partiesSection(Contract contract) {
    if (contract is RentContract) {
      return _card('لایەنەکانی گرێبەست', [
        _row('ژمارەی گرێبەست:', '${contract.contractNumber}'),
        _row('لایەنی یەکەم:', contract.party1Name),
        _row('ژمارەی مۆبایل:', contract.party1Mobile),
        _row('لایەنی دووەم:', contract.party2Name),
        _row('ژمارەی مۆبایل:', contract.party2Mobile),
        _row('بەروار:', _date.format(contract.createdAt)),
      ]);
    }
    final s = contract as SaleContract;
    return _card('لایەنەکانی گرێبەست', [
      _row('ژمارەی گرێبەست:', '${s.contractNumber}'),
      _row('ناوی موشتەری:', s.clientName),
      _row('مۆبایل:', s.clientMobile),
      _row('موڵک:', s.propertyTitle),
      _row('بەروار:', _date.format(contract.createdAt)),
    ]);
  }

  static pw.Widget _rentBody(RentContract c) {
    final cur = c.currency.label;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _card('زانیاری موڵک', [
          _row('جۆری موڵک:', c.propertyType),
          _row('پڕۆژە/گەرەک:', c.projectName),
          _row('ژمارەی عەقار:', c.propertyNumber),
          _row('ڕووبەر:', '${c.area} م²'),
          _row('هۆکاری بەکریگرتن:', c.rentalPurpose),
        ]),
        pw.SizedBox(height: 10),
        _card('زانیاری دارایی', [
          _row('بری کرێ:', '${_money.format(c.rentAmount)} $cur'),
          _row('ماوەی بەکریگرتن:', '${c.rentalPeriodMonths} مانگ'),
          _row('بری پێشەکی:',
              '${_money.format(c.downPayment)} بۆ ${c.downPaymentMonths} مانگ'),
          _row('بەرواری بەکریگرتن:', _date.format(c.startDate)),
          _row('بەرواری ڕادەستکردن:', _date.format(c.handoverDate)),
          _row('کرێدان:', 'هەر ${c.paymentFrequencyMonths} مانگ جارێک'),
          _row('بری دڵنیایی:', _money.format(c.guaranteeAmount)),
          _row('ماوەی ڕێپێدان:', c.gracePeriod),
          _row('بری دواکەوتن بۆ ڕۆژ:', _money.format(c.lateFeePerDay)),
        ]),
        pw.SizedBox(height: 10),
        pw.Text('خشتەی قیستەکان',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        _installmentsTable(c),
      ],
    );
  }

  static pw.Widget _installmentsTable(RentContract c) {
    String statusLabel(PaymentStatus s) => switch (s) {
          PaymentStatus.pending => 'چاوەڕوان',
          PaymentStatus.receivedFromTenant => 'وەرگیرا لە کرێچی',
          PaymentStatus.deliveredToOwner => 'گەیەنرا بە خاوەن',
        };

    return pw.TableHelper.fromTextArray(
      headerAlignment: pw.Alignment.center,
      cellAlignment: pw.Alignment.center,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      cellStyle: const pw.TextStyle(fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      headers: ['مانگ', 'بەرواری دواخستن', 'دۆخ', 'بڕ'],
      data: c.installments
          .map((i) => [
                '${i.monthNumber}',
                _date.format(i.dueDate),
                statusLabel(i.status),
                _money.format(c.rentAmount),
              ])
          .toList(),
    );
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
