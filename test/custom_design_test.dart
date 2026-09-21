import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aqarat/models/company_model.dart';

/// The app marks companies with bespoke paperwork in the Super Admin list, but
/// what actually decides is the REGISTRY in functions/designs/index.js, which
/// only ever runs on the server. The two are kept in step by hand, so this
/// reads the registry and holds the Dart copy to it — otherwise onboarding a
/// company server-side would quietly leave its card looking ordinary.
void main() {
  test('Company.customDesignIds matches the server design registry', () {
    final js = File('functions/designs/index.js').readAsStringSync();

    final start = js.indexOf('const REGISTRY = {');
    expect(start, isNot(-1), reason: 'REGISTRY not found in designs/index.js');
    final body = js.substring(start, js.indexOf('};', start));

    final ids = <String>{};
    for (final line in body.split('\n')) {
      // Commented-out entries are examples, not registered companies.
      if (line.trimLeft().startsWith('//')) continue;
      final m = RegExp(r'''["']([A-Za-z0-9_]+)["']\s*:''').firstMatch(line);
      if (m != null) ids.add(m.group(1)!);
    }

    expect(ids, isNotEmpty, reason: 'no company ids parsed out of REGISTRY');
    expect(Company.customDesignIds, ids);
  });
}
