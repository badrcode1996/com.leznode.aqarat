import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/company_model.dart';
import '../../models/contract_model.dart';
import '../../models/receipt_model.dart';

/// Super-admin data export: a company's contracts + receipts as an Excel
/// workbook (two sheets) or a PDF report. Both are handed to the OS share
/// sheet so the file can be saved or sent on.
class ExportService {
  static final _money = NumberFormat.decimalPattern();
  static final _date = DateFormat('yyyy/MM/dd');

  static const _contractHeaders = [
    'ژمارە',
    'جۆر',
    'لایەنی یەکەم',
    'لایەنی دووەم',
    'موڵک',
    'پڕۆژە',
    'بڕ / نرخ',
    'دراو',
    'بەروار',
  ];
  static const _receiptHeaders = [
    'ژمارە',
    'جۆر',
    'کەس',
    'بڕ',
    'دراو',
    'مەبەست',
    'لق',
    'بەروار',
  ];

  static List<String> _contractRow(Contract c) => switch (c) {
        RentContract r => [
            '${r.contractNumber}',
            'کرێ',
            r.party1Name,
            r.party2Name,
            r.propertyType,
            r.projectName,
            _money.format(r.rentAmount),
            r.currency.label,
            _date.format(r.startDate),
          ],
        SaleContract s => [
            '${s.contractNumber}',
            'فرۆشتن',
            s.party1Name,
            s.party2Name,
            s.propertyType,
            s.projectName,
            _money.format(s.totalPrice),
            s.currency.label,
            _date.format(s.deliveryDate),
          ],
      };

  static List<String> _receiptRow(Receipt r) => [
        '${r.receiptNumber}',
        r.type.titleKu,
        r.personName,
        _money.format(r.amount),
        r.currency.label,
        r.paymentPurpose,
        r.branch,
        _date.format(r.date),
      ];

  // --------------------------- Excel ---------------------------

  /// Builds and shares an `.xlsx` workbook for the company.
  static Future<void> shareExcel(
    Company company, {
    required List<Contract> contracts,
    required List<Receipt> receipts,
  }) async {
    final bytes = buildExcel(contracts: contracts, receipts: receipts);
    await _shareBytes(
      bytes,
      '${_slug(company)}.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  /// Builds the `.xlsx` workbook bytes (two sheets: contracts + receipts).
  static Uint8List buildExcel({
    required List<Contract> contracts,
    required List<Receipt> receipts,
  }) {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();

    final cSheet = excel['گرێبەستەکان'];
    cSheet.appendRow(_contractHeaders.map(TextCellValue.new).toList());
    for (final c in contracts) {
      cSheet.appendRow(_contractRow(c).map(TextCellValue.new).toList());
    }

    final rSheet = excel['پسولەکان'];
    rSheet.appendRow(_receiptHeaders.map(TextCellValue.new).toList());
    for (final r in receipts) {
      rSheet.appendRow(_receiptRow(r).map(TextCellValue.new).toList());
    }

    // Drop the empty default sheet that createExcel() inserts.
    if (defaultSheet != null && defaultSheet != 'گرێبەستەکان') {
      excel.delete(defaultSheet);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('نەتوانرا فایلی Excel دروست بکرێت');
    return Uint8List.fromList(bytes);
  }

  // --------------------------- PDF ---------------------------

  /// Builds and shares a PDF report (two tables) for the company.
  static Future<void> sharePdf(
    Company company, {
    required List<Contract> contracts,
    required List<Receipt> receipts,
  }) async {
    final bytes =
        await buildPdf(company, contracts: contracts, receipts: receipts);
    await Printing.sharePdf(bytes: bytes, filename: '${_slug(company)}.pdf');
  }

  /// Builds the PDF report bytes (two tables) for the company.
  static Future<Uint8List> buildPdf(
    Company company, {
    required List<Contract> contracts,
    required List<Receipt> receipts,
  }) async {
    final reg =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'));
    final bold =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf'));
    final theme = pw.ThemeData.withFont(base: reg, bold: bold);
    final doc = pw.Document(theme: theme);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(24),
        theme: theme,
        build: (ctx) => [
          pw.Text('ڕاپۆرتی ${company.displayName}',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('بەروار: ${_date.format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 12),
          _pdfHeading('گرێبەستەکان (${contracts.length})'),
          _pdfTable(_contractHeaders, contracts.map(_contractRow).toList()),
          pw.SizedBox(height: 16),
          _pdfHeading('پسولەکان (${receipts.length})'),
          _pdfTable(_receiptHeaders, receipts.map(_receiptRow).toList()),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _pdfHeading(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900)),
      );

  static pw.Widget _pdfTable(List<String> headers, List<List<String>> rows) {
    if (rows.isEmpty) {
      return pw.Text('— هیچ تۆمارێک نییە —',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600));
    }
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue50),
      cellAlignment: pw.Alignment.centerRight,
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
    );
  }

  // --------------------------- helpers ---------------------------

  static String _slug(Company company) {
    final base = company.id.isNotEmpty ? company.id : 'company';
    return 'aqarat_${base}_${DateFormat('yyyyMMdd').format(DateTime.now())}';
  }

  /// Writes bytes to a temp file and opens the share sheet.
  static Future<void> _shareBytes(
      Uint8List bytes, String name, String mime) async {
    final file = File('${Directory.systemTemp.path}/$name');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path, mimeType: mime)]);
  }
}
