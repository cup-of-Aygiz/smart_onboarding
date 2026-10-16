import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_onboarding_example/main.dart';

Future<void> frames(WidgetTester tester, [int n = 60]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('code onboarding runs end to end on a phone screen', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(const ExampleApp());
    await tester.tap(find.text('Онбординг из кода'));
    await frames(tester);
    expect(find.text('Привет!'), findsOneWidget);

    // welcome: 4s timer
    await tester.pump(const Duration(seconds: 4));
    await frames(tester);
    expect(find.text('Поиск'), findsOneWidget);

    // search: tap the real button
    await tester.tap(find.byIcon(Icons.search));
    await frames(tester);
    expect(
      find.text('Карточка и кнопка подсвечены одновременно.'),
      findsOneWidget,
    );

    // pair: 5s timer
    await tester.pump(const Duration(seconds: 5));
    await frames(tester);

    // tabs sequence: three taps anywhere
    for (var i = 0; i < 3; i++) {
      await tester.tapAt(const Offset(200, 400));
      await frames(tester);
    }

    // profile: arrow only, 3s timer
    await tester.pump(const Duration(seconds: 3));
    await frames(tester, 90);
    expect(
      find.text('Список прокрутился сам. Нажми на элемент — откроется экран.'),
      findsOneWidget,
    );

    // deep item: scrolled into view, tap navigates
    await tester.tap(find.text('Далеко внизу — к нему прокрутится'));
    await frames(tester, 90);
    expect(find.text('Онбординг дождался навигации.'), findsOneWidget);

    await tester.tapAt(const Offset(200, 600));
    await frames(tester);
    expect(find.text('Онбординг дождался навигации.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('json onboarding and standalone tooltip', (tester) async {
    phone(tester);
    await tester.pumpWidget(const ExampleApp());
    await tester.tap(find.text('Просто тултип у FAB'));
    await frames(tester);
    expect(find.text('Отдельный тултип без затемнения'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await frames(tester);
    expect(find.text('Отдельный тултип без затемнения'), findsNothing);

    await tester.tap(find.text('Онбординг из JSON'));
    await frames(tester);
    expect(find.text('Шаг пришёл с бэкенда'), findsOneWidget);
    await tester.tap(find.text('Пропустить'));
    await frames(tester);
    expect(find.text('Шаг пришёл с бэкенда'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
