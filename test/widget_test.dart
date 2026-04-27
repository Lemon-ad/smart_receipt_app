import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('basic Flutter test harness is available', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Smart Receipt AI')));
    expect(find.text('Smart Receipt AI'), findsOneWidget);
  });
}
