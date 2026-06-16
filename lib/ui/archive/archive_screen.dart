import 'package:flutter/material.dart';

import '../contracts/contracts_screen.dart';
import '../receipts/receipts_screen.dart';

const Color _primaryDarkBlue = Color(0xFF0F2C59);
const Color _accentYellow = Color(0xFFF8B115);
const Color _appBg = Color(0xFFF5F7FA);

/// Archive tab: all records, organised as two top sections — contracts and
/// receipts — each with its own rent/sale (or rent/external) sub-tabs.
class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _appBg,
        appBar: AppBar(
          title: const Text('ئەرشیف',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          backgroundColor: _primaryDarkBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          bottom: const TabBar(
            indicatorColor: _accentYellow,
            indicatorWeight: 4,
            labelColor: _accentYellow,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            tabs: [
              Tab(text: 'گرێبەستەکان'),
              Tab(text: 'پسولەکان'),
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
