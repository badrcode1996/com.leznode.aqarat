import 'package:flutter_test/flutter_test.dart';

import 'package:aqarat/models/contract_model.dart';
import 'package:aqarat/models/enums.dart';
import 'package:aqarat/services/pdf/contract_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rent contract PDF builds without throwing', () async {
    final now = DateTime.now();
    final c = RentContract(
      id: 'x',
      companyId: 'c',
      agentId: 'a',
      createdAt: now,
      contractNumber: 5,
      party1Name: 'خاوەن',
      party1Mobile: '0750',
      party2Name: 'کرێچی',
      party2Mobile: '0751',
      propertyType: 'شوقە',
      projectName: 'ئاشتی',
      propertyNumber: '12',
      area: 120,
      rentAmount: 500,
      currency: Currency.iqd,
      rentalPeriodMonths: 12,
      downPayment: 1000,
      downPaymentMonths: 2,
      startDate: now,
      handoverDate: now,
      paymentFrequencyMonths: 1,
      guaranteeAmount: 200,
      gracePeriod: '10 ڕۆژ',
      rentalPurpose: 'نیشتەجێبوون',
      lateFeePerDay: 10,
      installments:
          RentContract.buildSchedule(now, everyMonths: 1, prepaidMonths: 2),
    );

    final bytes = await ContractPdfService.build(c);
    expect(bytes.isNotEmpty, true);
  });
}
