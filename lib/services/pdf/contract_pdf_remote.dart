import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:printing/printing.dart';

/// Contract PDFs are rendered server-side by the `renderContractPdf` Cloud
/// Function (headless Chrome) so Kurdish/Arabic letter shaping — especially
/// ێ — is correct. The function takes the saved contract's id and returns the
/// PDF bytes.
class ContractPdfRemote {
  static Future<Uint8List> build(String contractId) async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('renderContractPdf');
    final res = await callable.call<Map<dynamic, dynamic>>({
      'contractId': contractId,
    });
    final b64 = res.data['pdf_base64'] as String?;
    if (b64 == null || b64.isEmpty) {
      throw Exception('وەڵامی فەنکشن بەتاڵە');
    }
    return base64Decode(b64);
  }

  static Future<void> printContract(String contractId) async {
    final bytes = await build(contractId);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<void> shareContract(String contractId) async {
    final bytes = await build(contractId);
    await Printing.sharePdf(bytes: bytes, filename: 'contract_$contractId.pdf');
  }
}
