import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aqarat/main.dart';

void main() {
  testWidgets('App boots to the demo login', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AqaratApp()));
    expect(find.text('چوونەژوورەوەی نموونە'), findsOneWidget);
  });
}
