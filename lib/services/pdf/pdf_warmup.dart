import 'package:cloud_functions/cloud_functions.dart';

/// Fire-and-forget warm-up ping for the PDF render Cloud Functions, so their
/// instances (and headless Chromium) are already running by the time the user
/// taps print — kills the 10-20s cold start. Throttled to once per 2 minutes.
class PdfWarmup {
  static DateTime? _last;

  static void ping() {
    final now = DateTime.now();
    if (_last != null && now.difference(_last!) < const Duration(minutes: 2)) {
      return;
    }
    _last = now;
    _ping('renderReceiptPdf');
    _ping('renderContractPdf');
  }

  static Future<void> _ping(String fn) async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable(fn)
          .call<dynamic>({'warmup': true});
    } catch (_) {
      // Warm-up is best-effort — never surface errors.
    }
  }
}
