import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:printing/printing.dart';

/// Receipt PDFs are rendered server-side by the `renderReceiptPdf` Cloud
/// Function (headless Chrome) so Kurdish/Arabic letter shaping — especially
/// ێ — is correct. The function takes the saved receipt's id and returns the
/// PDF bytes; the app only prints/shares/previews them.
class ReceiptPdfRemote {
  /// Calls the function and returns the PDF bytes for [receiptId].
  static Future<Uint8List> build(String receiptId) async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('renderReceiptPdf');
    final res = await callable.call<Map<dynamic, dynamic>>({
      'receiptId': receiptId,
    });
    final b64 = res.data['pdf_base64'] as String?;
    if (b64 == null || b64.isEmpty) {
      throw Exception('وەڵامی فەنکشن بەتاڵە');
    }
    return base64Decode(b64);
  }

  static Future<void> printReceipt(String receiptId) async {
    final bytes = await build(receiptId);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<void> shareReceipt(String receiptId, int receiptNumber) async {
    final bytes = await build(receiptId);
    await Printing.sharePdf(bytes: bytes, filename: 'receipt_$receiptNumber.pdf');
  }
}
