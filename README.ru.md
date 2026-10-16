# smart_onboarding

[English](README.md) | **Русский**

Spotlight-онбординг для Flutter без сторонних зависимостей.

- Находит виджеты по строковому id (`OnboardingTarget`) или по `GlobalKey`.
- Затемняет и размывает всё вокруг, вырезая «дырки» по форме: прямоугольник, круг, капсула или свой `Path`.
- Подсвечивает несколько виджетов одновременно или по очереди внутри одного шага.
- Сам выбирает место для контента. Контент может быть любым виджетом, его позицию можно закрепить.
- Рисует анимированные изогнутые стрелки. Их можно заменить своей картинкой или виджетом или отключить.
- Шаги закрываются по таймеру (с полоской прогресса), по тапу (по цели, вне её или в любом месте) или через `controller.next()`.
- Ждёт навигацию, если цель на другом экране, и сам прокручивает список к цели.
- Пересчитывает положение при скролле, повороте экрана и открытии клавиатуры. Поддерживает RTL.
- Шаги можно описать в коде или загрузить из JSON.

## Подключение

```dart
final onboarding = OnboardingController(
  onFinish: (result) => prefs.setBool('onboarding_done', true), // хранение — на стороне приложения
);

MaterialApp(
  builder: SmartOnboarding.builder(controller: onboarding),
  home: const HomePage(),
);
```

Отметьте виджеты:

```dart
OnboardingTarget(
  id: 'search',
  child: IconButton(icon: const Icon(Icons.search), onPressed: () {}),
)
```

Запустите онбординг:

```dart
onboarding.start([
  OnboardingStep(
    id: 'search',
    highlights: [OnboardingHighlight.id('search', shape: const HighlightShape.circle())],
    content: OnboardingContent.tooltip(title: 'Поиск', text: 'Ищите здесь'),
    advance: const StepAdvance(tap: TapToAdvance.target), // нажатие на кнопку засчитывает шаг
  ),
]);
```

## Id или GlobalKey

Используйте `OnboardingTarget(id:)` везде, где можно. Id — это обычная строка: её можно указать в любом месте кода и в JSON, она работает между экранами, и у нескольких виджетов может быть одинаковый id (нужный выбирается через `occurrence`).
`OnboardingHighlight.key(globalKey)` оставлен для виджетов, которые неудобно оборачивать.

## Шаги

| Что нужно | Как |
| --- | --- |
| Несколько целей сразу | `OnboardingStep(highlights: [a, b])` |
| Цели по очереди в одном шаге | `OnboardingStep.sequence(groups: [HighlightGroup(...), ...])` |
| Шаг без цели (по центру) | `OnboardingStep(content: ...)` без `highlights` |
| Только стрелка, без текста | `highlights: [OnboardingHighlight.id('x', arrow: OnboardingArrow.curved())]` без `content` |
| Таймер | `StepAdvance.timer(Duration(seconds: 4), progress: ProgressPlacement.top)` |
| Только по нажатию | `StepAdvance.tap(TapToAdvance.anywhere / target / outside)` |
| Только из кода | `StepAdvance.manual()` + `controller.next()` |
| Разрешить нажатия вне подсветки | `blockOutside: false` |
| Подсвеченный виджет не нажимается | `OnboardingHighlight(..., interactive: false)` |
| Условие показа | `condition: () async => !user.hasAvatar` |
| Подготовка (навигация, скролл, загрузка) | `onBeforeShow: () async => ...` |
| Цель не нашлась | `missingTarget: MissingTargetBehavior.skip / showAvailable`, `targetTimeout` |

Управление: `next()` переходит к следующей группе или шагу, `nextStep()` — к следующему шагу, `goTo(id)` — к шагу по id, `skip()` пропускает всё («Пропустить»), `stop()` останавливает онбординг.
Для аналитики есть колбэки `onStepShown`, `onGroupShown`, `onStepCompleted(reason)`, `onTargetMissing`, `onSkip` и `onFinish`.

## Контент

```dart
OnboardingContent(
  builder: (context, info) => MyCard(onNext: info.next, timer: info.timer),
  placement: const ContentPlacement.auto(preferred: [ContentSide.top]),
  // или .side(ContentSide.end), .aligned(Alignment.bottomCenter), .custom((bounds, size, anchor) => Offset(...))
  arrow: const OnboardingArrow.curved(dashed: true),
)
```

Внутри контента доступны `OnboardingStepInfo.of(context)` и `OnboardingTimerBar()`.

Стрелки: `OnboardingArrow.curved(...)`, `OnboardingArrow.widget(child: Image.asset(...))` (виджет поворачивается в сторону цели), `OnboardingArrow.custom((ctx, geometry, progress) => ...)` и `OnboardingArrow.none`. Если целей несколько, стрелки появляются по очереди, задержка задаётся в `arrowStagger`.

## Тема и анимации

```dart
SmartOnboarding.builder(
  controller: onboarding,
  theme: const OnboardingTheme(
    overlayColor: Color(0xB3000000),
    blurSigma: 3,
    padding: EdgeInsets.all(8),
    shape: HighlightShape.rect(radius: 12),
    animation: OnboardingAnimation(pulse: false), // или OnboardingAnimation.none
    skipLabel: 'Пропустить',
  ),
)
```

## Отдельный тултип

Тултип без затемнения, который сам выбирает, куда встать, и следует за целью:

```dart
final handle = showSmartTooltip(
  context,
  target: const OnboardingTargetRef.id('fab'),
  arrow: const OnboardingArrow.curved(color: Colors.indigo),
  duration: const Duration(seconds: 3),
  builder: (_) => const Text('Новое!'),
);
```

Для своих сценариев есть низкоуровневый виджет `SmartTooltipLayer`: он размещает контент и стрелки по переданным прямоугольникам.

## JSON

```dart
final steps = OnboardingJsonParser(
  conditions: {'isNewUser': () => user.isNew},
  contentFactories: {'promo': (json) => (context, info) => Promo(json['image'])},
).parseString(jsonFromBackend);
```

Формат описан в doc-комментарии `OnboardingJsonParser`.

## Ограничения

- Ленивые списки (`ListView.builder`) не строят элементы за экраном, поэтому такую цель найти нельзя. Прокрутите к ней в `onBeforeShow` (например, через `ScrollController.animateTo`), а дальше онбординг сам довернёт цель в центр.
- Положение цели обновляется после каждого кадра, поэтому при быстром скролле подсветка может отставать на один кадр.

## Использование с AI-ассистентами (Claude Code, Codex, Cursor)

В репозитории есть [AI_GUIDE.md](AI_GUIDE.md) — инструкция для агентов: пошаговое подключение, точные сигнатуры API, готовые рецепты и типичные ошибки. Чтобы агент подключил пакет в ваше приложение, добавьте в `CLAUDE.md` или `AGENTS.md` приложения:

```md
## Onboarding
We use the `smart_onboarding` package for spotlight onboarding.
Before writing onboarding code, read its AI_GUIDE.md
(in the package repository, or in the pub cache:
`~/.pub-cache/git/smart_onboarding-*/AI_GUIDE.md`; for a path dependency, at that path).
Target ids live in `lib/onboarding/onboarding_ids.dart`, steps in `lib/onboarding/onboarding_steps.dart`.
```

Или просто попросите агента: *«Подключи smart_onboarding по его AI_GUIDE.md»*.

## Лицензия

[MIT](LICENSE) — можно бесплатно использовать, изменять и распространять, в том числе в коммерческих проектах. Нужно лишь сохранить текст лицензии.
