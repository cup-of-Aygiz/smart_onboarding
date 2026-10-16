import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_onboarding/smart_onboarding.dart';

void main() {
  late OnboardingController controller;
  late List<String> log;

  setUp(() {
    log = [];
    controller = OnboardingController(
      onStepShown: (s, i) => log.add('shown:${s.id}'),
      onStepCompleted: (s, i, r) => log.add('done:${s.id}:${r.name}'),
      onFinish: (r) => log.add('finish:${r.name}'),
    );
  });

  tearDown(() => controller.dispose());

  Widget app({Widget? home, VoidCallback? onA}) => MaterialApp(
    builder: SmartOnboarding.builder(
      controller: controller,
      theme: const OnboardingTheme(animation: OnboardingAnimation.none),
    ),
    home:
        home ??
        Scaffold(
          body: Column(
            children: [
              OnboardingTarget(
                id: 'a',
                child: ElevatedButton(
                  onPressed: () {
                    log.add('tap:a');
                    onA?.call();
                  },
                  child: const Text('A'),
                ),
              ),
              const SizedBox(height: 200),
              const OnboardingTarget(id: 'b', child: Text('B')),
              const SizedBox(height: 200),
              const Text('outside'),
            ],
          ),
        ),
  );

  OnboardingStep step(
    String id,
    List<String> targets, {
    StepAdvance advance = const StepAdvance(),
    OnboardingContent? content,
  }) => OnboardingStep(
    id: id,
    highlights: [for (final t in targets) OnboardingHighlight.id(t)],
    advance: advance,
    content: content,
  );

  testWidgets('tap on interactive target reaches widget and advances', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    controller.start([
      step('s1', ['a']),
      step('s2', ['b']),
    ]);
    await tester.pumpAndSettle();
    expect(log, ['shown:s1']);

    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    expect(log, ['shown:s1', 'tap:a', 'done:s1:tapTarget', 'shown:s2']);
    expect(controller.currentStep?.id, 's2');
  });

  testWidgets('taps outside are blocked by default', (tester) async {
    await tester.pumpWidget(app());
    controller.start([
      step('s1', ['b']),
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('A'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(log, ['shown:s1']);
  });

  testWidgets('next() from app code advances once even after a tap', (
    tester,
  ) async {
    await tester.pumpWidget(app(onA: () => controller.next()));
    controller.start([
      step('s1', ['a']),
      step('s2', ['b']),
      step('s3', ['b']),
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    expect(controller.currentStep?.id, 's2');
  });

  testWidgets('timer advances and tooltip content renders', (tester) async {
    await tester.pumpWidget(app());
    controller.start([
      step(
        's1',
        ['a'],
        advance: const StepAdvance.timer(Duration(seconds: 2)),
        content: OnboardingContent.tooltip(title: 'Hello', text: 'World'),
      ),
    ]);
    // pumpAndSettle would run the 2s timer to the end.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);

    expect(log, ['shown:s1']);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(log, ['shown:s1', 'done:s1:timer', 'finish:completed']);
    expect(find.text('Hello'), findsNothing);
  });

  testWidgets('sequence walks through groups before next step', (tester) async {
    await tester.pumpWidget(app());
    controller.start([
      OnboardingStep.sequence(
        id: 'seq',
        groups: [
          HighlightGroup(highlights: [OnboardingHighlight.id('a')]),
          HighlightGroup(
            highlights: [
              OnboardingHighlight.id('a'),
              OnboardingHighlight.id('b'),
            ],
          ),
        ],
        advance: const StepAdvance.tap(),
      ),
    ]);
    await tester.pumpAndSettle();
    expect(controller.groupIndex, 0);
    await tester.tapAt(const Offset(390, 590));
    await tester.pumpAndSettle();
    expect(controller.groupIndex, 1);
    await tester.tapAt(const Offset(390, 590));
    await tester.pumpAndSettle();
    expect(log.last, 'finish:completed');
  });

  testWidgets('missing target is skipped after timeout', (tester) async {
    await tester.pumpWidget(app());
    controller.start([
      OnboardingStep(
        id: 'ghost',
        highlights: [OnboardingHighlight.id('nope')],
        targetTimeout: const Duration(seconds: 1),
      ),
      step('s2', ['b']),
    ]);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(log, ['done:ghost:targetMissing', 'shown:s2']);
  });

  testWidgets('waits for target on a pushed route', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        builder: SmartOnboarding.builder(
          controller: controller,
          theme: const OnboardingTheme(animation: OnboardingAnimation.none),
        ),
        home: const Scaffold(body: Text('home')),
      ),
    );
    controller.start([
      step('second', ['deep']),
    ]);
    await tester.pumpAndSettle();
    expect(log, isEmpty);

    navKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(
          body: Center(
            child: OnboardingTarget(id: 'deep', child: Text('deep')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(log, ['shown:second']);
  });

  testWidgets('condition false skips the step, skip() ends flow', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    controller.start([
      OnboardingStep(id: 'never', condition: () => false),
      step('s2', ['b']),
      step('s3', ['a']),
    ]);
    await tester.pumpAndSettle();
    expect(log, ['done:never:conditionFalse', 'shown:s2']);
    // Without a Material ancestor Flutter falls back to the yellow
    // double-underlined debug style.
    final skipStyle = DefaultTextStyle.of(tester.element(find.text('Skip')));
    expect(skipStyle.style.debugLabel, isNot(contains('fallback')));
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(log.last, 'finish:skipped');
    expect(controller.isActive, isFalse);
  });

  testWidgets('animated flow with arrows, blur and morph has no errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: SmartOnboarding.builder(controller: controller),
        home: const Scaffold(
          body: Column(
            children: [
              OnboardingTarget(id: 'a', child: Text('A')),
              SizedBox(height: 250),
              OnboardingTarget(id: 'b', child: Text('B')),
            ],
          ),
        ),
      ),
    );
    controller.start([
      OnboardingStep(
        id: 'both',
        highlights: [
          OnboardingHighlight.id('a', shape: const HighlightShape.circle()),
          OnboardingHighlight.id('b'),
        ],
        content: OnboardingContent.tooltip(text: 'Two at once'),
      ),
      OnboardingStep(
        id: 'one',
        highlights: [
          OnboardingHighlight.id(
            'b',
            arrow: const OnboardingArrow.widget(
              child: Icon(Icons.arrow_upward),
            ),
          ),
        ],
      ),
    ]);
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('Two at once'), findsOneWidget);
    await tester.tap(find.text('Next'));
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(controller.currentStep?.id, 'one');
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    controller.stop();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  test('json parser builds steps', () {
    const source = '''
    [
      {"id": "one", "highlights": [{"target": "a", "shape": "circle", "padding": 4}],
       "content": {"title": "T", "text": "x", "placement": "bottom"},
       "advance": {"timerMs": 3000, "tap": "anywhere", "progress": "top"}},
      {"id": "two", "sequence": [{"highlights": ["a"]}, {"highlights": ["a", "b"]}],
       "condition": "isNew", "blockOutside": false}
    ]''';
    final steps = OnboardingJsonParser(
      conditions: {'isNew': () => true},
    ).parseString(source);
    expect(steps, hasLength(2));
    expect(steps[0].advance.duration, const Duration(seconds: 3));
    expect(steps[0].advance.progress, ProgressPlacement.top);
    expect(
      steps[0].groups.single.highlights.single.shape,
      isA<CircleHighlightShape>(),
    );
    expect(steps[0].content!.placement, isA<SidePlacement>());
    expect(steps[1].groups, hasLength(2));
    expect(steps[1].groups[1].highlights, hasLength(2));
    expect(steps[1].blockOutside, isFalse);
  });
}
