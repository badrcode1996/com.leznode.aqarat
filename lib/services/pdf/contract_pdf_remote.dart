import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:printing/printing.dart';
import '../../l10n/app_strings.dart';

/// Contract PDFs are rendered server-side by the `renderContractPdf` Cloud
/// Function (headless Chrome) so Kurdish/Arabic letter shaping — especially
/// ێ — is correct. The function takes the saved contract's id and returns the
/// PDF bytes.
class ContractPdfRemote {
  /// [lang] is 'ku' or 'ar'. Arabic is a paid feature and needs the company's
  /// Arabic clauses on file; the function rejects the request when either is
  /// missing, so callers should only offer it when [ContractTemplate
  /// .arabicReadyFor] and the plan both say yes.
  static Future<Uint8List> build(String contractId,
      {String lang = 'ku'}) async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('renderContractPdf');
    final res = await callable.call<Map<dynamic, dynamic>>({
      'contractId': contractId,
      'lang': lang,
    });
    final b64 = res.data['pdf_base64'] as String?;
    if (b64 == null || b64.isEmpty) {
      throw Exception(S.emptyFunctionResponse);
    }
    return base64Decode(b64);
  }

  static Future<void> printContract(String contractId,
      {String lang = 'ku'}) async {
    final bytes = await build(contractId, lang: lang);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<void> shareContract(String contractId,
      {String lang = 'ku'}) async {
    final bytes = await build(contractId, lang: lang);
    await Printing.sharePdf(
        bytes: bytes,
        filename: 'contract_${contractId}_$lang.pdf');
  }
}
