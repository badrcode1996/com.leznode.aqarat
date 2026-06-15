import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/company_model.dart';
import '../../models/contract_model.dart';
import '../../models/receipt_model.dart';

/// Super-admin data export for one company.
///
/// * **Excel** (.xlsx) is built on-device — spreadsheets store raw Unicode, so
///   shaping is the spreadsheet app's job, no PDF shaper involved.
/// * **PDF** is rendered server-side by the `renderExportPdf` Cloud Function
///   (headless Chrome) so Kurdish ێ shapes correctly.
class ExportService {
  static final _money = NumberFormat.decimalPattern();
  static final _date = DateFormat('yyyy/MM/dd');

  static const _contractHeaders = [
    'ژمارە', 'جۆر', 'لایەنی یەکەم', 'لایەنی دووەم', 'موڵک', 'پڕۆژە',
    'بڕ / نرخ', 'دراو', 'بەروار',
  ];
  static const _receiptHeaders = [
    'ژمارە', 'جۆر', 'کەس', 'بڕ', 'دراو', 'مەبەست', 'لق', 'بەروار',
  ];

  static List<String> _contractRow(Contract c) => switch (c) {
        RentContract r => [
            '${r.contractNumber}', 'کرێ', r.party1Name, r.party2Name,
            r.propertyType, r.projectName, _money.format(r.rentAmount),
            r.currency.label, _date.format(r.startDate),
          ],
        SaleContract s => [
            '${s.contractNumber}', 'فرۆشتن', s.party1Name, s.party2Name,
            s.propertyType, s.projectName, _money.format(s.totalPrice),
            s.currency.label, _date.format(s.deliveryDate),
          ],
      };

  static List<String> _receiptRow(Receipt r) => [
        '${r.receiptNumber}', r.type.titleKu, r.personName,
        _money.format(r.amount), r.currency.label, r.paymentPurpose, r.branch,
        _date.format(r.date),
      ];

  // --------------------------- Excel (on-device) ---------------------------

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

    if (defaultSheet != null && defaultSheet != 'گرێبەستەکان') {
      excel.delete(defaultSheet);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('نەتوانرا فایلی Excel دروست بکرێت');
    return Uint8List.fromList(bytes);
  }

  // --------------------------- PDF (server-side) ---------------------------

  /// Calls `renderExportPdf` and shares the returned PDF report.
  static Future<void> sharePdfRemote(Company company) async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('renderExportPdf');
    final res = await callable.call<Map<dynamic, dynamic>>({
      'companyId': company.id,
    });
    final b64 = res.data['pdf_base64'] as String?;
    if (b64 == null || b64.isEmpty) {
      throw Exception('وەڵامی فەنکشن بەتاڵە');
    }
    await Printing.sharePdf(
        bytes: base64Decode(b64), filename: '${_slug(company)}.pdf');
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
