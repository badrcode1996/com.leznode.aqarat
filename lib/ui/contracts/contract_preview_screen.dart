import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../models/company_model.dart';
import '../../models/contract_model.dart';
import '../../services/pdf/contract_pdf_service.dart';

/// On-screen PDF preview. Builds the bytes, rasterizes the pages to images and
/// shows them. Both steps are guarded so a failure surfaces the real error
/// instead of a blank red screen, and print/share always work regardless.
class ContractPreviewScreen extends StatefulWidget {
  const ContractPreviewScreen({
    super.key,
    required this.contract,
    this.company,
  });

  final Contract contract;
  final Company? company;

  @override
  State<ContractPreviewScreen> createState() => _ContractPreviewScreenState();
}

class _ContractPreviewScreenState extends State<ContractPreviewScreen> {
  late final Future<List<Uint8List>> _pages = _render();

  Future<List<Uint8List>> _render() async {
    final bytes =
        await ContractPdfService.build(widget.contract, company: widget.company);
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('هەڵە: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('گرێبەست #${widget.contract.contractNumber}'),
        actions: [
          IconButton(
            tooltip: 'هاوبەشکردن',
            icon: const Icon(Icons.share),
            onPressed: () => _run(() => ContractPdfService.shareContract(
                widget.contract,
                company: widget.company)),
          ),
          IconButton(
            tooltip: 'پرینت',
            icon: const Icon(Icons.print),
            onPressed: () => _run(() => ContractPdfService.printContract(
                widget.contract,
                company: widget.company)),
          ),
        ],
      ),
      body: FutureBuilder<List<Uint8List>>(
        future: _pages,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || (snap.data?.isEmpty ?? true)) {
            return _ErrorFallback(error: snap.error);
          }
          final pages = snap.data!;
          return Container(
            color: Colors.grey.shade300,
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: pages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => Material(
                elevation: 2,
                child: Image.memory(pages[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ErrorFallback extends StatelessWidget {
  const _ErrorFallback({this.error});
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf, size: 48, color: Colors.black38),
            const SizedBox(height: 12),
            const Text('پێشبینین نەکرایەوە. دەتوانیت پرینت یان هاوبەشی بکەیت.',
                textAlign: TextAlign.center),
            if (error != null) ...[
              const SizedBox(height: 8),
              SelectableText('$error',
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 12, color: Colors.black45)),
            ],
          ],
        ),
      ),
    );
  }
}
