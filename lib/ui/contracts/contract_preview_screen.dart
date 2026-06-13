import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../models/company_model.dart';
import '../../models/contract_model.dart';
import '../../services/pdf/contract_pdf_service.dart';

/// On-screen PDF preview of a contract. The [PdfPreview] toolbar also exposes
/// print and share, so this is a one-stop view → print/share screen.
class ContractPreviewScreen extends StatelessWidget {
  const ContractPreviewScreen({
    super.key,
    required this.contract,
    this.company,
  });

  final Contract contract;
  final Company? company;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('گرێبەست #${contract.contractNumber}')),
      body: PdfPreview(
        build: (_) => ContractPdfService.build(contract, company: company),
        // Pin the page format so PdfPreview never derives it from the printer
        // list (which can be empty → "Bad state: No element").
        initialPageFormat: PdfPageFormat.a4,
        pageFormats: const {'A4': PdfPageFormat.a4},
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: 'contract_${contract.contractNumber}.pdf',
        loadingWidget: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
