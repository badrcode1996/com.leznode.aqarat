import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../models/company_model.dart';
import '../../models/contract_template_model.dart';
import '../../models/receipt_model.dart';
import '../../services/pdf/receipt_pdf_service.dart';

// ڕەنگە سەرەکییەکان بۆ یەکپارچەیی دیزاینەکە
const Color primaryDarkBlue = Color(0xFF0F2C59);
const Color accentYellow = Color(0xFFF8B115);
const Color appBackgroundColor = Color(0xFFF5F7FA);

/// On-screen PDF preview for a receipt (وەصڵ). Builds the bytes, rasterizes the
/// pages to images and shows them — same UX as [ContractPreviewScreen]. Both
/// steps are guarded so a failure surfaces the real error instead of a blank
/// red screen, and print/share always work regardless.
class ReceiptPreviewScreen extends StatefulWidget {
  const ReceiptPreviewScreen({
    super.key,
    required this.receipt,
    this.company,
    this.template,
  });

  final Receipt receipt;
  final Company? company;
  final ContractTemplate? template;

  @override
  State<ReceiptPreviewScreen> createState() => _ReceiptPreviewScreenState();
}

class _ReceiptPreviewScreenState extends State<ReceiptPreviewScreen> {
  late final Future<List<Uint8List>> _pages = _render();

  Future<List<Uint8List>> _render() async {
    final bytes = await ReceiptPdfService.build(widget.receipt,
        company: widget.company, template: widget.template);
    final images = <Uint8List>[];
    await for (final page in Printing.raster(bytes, dpi: 110)) {
      images.add(await page.toPng());
    }
    return images;
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('هەڵە: $e',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackgroundColor,
      appBar: AppBar(
        title: Text(
          'پسولە #${widget.receipt.receiptNumber}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: primaryDarkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'هاوبەشکردن',
            icon: const Icon(Icons.share_rounded),
            onPressed: () => _run(() => ReceiptPdfService.shareReceipt(
                widget.receipt,
                company: widget.company,
                template: widget.template)),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8, left: 8),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: accentYellow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                tooltip: 'پرینت',
                icon: const Icon(Icons.print_rounded, color: primaryDarkBlue),
                onPressed: () => _run(() => ReceiptPdfService.printReceipt(
                    widget.receipt,
                    company: widget.company,
                    template: widget.template)),
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<Uint8List>>(
        future: _pages,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(
                  color: primaryDarkBlue, strokeWidth: 3),
            );
          }
          if (snap.hasError || (snap.data?.isEmpty ?? true)) {
            return _ErrorFallback(error: snap.error, stack: snap.stackTrace);
          }
          final pages = snap.data!;
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            itemCount: pages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 24),
            itemBuilder: (_, i) => Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.memory(pages[i], fit: BoxFit.contain),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ErrorFallback extends StatelessWidget {
  const _ErrorFallback({this.error, this.stack});
  final Object? error;
  final StackTrace? stack;

  @override
  Widget build(BuildContext context) {
    final frames = stack?.toString().split('\n').take(8).join('\n') ?? '';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accentYellow.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.picture_as_pdf_rounded,
                    size: 48, color: accentYellow),
              ),
              const SizedBox(height: 16),
              const Text(
                'کێشە لە پێشبینینی فایلی PDF',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryDarkBlue),
              ),
              const SizedBox(height: 8),
              Text(
                'پێشبینین نەکرایەوە لەسەر شاشەکە، بەڵام هێشتا دەتوانیت لە ڕێگەی دوگمەکانی سەرەوە پرینتی بکەیت یان هاوبەشی پێ بکەیت.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: Colors.grey.shade600, height: 1.5),
              ),
              if (error != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    '$error',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                  ),
                ),
              ],
              if (frames.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SelectableText(
                    frames,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                        fontFamily: 'monospace'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
