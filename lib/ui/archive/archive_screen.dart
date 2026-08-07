import 'package:flutter/material.dart';

import '../../services/pdf/pdf_warmup.dart';
import '../contracts/contracts_screen.dart';
import '../receipts/receipts_screen.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';

Color get _primaryDarkBlue => AppColors.current.brand;
Color get _accentYellow => AppColors.current.accent;
Color get _appBg => AppColors.current.pageBg;

/// Archive tab: all records, organised as two top sections — contracts and
/// receipts — each with its own rent/sale (or rent/external) sub-tabs.
class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Warm the PDF render functions as soon as the archive opens, so a print
    // tap moments later doesn't hit a cold instance (throttled internally).
    PdfWarmup.ping();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _appBg,
        appBar: AppBar(
          title: Text(S.archiveTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          backgroundColor: _primaryDarkBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          bottom: TabBar(
            indicatorColor: _accentYellow,
            indicatorWeight: 4,
            labelColor: _accentYellow,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            tabs: [
              Tab(text: S.tabContracts),
              Tab(text: S.tabReceipts),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ContractsArchiveBody(),
            ReceiptsArchiveBody(),
          ],
        ),
      ),
    );
  }
}
