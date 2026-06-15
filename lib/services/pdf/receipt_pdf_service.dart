import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/company_model.dart';
import '../../models/contract_template_model.dart';
import '../../models/enums.dart';
import '../../models/receipt_model.dart';

/// On-device PDF for a receipt/voucher (وەصڵ). Renders TWO copies on one A4
/// page — company copy + customer copy — in the trilingual (Kurdish / Arabic /
/// English) voucher layout: blue title banner with logo, labelled fields on
/// dotted lines, a three-signature row, and a footer contact band.
class ReceiptPdfService {
  static pw.Font? _regular;
  static pw.Font? _bold;
  static final _money = NumberFormat.decimalPattern();
  static final _date = DateFormat('yyyy/MM/dd');

  // Brand palette (matches app_theme). The banner/footer colour and field font
  // size are overridable per company via the template; these are the defaults.
  static const PdfColor _darkBlue = PdfColor.fromInt(0xFF0F2C59);
  static const PdfColor _red = PdfColor.fromInt(0xFFD64545);

  static Future<void> _ensureFonts() async {
    if (_regular != null && _bold != null) return;
    _regular =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'));
    _bold =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf'));
  }

  /// Parses a `RRGGBB` hex string into an opaque [PdfColor].
  static PdfColor _hexColor(String hex) {
    final v = int.tryParse(hex.replaceAll('#', ''), radix: 16);
    return v == null ? const PdfColor.fromInt(0xFF1E4D8B) : PdfColor.fromInt(0xFF000000 | v);
  }

  static Future<Uint8List> build(Receipt r,
      {Company? company, ContractTemplate? template}) async {
    await _ensureFonts();
    final tpl = template ?? ContractTemplate.defaults();
    final accent = _hexColor(tpl.receiptColorHex);
    final fs = tpl.receiptFontSize;
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
        margin: const pw.EdgeInsets.all(18),
        theme: theme,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Expanded(
                child: _copy(r, company, logo, 'کۆپی کۆمپانیا', accent, fs)),
            pw.SizedBox(height: 10),
            _scissorLine(),
            pw.SizedBox(height: 10),
            pw.Expanded(
                child: _copy(r, company, logo, 'کۆپی زەبوون', accent, fs)),
          ],
        ),
      ),
    );
    return doc.save();
  }

  static Future<void> printReceipt(Receipt r,
      {Company? company, ContractTemplate? template}) async {
    final bytes = await build(r, company: company, template: template);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<void> shareReceipt(Receipt r,
      {Company? company, ContractTemplate? template}) async {
    final bytes = await build(r, company: company, template: template);
    await Printing.sharePdf(
        bytes: bytes, filename: 'receipt_${r.receiptNumber}.pdf');
  }

  // ----------------------------- one copy -----------------------------
  static pw.Widget _copy(
    Receipt r,
    Company? company,
    pw.ImageProvider? logo,
    String copyLabel,
    PdfColor accent,
    double fs,
  ) {
    final isPay = r.type.isPayment;
    final personKuAr = isPay
        ? 'پێدرا بە بەڕێز / دُفِع إلى السید/ة'
        : 'وەرمگرت لە بەڕێز / استلمت من السید/ة';
    final personEn = isPay ? 'Paid To Mr/Mrs' : 'Received From Mr/Mrs';

    // Auto-fill the two lower signatures from the money direction:
    //   • Receive: the office (accountant) is delivered the money, and it is
    //     received-by the person named above.
    //   • Pay: the office (accountant) receives the signature, and it is
    //     delivered-to the person named above.
    final receivedByName = isPay ? r.agentName : r.personName;
    final deliveredToName = isPay ? r.personName : r.agentName;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // ---------------- Header: logo (left) + blue banner (right) --------
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Expanded(child: _banner(r.type, accent)),
            _arrowTail(accent),
            pw.SizedBox(width: 10),
            _logoBox(logo),
          ],
        ),
        pw.SizedBox(height: 4),
        // Copy label under the header.
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(right: 4),
            child: pw.Text(copyLabel,
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _darkBlue)),
          ),
        ),
        pw.SizedBox(height: 4),

        // ---------------- Date + branch ----------------
        pw.Row(
          children: [
            pw.Expanded(
              flex: 3,
              child: _field('التأريخ / بەروار / DATE', 'DATE',
                  _date.format(r.date), fs,
                  showEn: false),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              flex: 2,
              child: _field('لق', 'Branch', r.branch, fs, showEn: false),
            ),
          ],
        ),

        // ---------------- Fields ----------------
        _field('ژمارەی پسوله / رقم الوصل', 'Voucher No.', '${r.receiptNumber}',
            fs),
        _field(personKuAr, personEn, r.personName, fs),
        _field('بڕی پارە / مبلغ وقدره', 'Amount',
            '${_money.format(r.amount)} ${r.currency.label}', fs),
        _field('لەبڕی / وذلك لقاء', 'Payment Purpose', r.paymentPurpose, fs),
        _field('تێبینی / ملاحظة', 'Note', r.note, fs, labelColor: _red),

        pw.Spacer(),

        // ---------------- Signatures ----------------
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _sign('کارمەندی بەرپرس / المحاسب', 'Acountant', r.agentName),
            _sign('لێوەرگیراو / المستلم', 'Received By', receivedByName),
            _sign('پێدراو / تسلیم الی', 'Delivered To', deliveredToName),
          ],
        ),

        // ---------------- Footer ----------------
        if (company != null) ...[
          pw.SizedBox(height: 8),
          _footer(company, accent),
        ],
      ],
    );
  }

  // ---------------- header pieces ----------------

  /// The title band with the three-language voucher name.
  static pw.Widget _banner(ReceiptType type, PdfColor accent) => pw.Container(
        height: 34,
        decoration: pw.BoxDecoration(
          color: accent,
          borderRadius: const pw.BorderRadius.only(
            topRight: pw.Radius.circular(6),
            bottomRight: pw.Radius.circular(6),
          ),
        ),
        padding: const pw.EdgeInsets.symmetric(horizontal: 14),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(type.titleKu,
                style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold)),
            pw.Text(type.titleAr,
                style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold)),
            pw.Text(type.titleEn,
                style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );

  /// The leftward arrow tail that joins the banner to the logo.
  static pw.Widget _arrowTail(PdfColor accent) => pw.CustomPaint(
        size: const PdfPoint(16, 34),
        painter: (canvas, size) {
          canvas
            ..setFillColor(accent)
            ..moveTo(16, 34)
            ..lineTo(16, 0)
            ..lineTo(0, 17)
            ..fillPath();
        },
      );

  static pw.Widget _logoBox(pw.ImageProvider? logo) => pw.Container(
        width: 64,
        height: 44,
        alignment: pw.Alignment.center,
        child: logo != null
            ? pw.Image(logo, fit: pw.BoxFit.contain)
            : pw.Text('LOGO',
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: _darkBlue)),
      );

  // ---------------- field row ----------------

  /// One labelled field: Kurdish/Arabic label on the right, the value on a
  /// single dotted line in the middle, and the English label on the left.
  static pw.Widget _field(
    String kuAr,
    String en,
    String value,
    double fs, {
    bool showEn = true,
    PdfColor labelColor = _darkBlue,
  }) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('$kuAr :',
                style: pw.TextStyle(
                    fontSize: fs,
                    fontWeight: pw.FontWeight.bold,
                    color: labelColor)),
            pw.SizedBox(width: 6),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Text(value, style: pw.TextStyle(fontSize: fs)),
                  pw.SizedBox(height: 2),
                  _dottedLine(),
                ],
              ),
            ),
            if (showEn) ...[
              pw.SizedBox(width: 6),
              pw.Text('$en :',
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey700)),
            ],
          ],
        ),
      );

  /// A full-width dotted line drawn as evenly spaced dashes.
  static pw.Widget _dottedLine() => pw.CustomPaint(
        painter: (canvas, size) {
          const dash = 2.0;
          const gap = 2.5;
          canvas.setStrokeColor(PdfColors.grey500);
          canvas.setLineWidth(0.6);
          var x = 0.0;
          while (x < size.x) {
            canvas
              ..moveTo(x, 0.5)
              ..lineTo((x + dash).clamp(0, size.x), 0.5);
            x += dash + gap;
          }
          canvas.strokePath();
        },
        child: pw.SizedBox(height: 1, width: double.infinity),
      );

  // ---------------- signatures ----------------

  static pw.Widget _sign(String kuAr, String en, String name) => pw.Expanded(
        child: pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6),
          child: pw.Column(
            children: [
              pw.SizedBox(height: 16),
              if (name.isNotEmpty)
                pw.Text(name, style: const pw.TextStyle(fontSize: 9))
              else
                pw.SizedBox(height: 11),
              pw.SizedBox(height: 2),
              _dottedLine(),
              pw.SizedBox(height: 3),
              pw.Text(kuAr,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Text(en,
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _darkBlue)),
            ],
          ),
        ),
      );

  // ---------------- footer ----------------

  static pw.Widget _footer(Company company, PdfColor accent) {
    final cells = <String>[
      if (company.phone1.isNotEmpty) company.phone1,
      if (company.phone2.isNotEmpty) company.phone2,
      if (company.address.isNotEmpty) company.address,
    ];
    if (cells.isEmpty) return pw.SizedBox();
    return pw.Container(
      height: 24,
      decoration: pw.BoxDecoration(
        color: accent,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 14),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0)
              pw.Container(width: 0.8, height: 12, color: PdfColors.blue200),
            pw.Text(cells[i],
                style:
                    const pw.TextStyle(color: PdfColors.white, fontSize: 8)),
          ],
        ],
      ),
    );
  }

  /// A dashed "cut here" divider between the two copies.
  static pw.Widget _scissorLine() => pw.CustomPaint(
        painter: (canvas, size) {
          const dash = 4.0;
          const gap = 3.0;
          canvas.setStrokeColor(PdfColors.grey400);
          canvas.setLineWidth(0.8);
          var x = 0.0;
          while (x < size.x) {
            canvas
              ..moveTo(x, 0.5)
              ..lineTo((x + dash).clamp(0, size.x), 0.5);
            x += dash + gap;
          }
          canvas.strokePath();
        },
        child: pw.SizedBox(height: 1, width: double.infinity),
      );
}
