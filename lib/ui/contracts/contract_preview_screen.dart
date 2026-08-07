import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../data/plan_config_repository.dart';
import '../../models/company_model.dart';
import '../../models/contract_model.dart';
import '../../models/contract_template_model.dart';
import '../../services/pdf/contract_pdf_remote.dart';
import '../../theme/app_colors.dart';

// ڕەنگە سەرەکییەکان بۆ یەکپارچەیی دیزاینەکە
Color get primaryDarkBlue => AppColors.current.brand;
Color get accentYellow => AppColors.current.accent;
Color get appBackgroundColor => AppColors.current.pageBg;

/// On-screen PDF preview. Builds the bytes, rasterizes the pages to images and
/// shows them. Both steps are guarded so a failure surfaces the real error
/// instead of a blank red screen, and print/share always work regardless.
class ContractPreviewScreen extends ConsumerStatefulWidget {
  const ContractPreviewScreen({
    super.key,
    required this.contract,
    this.company,
    this.template,
    this.initialLang = 'ku',
  });

  final Contract contract;
  final Company? company;
  final ContractTemplate? template;

  /// Which edition to open on — 'ku' or 'ar'. Set by the stepper (the language
  /// picked while creating the contract) and by the archive's long-press menu.
  final String initialLang;

  @override
  ConsumerState<ContractPreviewScreen> createState() =>
      _ContractPreviewScreenState();
}

class _ContractPreviewScreenState
    extends ConsumerState<ContractPreviewScreen> {
  /// 'ku' or 'ar' — which edition of the document is on screen.
  late String _lang = widget.initialLang;

  late Future<List<Uint8List>> _pages = _render();

  /// The rendered PDF bytes, cached from the preview render so print/share can
  /// fire synchronously inside the button's tap — on web the browser only opens
  /// the print dialog while the user gesture is still alive, so we must not
  /// `await` a network call between the tap and [Printing.layoutPdf].
  Uint8List? _pdfBytes;

  Future<List<Uint8List>> _render() async {
    final bytes =
        await ContractPdfRemote.build(widget.contract.id, lang: _lang);
    _pdfBytes = bytes;
    final images = <Uint8List>[];
    await for (final page in Printing.raster(bytes, dpi: 110)) {
      images.add(await page.toPng());
    }
    return images;
  }

  /// Prints the contract. Uses the cached bytes when available so the call to
  /// [Printing.layoutPdf] stays inside the tap gesture (required on web).
  Future<void> _print() async {
    final bytes = _pdfBytes;
    if (bytes != null) {
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } else {
      await ContractPdfRemote.printContract(widget.contract.id, lang: _lang);
    }
  }

  /// Re-renders the same contract in the other language. The cached bytes must
  /// go with it, or print/share would emit the edition no longer on screen.
  void _setLang(String lang) {
    if (lang == _lang) return;
    setState(() {
      _lang = lang;
      _pdfBytes = null;
      _pages = _render();
    });
  }

  /// Shares the contract, reusing the cached bytes when available.
  Future<void> _share() async {
    final bytes = _pdfBytes;
    if (bytes != null) {
      await Printing.sharePdf(
          bytes: bytes,
          filename: 'contract_${widget.contract.id}_$_lang.pdf');
    } else {
      await ContractPdfRemote.shareContract(widget.contract.id, lang: _lang);
    }
  }

  /// Two pills in the app bar. Deliberately not a dropdown: there are exactly
  /// two editions and the user needs to see at a glance which one is printing.
  Widget _langToggle() => Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.current.card.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _langPill('کوردی', 'ku'),
            _langPill('عەرەبی', 'ar'),
          ],
        ),
      );

  Widget _langPill(String text, String lang) {
    final active = _lang == lang;
    return GestureDetector(
      onTap: () => _setLang(lang),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? accentYellow : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: active ? AppColors.current.textStrong : Colors.white70,
          ),
        ),
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('هەڵە: $e', style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: AppColors.current.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Arabic needs BOTH the plan feature and this company's Arabic clauses for
  /// THIS contract type — an Arabic rent template says nothing about sales.
  bool get _canArabic {
    // A null template means it has not loaded yet, not that the company opted
    // out — the built-in template always carries the Arabic clauses.
    final tpl = widget.template ?? ContractTemplate.defaults();
    if (!tpl.arabicReadyFor(widget.contract)) return false;
    return ref.watch(currentPlanFeaturesProvider).arabicContracts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackgroundColor,
      appBar: AppBar(
        title: Text(
          'گرێبەست #${widget.contract.contractNumber}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: primaryDarkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_canArabic) _langToggle(),
          IconButton(
            tooltip: 'هاوبەشکردن',
            icon: const Icon(Icons.share_rounded),
            onPressed: () => _run(_share),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8, start: 8),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: accentYellow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                tooltip: 'پرینت',
                icon: Icon(Icons.print_rounded, color: AppColors.current.onAccent),
                onPressed: () => _run(_print),
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<Uint8List>>(
        future: _pages,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(
              child: CircularProgressIndicator(color: AppColors.current.textStrong, strokeWidth: 3),
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
                color: AppColors.current.card,
                borderRadius: BorderRadius.circular(4), // گۆشەی زۆر کەم بۆ ئەوەی وەک کاغەز بێت
                boxShadow: [
                  BoxShadow(
                    color: AppColors.current.shadow,
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.memory(
                  pages[i],
                  fit: BoxFit.contain,
                ),
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
    // Show the first few stack frames to pinpoint the source of the error.
    final frames = stack?.toString().split('\n').take(8).join('\n') ?? '';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.current.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.current.shadow,
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
                child: Icon(Icons.picture_as_pdf_rounded, size: 48, color: accentYellow),
              ),
              const SizedBox(height: 16),
              Text(
                'کێشە لە پێشبینینی فایلی PDF',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.current.textStrong),
              ),
              const SizedBox(height: 8),
              Text(
                'پێشبینین نەکرایەوە لەسەر شاشەکە، بەڵام هێشتا دەتوانیت لە ڕێگەی دوگمەکانی سەرەوە پرینتی بکەیت یان هاوبەشی پێ بکەیت.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.current.textMuted, height: 1.5),
              ),
              if (error != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.current.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    '$error',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.current.danger),
                  ),
                ),
              ],
              if (frames.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.current.inputFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.current.divider),
                  ),
                  child: SelectableText(
                    frames,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(fontSize: 10, color: AppColors.current.textBody, fontFamily: 'monospace'),
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