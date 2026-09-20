import 'package:flutter_test/flutter_test.dart';
import 'package:aqarat/models/receipt_model.dart';

/// The line printed on a rent voucher. What matters is the date after
/// "تاکو": one voucher can settle several months, and it then has to run to
/// the end of the LAST month it covers, not the first.
void main() {
  test('a single month runs to the day before the next due date', () {
    expect(
      Receipt.rentPurpose(DateTime(2026, 7, 25)),
      contains('24-8-2026'),
    );
  });

  test('three months run to the end of the third', () {
    expect(
      Receipt.rentPurpose(DateTime(2026, 7, 25),
          lastDueDate: DateTime(2026, 9, 25)),
      allOf(contains('25-7-2026'), contains('24-10-2026')),
    );
  });

  test('the end comes from the last due date, not a month count', () {
    // February is short, and installments are not always a month apart.
    // Taking the end off the real due date is what keeps both right.
    expect(
      Receipt.rentPurpose(DateTime(2026, 1, 31),
          lastDueDate: DateTime(2026, 2, 28)),
      contains('27-3-2026'),
    );
  });
}
