import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/company_model.dart';
import '../../models/receipt_model.dart';

/// On-device PDF for a receipt/voucher (وەصڵ). Renders TWO copies on one A4
/// page — company copy + customer copy — matching the printed voucher design.
class ReceiptPdfService {
  static pw.Font? _regular;
  static pw.Font? _bold;
  static final _money = NumberFormat.decimalPattern();
  static final _date = DateFormat('yyyy/MM/dd');

  static Future<void> _ensureFonts() async {
    if (_regular != null && _bold != null) return;
    _regular =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'));
    _bold =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf'));
  }

  static Future<Uint8List> build(Receipt r, {Company? company}) async {
    await _ensureFonts();
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
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(20),
        theme: theme,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Expanded(child: _copy(r, company, logo, 'کۆپی کۆمپانیا')),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 8),
            pw.Expanded(child: _copy(r, company, logo, 'کۆپی زەبوون')),
          ],
        ),
      ),
    );
    return doc.save();
  }

  static Future<void> printReceipt(Receipt r, {Company? company}) async {
    final bytes = await build(r, company: company);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<void> shareReceipt(Receipt r, {Company? company}) async {
    final bytes = await build(r, company: company);
    await Printing.sharePdf(bytes: bytes, filename: 'receipt_${r.receiptNumber}.pdf');
  }

  // ----------------------------- one copy -----------------------------
  static pw.Widget _copy(
    Receipt r,
    Company? company,
    pw.ImageProvider? logo,
    String copyLabel,
  ) {
    final personLabel =
        r.type.isPayment ? 'پێدرا بە بەڕێز' : 'وەرمگرت لە بەڕێز';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        // Header: title band (right) + logo (left).
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('${r.type.titleKu}  /  ${r.type.titleAr}',
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text('${r.type.titleEn}  ($copyLabel)',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
            ),
            if (logo != null)
              pw.Container(
                  width: 50, height: 50, child: pw.Image(logo, fit: pw.BoxFit.contain)),
          ],
        ),
        pw.Divider(thickness: 1.2, color: PdfColors.blue900),
        // Date + branch + number.
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('بەروار: ${_date.format(r.date)}',
                style: const pw.TextStyle(fontSize: 10)),
            pw.Text('لق: ${r.branch}', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('ژمارەی وەصڵ: ${r.receiptNumber}',
                style:
                    pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ],
        ),
        pw.SizedBox(height: 6),
        _row(personLabel, r.personName),
        _row('بڕی پارە', '${_money.format(r.amount)} ${r.currency.label}'),
        _row('لە بڕی', r.paymentPurpose),
        if (r.note.trim().isNotEmpty) _row('تێبینی', r.note),
        pw.SizedBox(height: 10),
        // Signatures.
        pw.Row(
          children: [
            _sign('کارمەندی بەرپرس', r.agentName),
            _sign('لێوەرگیراو', ''),
            _sign('پێدراو', ''),
          ],
        ),
        // Footer.
        if (company != null) ...[
          pw.SizedBox(height: 6),
          pw.Divider(thickness: 0.5, color: PdfColors.grey400),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                  [company.phone1, company.phone2]
                      .where((p) => p.isNotEmpty)
                      .join(' / '),
                  style: const pw.TextStyle(fontSize: 8)),
              pw.Text(company.address,
                  style: const pw.TextStyle(fontSize: 8)),
            ],
          ),
        ],
      ],
    );
  }

  static pw.Widget _row(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
                width: 90,
                child: pw.Text('$label:',
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold))),
            pw.Expanded(
                child: pw.Text(value, style: const pw.TextStyle(fontSize: 10))),
          ],
        ),
      );

  static pw.Widget _sign(String label, String name) => pw.Expanded(
        child: pw.Column(
          children: [
            pw.SizedBox(height: 14),
            pw.Container(width: 90, height: 0.8, color: PdfColors.black),
            pw.SizedBox(height: 2),
            pw.Text(label,
                style:
                    pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            if (name.isNotEmpty)
              pw.Text(name, style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
      );
}
