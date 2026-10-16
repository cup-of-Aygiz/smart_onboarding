import 'package:flutter/material.dart';
import 'package:smart_onboarding/smart_onboarding.dart';

void main() => runApp(const ExampleApp());

/// Target ids in one place to avoid typos.
abstract final class Ids {
  static const search = 'search';
  static const profile = 'profile';
  static const fab = 'fab';
  static const tabHome = 'tab_home';
  static const tabFeed = 'tab_feed';
  static const tabSettings = 'tab_settings';
  static const card = 'card';
  static const deepItem = 'deep_item';
  static const details = 'details_save';
}

final navigatorKey = GlobalKey<NavigatorState>();

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  late final OnboardingController onboarding = OnboardingController(
    onStepShown: (step, i) => debugPrint('[analytics] shown ${step.id}'),
    onStepCompleted: (step, i, reason) =>
        debugPrint('[analytics] ${step.id} completed: ${reason.name}'),
    onSkip: (step, i) => debugPrint('[analytics] skipped at ${step.id}'),
    // Persisting "already shown" is the app's job, e.g. SharedPreferences.
    onFinish: (result) => debugPrint('[analytics] finished: ${result.name}'),
  );

  @override
  void dispose() {
    onboarding.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      // The only integration point: wrap the navigator.
      builder: SmartOnboarding.builder(
        controller: onboarding,
        theme: const OnboardingTheme(skipLabel: 'Пропустить'),
      ),
      home: HomePage(onboarding: onboarding),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onboarding});

  final OnboardingController onboarding;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;

  OnboardingController get onboarding => widget.onboarding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart onboarding'),
        actions: [
          OnboardingTarget(
            id: Ids.search,
            child: IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
          ),
          OnboardingTarget(
            id: Ids.profile,
            child: IconButton(
              onPressed: () {},
              icon: const Icon(Icons.account_circle),
            ),
          ),
        ],
      ),
      // A non-lazy scroll view: every target exists from the start, so
      // auto-scroll can reach the bottom item. For lazy lists, scroll in
      // `onBeforeShow` first (see README).
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: () => onboarding.start(codeSteps()),
              child: const Text('Онбординг из кода'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => onboarding.start(jsonSteps()),
              child: const Text('Онбординг из JSON'),
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) => OutlinedButton(
                onPressed: () => showSmartTooltip(
                  context,
                  target: const OnboardingTargetRef.id(Ids.fab),
                  arrow: const OnboardingArrow.curved(color: Colors.indigo),
                  duration: const Duration(seconds: 3),
                  builder: (_) =>
                      const _Bubble('Отдельный тултип без затемнения'),
                ),
                child: const Text('Просто тултип у FAB'),
              ),
            ),
            const SizedBox(height: 16),
            OnboardingTarget(
              id: Ids.card,
              child: const Card(
                child: ListTile(
                  leading: Icon(Icons.star),
                  title: Text('Карточка'),
                  subtitle: Text('Подсвечивается вместе с FAB'),
                ),
              ),
            ),
            for (var i = 0; i < 25; i++) ListTile(title: Text('Элемент $i')),
            OnboardingTarget(
              id: Ids.deepItem,
              child: ListTile(
                tileColor: Colors.amber.shade100,
                title: const Text('Далеко внизу — к нему прокрутится'),
                onTap: () => navigatorKey.currentState!.push(
                  MaterialPageRoute<void>(builder: (_) => const DetailsPage()),
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: OnboardingTarget(
        id: Ids.fab,
        child: FloatingActionButton(
          onPressed: () {},
          child: const Icon(Icons.add),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(
            icon: OnboardingTarget(id: Ids.tabHome, child: Icon(Icons.home)),
            label: 'Главная',
          ),
          NavigationDestination(
            icon: OnboardingTarget(id: Ids.tabFeed, child: Icon(Icons.feed)),
            label: 'Лента',
          ),
          NavigationDestination(
            icon: OnboardingTarget(
              id: Ids.tabSettings,
              child: Icon(Icons.settings),
            ),
            label: 'Настройки',
          ),
        ],
      ),
    );
  }

  List<OnboardingStep> codeSteps() => [
    // Centered welcome without targets.
    OnboardingStep(
      id: 'welcome',
      content: OnboardingContent.tooltip(
        title: 'Привет!',
        text: 'Покажу, что тут есть. Шаг закроется сам через 4 секунды.',
      ),
      advance: const StepAdvance.timer(Duration(seconds: 4)),
    ),
    // Tap on the real button counts as the step.
    OnboardingStep(
      id: 'search',
      highlights: [
        OnboardingHighlight.id(
          Ids.search,
          shape: const HighlightShape.circle(),
        ),
      ],
      content: OnboardingContent.tooltip(
        title: 'Поиск',
        text: 'Нажми на лупу — кнопка сработает и шаг засчитается.',
        showNext: false,
      ),
      advance: const StepAdvance(tap: TapToAdvance.target),
    ),
    // Several targets at once with staggered arrows.
    OnboardingStep(
      id: 'pair',
      highlights: [
        OnboardingHighlight.id(Ids.card),
        OnboardingHighlight.id(Ids.fab, shape: const HighlightShape.circle()),
      ],
      content: OnboardingContent.tooltip(
        text: 'Карточка и кнопка подсвечены одновременно.',
      ),
      advance: const StepAdvance.timer(
        Duration(seconds: 5),
        progress: ProgressPlacement.top,
      ),
    ),
    // One step walks through tabs one by one.
    OnboardingStep.sequence(
      id: 'tabs',
      groups: [
        HighlightGroup(
          highlights: [OnboardingHighlight.id(Ids.tabHome)],
          content: OnboardingContent.tooltip(text: 'Главная'),
        ),
        HighlightGroup(
          highlights: [OnboardingHighlight.id(Ids.tabFeed)],
          content: OnboardingContent.tooltip(text: 'Лента'),
        ),
        HighlightGroup(
          highlights: [
            OnboardingHighlight.id(
              Ids.tabSettings,
              arrow: const OnboardingArrow.widget(
                child: Icon(Icons.arrow_upward, color: Colors.amber, size: 40),
              ),
            ),
          ],
          content: OnboardingContent(
            // Fully custom content pinned to a fixed spot on screen.
            placement: const ContentPlacement.aligned(Alignment(0, -0.3)),
            builder: (context, info) => _Bubble(
              'Настройки. Своя картинка вместо стрелки, контент прибит к месту.',
              onTap: info.next,
            ),
          ),
        ),
      ],
      advance: const StepAdvance.tap(),
    ),
    // Arrow without any content.
    OnboardingStep(
      id: 'profile',
      highlights: [
        OnboardingHighlight.id(
          Ids.profile,
          shape: const HighlightShape.circle(),
          arrow: const OnboardingArrow.curved(dashed: true),
        ),
      ],
      advance: const StepAdvance.timer(
        Duration(seconds: 3),
        progress: ProgressPlacement.bottom,
      ),
    ),
    // Auto-scroll to an item far below; tapping it navigates.
    OnboardingStep(
      id: 'deep',
      highlights: [OnboardingHighlight.id(Ids.deepItem)],
      content: OnboardingContent.tooltip(
        text: 'Список прокрутился сам. Нажми на элемент — откроется экран.',
        showNext: false,
      ),
    ),
    // Target lives on the next screen: onboarding waits for it.
    OnboardingStep(
      id: 'details',
      highlights: [OnboardingHighlight.id(Ids.details)],
      content: OnboardingContent.tooltip(
        title: 'Другой экран',
        text: 'Онбординг дождался навигации.',
      ),
      advance: const StepAdvance(tap: TapToAdvance.anywhere),
    ),
  ];

  List<OnboardingStep> jsonSteps() =>
      const OnboardingJsonParser().parseString('''
    [
      {"id": "j1", "highlights": [{"target": "fab", "shape": "circle"}],
       "content": {"title": "Из JSON", "text": "Шаг пришёл с бэкенда", "placement": "start"},
       "advance": {"timerMs": 3000, "tap": "anywhere"}},
      {"id": "j2", "sequence": [
        {"highlights": ["tab_home"], "content": {"text": "Сначала эта"}},
        {"highlights": ["tab_feed", "tab_settings"], "content": {"text": "Потом эти две"}}
      ], "advance": {"tap": "anywhere", "progress": "none"}, "blur": 0}
    ]
    ''');
}

class DetailsPage extends StatelessWidget {
  const DetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Детали')),
      body: Center(
        child: OnboardingTarget(
          id: Ids.details,
          child: FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.save),
            label: const Text('Сохранить'),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.text, {this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.amber,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
