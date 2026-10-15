import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbro_app/core/l10n/l10n.dart';
import 'package:gymbro_app/features/home/home_screen.dart';

void main() {
  testWidgets('il foglio Crea non va in overflow su uno schermo piccolo, in francese', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    L10n.lang = 'fr';
    addTearDown(() {
      tester.view.reset();
      L10n.lang = 'it';
    });
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(onPressed: () => showQuickCreate(context), child: const Text('+')),
      ),
    ));
    await tester.tap(find.text('+'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Parcours de course'), 100, scrollable: find.byType(Scrollable).last);
    expect(find.text('Parcours de course'), findsOneWidget);
  });
}
