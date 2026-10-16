# smart_onboarding — integration guide for AI coding agents

This file is written for Claude Code, Codex, Cursor and other coding agents
that add `smart_onboarding` to a Flutter app. It is precise on purpose:
follow it literally. Human-oriented docs: [README.md](README.md).

Import everything from one library:

```dart
import 'package:smart_onboarding/smart_onboarding.dart';
```

Never import from `package:smart_onboarding/src/...`.

## 1. Integration checklist

Do these steps in order. Stop and ask the user only when a step is ambiguous
for their app.

1. **Dependency.** Add to the app's `pubspec.yaml` (git or path, the package
   is not on pub.dev yet unless the user says otherwise), then run
   `flutter pub get`.
   ```yaml
   dependencies:
     smart_onboarding:
       git:
         url: https://github.com/cup-of-Aygiz/smart_onboarding.git
       # or: path: ../smart_onboarding
   ```
2. **Controller.** Create ONE `OnboardingController` that lives as long as the
   app (a field in the root `State`, a DI singleton, a Riverpod/Provider/GetIt
   object — match what the app already uses). Dispose it with the app.
3. **Host.** Put `SmartOnboarding` above the app's navigator. With
   `MaterialApp`/`CupertinoApp`/`MaterialApp.router` use `builder:`:
   ```dart
   MaterialApp(
     builder: SmartOnboarding.builder(controller: onboarding),
     // If the app already has a builder, keep it:
     // builder: SmartOnboarding.builder(controller: onboarding, builder: existingBuilder),
   )
   ```
   Exactly one `SmartOnboarding` per app. Do not wrap individual screens.
4. **Targets.** Wrap each widget to highlight with `OnboardingTarget`:
   ```dart
   OnboardingTarget(id: OnboardingIds.search, child: IconButton(...))
   ```
   Keep ids in one constants class (see §6). Wrapping does not change layout.
5. **Steps.** Build a `List<OnboardingStep>` (in code or from JSON) in a
   dedicated file, e.g. `lib/onboarding/onboarding_steps.dart`.
6. **Start.** Call `onboarding.start(steps)` when the user should see it —
   typically after the first screen is shown and only if the app has not
   stored "onboarding done". It is safe to call from `initState`.
7. **Persist.** The package stores nothing. Save completion in `onFinish`
   with the app's storage (SharedPreferences, Hive, backend...).
8. **Verify.** Run `flutter analyze`. Add a widget test (§8) if the app has
   tests.

## 2. Mental model

```
OnboardingController.start([steps])
  └─ OnboardingStep              one screen of explanation
       ├─ groups: [HighlightGroup]   shown one after another (sequence)
       │    └─ highlights: [OnboardingHighlight]   shown at the same time
       ├─ content: OnboardingContent?  widget placed next to the highlights
       └─ advance: StepAdvance         timer / tap / manual
```

- `OnboardingStep(highlights: [...])` = one group.
- `OnboardingStep.sequence(groups: [...])` = several groups in one step.
- `controller.next()` moves to the next group, then to the next step.
- A step is shown only when ALL its targets are on screen, laid out, on the
  current route and the route transition has finished. Until then the
  overlay is hidden and taps go to the app.

## 3. API reference (exact signatures)

### OnboardingController

```dart
OnboardingController({
  VoidCallback? onStart,
  void Function(OnboardingStep step, int index)? onStepShown,
  void Function(OnboardingStep step, int stepIndex, int groupIndex)? onGroupShown,
  void Function(OnboardingStep step, int index, StepCompletionReason reason)? onStepCompleted,
  void Function(OnboardingStep step, int index)? onTargetMissing,
  void Function(OnboardingStep step, int index)? onSkip,
  ValueChanged<OnboardingResult>? onFinish,
})

Future<OnboardingResult> start(List<OnboardingStep> steps, {int startAt = 0});
void next();        // next group or next step
void nextStep();    // next step, skipping remaining groups
void goTo(String stepId);
void skip();        // ends everything, reports OnboardingResult.skipped
void stop();        // ends everything, reports OnboardingResult.stopped

bool get isActive;
OnboardingStep? get currentStep;   // null while preparing or inactive
HighlightGroup? get currentGroup;
int get stepIndex;
int get groupIndex;
```

`enum OnboardingResult { completed, skipped, stopped }`
`enum StepCompletionReason { timer, tapTarget, tapOutside, manual, jump, skipped, stopped, targetMissing, conditionFalse }`

Find the controller from any widget below the host:
`SmartOnboarding.of(context)` / `SmartOnboarding.maybeOf(context)`.

### OnboardingStep

```dart
OnboardingStep({                       // NOT const
  required String id,
  List<OnboardingHighlight> highlights = const [],
  OnboardingContent? content,
  StepAdvance advance = const StepAdvance(),
  FutureOr<bool> Function()? condition,          // false => step skipped
  Future<void> Function()? onBeforeShow,         // navigate / scroll / load first
  MissingTargetBehavior missingTarget = MissingTargetBehavior.skip,
  Duration targetTimeout = const Duration(seconds: 10),
  bool? blockOutside,      // default true (theme): taps outside highlights are swallowed
  bool? showSkip,          // default true (theme)
  Color? overlayColor,
  double? blurSigma,
})

const OnboardingStep.sequence({        // const allowed
  required String id,
  required List<HighlightGroup> groups,
  ...same named parameters as above
})

const HighlightGroup({
  List<OnboardingHighlight> highlights = const [],
  OnboardingContent? content,   // overrides step.content for this group
  StepAdvance? advance,         // overrides step.advance for this group
})
```

`enum MissingTargetBehavior { skip, showAvailable }`

### OnboardingHighlight

```dart
OnboardingHighlight.id(String id, {         // NOT const
  int occurrence = 0,          // which one if several visible widgets share the id
  EdgeInsets? padding,         // default EdgeInsets.all(8) (theme)
  HighlightShape? shape,       // default HighlightShape.rect(radius: 12) (theme)
  OnboardingArrow? arrow,      // overrides content/theme arrow for this target
  bool? interactive,           // default true: tap reaches the real widget
  bool autoScroll = true,      // scroll the nearest Scrollable to show it
})
OnboardingHighlight.key(GlobalKey key, {...same})
const OnboardingHighlight(OnboardingTargetRef target, {...same})   // const allowed
```

Shapes: `HighlightShape.rect({double radius = 12})`, `HighlightShape.circle()`,
`HighlightShape.stadium()`, `HighlightShape.custom(Path Function(Rect) builder)`.

### StepAdvance

```dart
const StepAdvance({Duration? duration, TapToAdvance tap = TapToAdvance.target,
                   ProgressPlacement progress = ProgressPlacement.content})
const StepAdvance.timer(Duration duration, {TapToAdvance tap = TapToAdvance.anywhere,
                   ProgressPlacement progress = ProgressPlacement.content})
const StepAdvance.tap([TapToAdvance tap = TapToAdvance.anywhere])
const StepAdvance.manual()     // only controller.next() / buttons in content
```

`enum TapToAdvance { none, target, outside, anywhere }`
`enum ProgressPlacement { none, content, top, bottom }` — `content` is drawn
by `OnboardingTooltip` / `OnboardingTimerBar`; `top`/`bottom` by the overlay.

Buttons inside content and `controller.next()` always work, whatever `tap` is.

### OnboardingContent

```dart
const OnboardingContent({
  required Widget Function(BuildContext context, OnboardingStepInfo info) builder,
  ContentPlacement placement = const ContentPlacement.auto(),
  double maxWidth = 320,
  double? gap,              // null => 56 when an arrow is drawn, else 16
  OnboardingArrow? arrow,   // default arrow for highlights of this content
  int? anchor,              // index of the highlight to position around; null = all
})

factory OnboardingContent.tooltip({   // ready-made card
  String? title, required String text,
  String? nextLabel, String? doneLabel,     // default 'Next' / 'Done'
  bool showNext = true, bool showCounter = true,
  ContentPlacement placement, double maxWidth, double? gap,
  OnboardingArrow? arrow, int? anchor,
})
```

Placement:
- `ContentPlacement.auto({List<ContentSide> preferred = const []})` — finds a free side.
- `ContentPlacement.side(ContentSide side)` — always that side of the target.
- `ContentPlacement.aligned(AlignmentGeometry alignment)` — pinned on screen.
- `ContentPlacement.custom(Offset Function(Rect bounds, Size content, Rect? anchor))`.

`enum ContentSide { top, bottom, start, end }` (start/end follow RTL).

`OnboardingStepInfo` (builder argument, or `OnboardingStepInfo.of(context)`):
`controller, step, stepIndex, stepCount, groupIndex, groupCount,
Animation<double>? timer, progressPlacement, isLast, isLastStep, next(), skip()`.

`OnboardingTimerBar({Animation<double>? animation, Color color, Color? backgroundColor, double height = 4, double radius = 2})`
— inside content it reads the step timer automatically.

### OnboardingArrow

```dart
const OnboardingArrow.curved({Color? color, double strokeWidth = 2.5,
  double curvature = 0.3, double headSize = 11, double tipGap = 6, bool dashed = false})
const OnboardingArrow.widget({required Widget child, Size size = const Size(40, 40),
  bool rotate = true, double tipGap = 4})   // child's "up" is turned to the target
const OnboardingArrow.custom(Widget Function(BuildContext, ArrowGeometry, Animation<double> progress) builder)
OnboardingArrow.none
```

Arrow resolution per highlight: `highlight.arrow ?? content.arrow ??
(content == null ? OnboardingArrow.none : theme.arrow)`. So a step without
content draws an arrow ONLY if the highlight sets `arrow:` explicitly.

### OnboardingTheme

```dart
const OnboardingTheme({
  Color overlayColor = const Color(0xB3000000),
  double blurSigma = 2.5,                       // 0 disables blur
  EdgeInsets padding = const EdgeInsets.all(8),
  HighlightShape shape = const HighlightShape.rect(),
  OnboardingArrow arrow = const OnboardingArrow.curved(),
  OnboardingAnimation animation = const OnboardingAnimation(),
  bool blockOutside = true,
  bool interactive = true,
  bool showSkip = true,
  String skipLabel = 'Skip',
  Widget Function(BuildContext, VoidCallback skip)? skipBuilder,
  AlignmentGeometry skipAlignment = AlignmentDirectional.topEnd,
  EdgeInsets margin = const EdgeInsets.all(16),
  Color progressColor = const Color(0xFFFFFFFF),
  double arrowOnlyLength = 72,
})

const OnboardingAnimation({bool enabled = true, Duration duration = 400ms,
  Curve curve = Curves.easeInOutCubic, bool pulse = true, Duration pulseDuration = 1400ms,
  Duration arrowDuration = 550ms, Duration arrowStagger = 250ms})
OnboardingAnimation.none
```

Pass it as `SmartOnboarding.builder(controller: c, theme: const OnboardingTheme(...))`.

### Standalone tooltip (no dimming, no controller)

```dart
SmartTooltipHandle showSmartTooltip(BuildContext context, {
  required OnboardingTargetRef target,      // OnboardingTargetRef.id('x') or .key(k)
  required WidgetBuilder builder,
  ContentPlacement placement = const ContentPlacement.auto(),
  OnboardingArrow arrow = OnboardingArrow.none,
  double maxWidth = 280, double gap = 12, EdgeInsets margin = const EdgeInsets.all(12),
  OnboardingAnimation animation = const OnboardingAnimation(),
  Duration? duration,            // auto-dismiss
  bool dismissOnTap = true,
  VoidCallback? onDismissed,
})
// handle.dismiss(); handle.isShowing; await handle.closed;
```

## 4. Recipes

### Basic flow with persistence

```dart
abstract final class OnboardingIds {
  static const search = 'onboarding.search';
  static const profile = 'onboarding.profile';
  static const createButton = 'onboarding.create';
}

List<OnboardingStep> buildOnboardingSteps() => [
  OnboardingStep(
    id: 'welcome',
    content: OnboardingContent.tooltip(title: 'Welcome', text: 'A quick tour.'),
    advance: const StepAdvance.timer(Duration(seconds: 4)),
  ),
  OnboardingStep(
    id: 'search',
    highlights: [
      OnboardingHighlight.id(OnboardingIds.search, shape: const HighlightShape.circle()),
    ],
    content: OnboardingContent.tooltip(title: 'Search', text: 'Tap the magnifier.', showNext: false),
    advance: const StepAdvance(tap: TapToAdvance.target),
  ),
];

final onboarding = OnboardingController(
  onFinish: (_) => prefs.setBool('onboarding_done', true),
);

// After the home screen is visible:
if (!(prefs.getBool('onboarding_done') ?? false)) {
  onboarding.start(buildOnboardingSteps());
}
```

### Several targets at once / one after another

```dart
OnboardingStep(
  id: 'pair',
  highlights: [OnboardingHighlight.id('card'), OnboardingHighlight.id('fab')],
  content: OnboardingContent.tooltip(text: 'These two work together.'),
);

const OnboardingStep.sequence(
  id: 'tabs',
  advance: StepAdvance.tap(),
  groups: [
    HighlightGroup(highlights: [OnboardingHighlight(OnboardingTargetRef.id('tab_home'))]),
    HighlightGroup(highlights: [OnboardingHighlight(OnboardingTargetRef.id('tab_feed'))]),
  ],
);
```

### Target on another screen

The flow waits for the target (up to `targetTimeout`). Either let the user
navigate (tap on an interactive highlight that pushes a route — the next
step then waits for the new screen) or navigate yourself:

```dart
OnboardingStep(
  id: 'details',
  onBeforeShow: () async => navigatorKey.currentState!.pushNamed('/details'),
  highlights: [OnboardingHighlight.id('details.save')],
  content: OnboardingContent.tooltip(text: 'Save here.'),
);
```

### Target in a lazy list (`ListView.builder`, `GridView.builder`, slivers)

Off-screen items are not built, so they cannot be found. Scroll first:

```dart
OnboardingStep(
  id: 'item',
  onBeforeShow: () => scrollController.animateTo(
    targetOffset, duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
  highlights: [OnboardingHighlight.id('list.item.42')],
);
```

Non-lazy scroll views (`SingleChildScrollView`, `ListView(children:)` within
cache extent) are scrolled automatically (`autoScroll: true`).

### Advance from app code

```dart
onPressed: () {
  doSomething();
  SmartOnboarding.of(context).next();   // safe even if the tap also advanced the step
}
```

### Custom content and pinned position

```dart
OnboardingContent(
  placement: const ContentPlacement.aligned(Alignment.bottomCenter),
  builder: (context, info) => MyBrandCard(
    text: 'Custom card',
    onNext: info.next,
    onSkip: info.skip,
    footer: const OnboardingTimerBar(),
  ),
);
```

### Arrow without text, custom arrow image

```dart
OnboardingStep(
  id: 'profile',
  highlights: [
    OnboardingHighlight.id('profile', arrow: const OnboardingArrow.curved(dashed: true)),
  ],
  advance: const StepAdvance.timer(Duration(seconds: 3), progress: ProgressPlacement.bottom),
);

OnboardingHighlight.id('settings',
  arrow: OnboardingArrow.widget(child: Image.asset('assets/hand.png')));
```

### JSON from backend

```dart
final steps = OnboardingJsonParser(
  conditions: {'isNewUser': () => user.isNew},
  beforeShow: {'openProfile': () async => router.go('/profile')},
  contentFactories: {
    'promo': (json) => (context, info) => PromoCard(image: json['image'] as String),
  },
).parseString(jsonString);
```

```json
[
  {"id": "fab", "highlights": [{"target": "fab", "shape": "circle", "padding": 6}],
   "content": {"type": "tooltip", "title": "Create", "text": "...", "placement": "top"},
   "advance": {"timerMs": 4000, "tap": "anywhere", "progress": "content"}},
  {"id": "tabs", "sequence": [
     {"highlights": ["tab_home"], "content": {"text": "Home"}},
     {"highlights": ["tab_feed", "tab_settings"]}],
   "advance": {"tap": "anywhere"}, "condition": "isNewUser", "blur": 0}
]
```

JSON keys: step `id, highlights | sequence, content, advance, condition,
beforeShow, missingTarget ("skip"|"show"), targetTimeoutMs, blockOutside,
showSkip, overlayColor ("#AARRGGBB"), blur`. Highlight: string id or
`{target, occurrence, padding (num | [h,v] | [l,t,r,b]), shape ("rect"|"circle"|"stadium"|{"type":"rect","radius":n}), arrow (bool | {color, strokeWidth, curvature, headSize, dashed}), interactive, autoScroll}`.
Content: `{type ("tooltip" or a contentFactories key), title, text, nextLabel,
doneLabel, showNext, showCounter, placement ("auto"|"top"|"bottom"|"start"|"end"|"center"|"screenTop"|"screenBottom"|{"auto":[sides]}|{"alignment":[x,y]}), maxWidth, gap, arrow, anchor}`.
Advance: `{timerMs, tap (none|target|outside|anywhere), progress (none|content|top|bottom)}`.

### Localization

Pass translated strings: `OnboardingTheme(skipLabel: l10n.skip)` and
`OnboardingContent.tooltip(nextLabel: l10n.next, doneLabel: l10n.done, ...)`.
Build steps where a `BuildContext` with localizations is available.

## 5. Rules and pitfalls

- `OnboardingStep(...)` and `OnboardingHighlight.id(...)` are NOT const
  constructors. Do not write `const OnboardingStep(` or
  `const [OnboardingHighlight.id(...)]`. `OnboardingStep.sequence`,
  `HighlightGroup`, `StepAdvance.*`, `HighlightShape.*`, `OnboardingArrow.*`
  and `OnboardingHighlight(OnboardingTargetRef.id(...))` are const.
- Step ids must be unique within a flow (`goTo` uses them). Target ids may
  repeat; use `occurrence` to choose.
- Exactly one `SmartOnboarding`, above the navigator. Putting it inside a
  screen breaks waiting for navigation and dialogs.
- Do not wrap a target in a widget that hides it (`Offstage`, inactive
  `IndexedStack` tab, a route under a dialog): such targets are treated as
  not visible and the step waits.
- With the default `blockOutside: true` only highlighted widgets are
  tappable. If a step tells the user to tap something, make sure that
  widget is highlighted (and `interactive` is not false) or set
  `blockOutside: false`.
- `TapToAdvance.target` + interactive highlight: the real `onPressed` runs
  AND the step advances. Do not also call `next()` there unless you want to;
  calling it is harmless (no double advance).
- Timed steps keep running even if the user does nothing; for important
  steps prefer `StepAdvance.tap()` or `StepAdvance.manual()`.
- Do not store onboarding state inside the package; use `onFinish` /
  `onStepCompleted`.
- The package targets Android and iOS. Web/desktop are untested.
- `OnboardingTooltip` must only be used inside onboarding content (it reads
  `OnboardingStepInfo.of(context)`).

## 6. Conventions to apply in the host app

- One constants class for target ids, e.g. `OnboardingIds`, values prefixed
  with the feature (`'profile.avatar'`).
- Steps in `lib/onboarding/` (or the app's feature folder), not inline in
  widgets.
- Controller owned by the app root / DI container, disposed with it.
- Wrap targets as close to the visible widget as possible (wrap the
  `IconButton`, not the whole `AppBar`), so the cut-out is tight.

## 7. Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| Step never appears, skipped after 10 s | Target id typo, target not built (lazy list), on another route, under a dialog, in `Offstage`/inactive tab. Check `OnboardingTargetRegistry.instance.ids` in debug. |
| Nothing happens on `start()` | No `SmartOnboarding` above the navigator, or a different controller instance is passed. |
| Tap on highlighted button does nothing | `interactive: false`, or `TapToAdvance.none` and no button in content. |
| User cannot tap anything | Expected with `blockOutside: true`; highlight the widget or set `blockOutside: false`. |
| Arrow missing | Step without content needs `highlight.arrow`; arrow is also skipped when content touches the target (set a larger `gap`). |
| Content covers something | Use `ContentPlacement.auto(preferred: [...])`, `.side(...)` or `anchor:`. |

## 8. Testing in the host app

```dart
testWidgets('onboarding shows search step', (tester) async {
  final controller = OnboardingController();
  await tester.pumpWidget(MaterialApp(
    builder: SmartOnboarding.builder(
      controller: controller,
      theme: const OnboardingTheme(animation: OnboardingAnimation.none), // pumpAndSettle-friendly
    ),
    home: const HomePage(),
  ));
  controller.start(buildOnboardingSteps());
  await tester.pumpAndSettle();
  expect(controller.currentStep?.id, 'welcome');
});
```

With animations enabled the pulse repeats forever, so `pumpAndSettle` times
out: use `OnboardingAnimation.none` or `tester.pump(duration)` in tests.
Timed steps also keep `pumpAndSettle` busy until the timer ends.
