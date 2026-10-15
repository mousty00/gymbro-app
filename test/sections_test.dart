import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbro_app/core/config/env.dart';
import 'package:gymbro_app/features/auth/session.dart';
import 'package:gymbro_app/features/shell/sections.dart';
import 'package:gymbro_app/models/user.dart';

void main() {
  setUp(() => Env.useMock = true);
  tearDown(() => Env.useMock = false);

  Future<void> open(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [currentUserProvider.overrideWithValue(const User(id: 'u1', username: 'mousty'))],
      child: MaterialApp(home: screen),
    ));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> tapAndCheck(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).first);
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull, reason: label);
  }

  testWidgets('Allenati: Schede, Corsa ed Esercizi nella stessa tab', (tester) async {
    await open(tester, const TrainScreen());
    expect(tester.takeException(), isNull);
    await tapAndCheck(tester, 'Corsa');
    expect(find.text('Corsa libera'), findsOneWidget);
    await tapAndCheck(tester, 'Esercizi');
    expect(find.text('Tutti'), findsOneWidget);
    await tapAndCheck(tester, 'Schede');
  });

  testWidgets('Community: Feed, Esplora e Amici nella stessa tab', (tester) async {
    await open(tester, const CommunityScreen());
    expect(tester.takeException(), isNull);
    await tapAndCheck(tester, 'Esplora');
    await tapAndCheck(tester, 'Amici');
    expect(find.text('Cerca per username'), findsOneWidget);
  });
}
