# smart_onboarding

**English** | [Русский](README.ru.md)

Spotlight onboarding for Flutter with zero third-party dependencies.

- Finds widgets by string id (`OnboardingTarget`) or by `GlobalKey`.
- Dims and blurs everything else, cutting out holes shaped as a rect, circle, stadium or any custom `Path`.
- Highlights several widgets at once, or one after another within a single step.
- Places content where it fits on its own. Content can be any widget, and its position can be pinned.
- Draws animated curved arrows. You can replace them with your own image or widget, or turn them off.
- Steps advance on a timer (with a progress bar), on tap (on the target, outside it or anywhere) or via `controller.next()`.
- Waits for navigation when a target is on another screen, and scrolls lists to the target.
- Keeps up with scrolling, rotation and the keyboard. Supports RTL.
- Steps can be written in code or loaded from JSON.

## Setup

```dart
final onboarding = OnboardingController(
  onFinish: (result) => prefs.setBool('onboarding_done', true), // persistence is up to the app
);

MaterialApp(
  builder: SmartOnboarding.builder(controller: onboarding),
  home: const HomePage(),
);
```

Mark widgets:

```dart
OnboardingTarget(
  id: 'search',
  child: IconButton(icon: const Icon(Icons.search), onPressed: () {}),
)
```

Start the onboarding:

```dart
onboarding.start([
  OnboardingStep(
    id: 'search',
    highlights: [OnboardingHighlight.id('search', shape: const HighlightShape.circle())],
    content: OnboardingContent.tooltip(title: 'Search', text: 'Find anything here'),
    advance: const StepAdvance(tap: TapToAdvance.target), // tapping the real button completes the step
  ),
]);
```

## Id or GlobalKey

Use `OnboardingTarget(id:)` wherever you can. An id is a plain string: you can reference it from anywhere in your code and from JSON, it works across screens, and several widgets can share one id (pick one with `occurrence`).
`OnboardingHighlight.key(globalKey)` is there for widgets that are awkward to wrap.

## Steps

| Need | How |
| --- | --- |
| Several targets at once | `OnboardingStep(highlights: [a, b])` |
| Targets one by one within a step | `OnboardingStep.sequence(groups: [HighlightGroup(...), ...])` |
| Step without a target (centered) | `OnboardingStep(content: ...)` without `highlights` |
| Arrow only, no text | `highlights: [OnboardingHighlight.id('x', arrow: OnboardingArrow.curved())]` without `content` |
| Timer | `StepAdvance.timer(Duration(seconds: 4), progress: ProgressPlacement.top)` |
| Tap only | `StepAdvance.tap(TapToAdvance.anywhere / target / outside)` |
| Code only | `StepAdvance.manual()` + `controller.next()` |
| Allow taps outside the highlight | `blockOutside: false` |
| Highlighted widget can't be tapped | `OnboardingHighlight(..., interactive: false)` |
| Show condition | `condition: () async => !user.hasAvatar` |
| Preparation (navigate, scroll, load) | `onBeforeShow: () async => ...` |
| Target not found | `missingTarget: MissingTargetBehavior.skip / showAvailable`, `targetTimeout` |

Controls: `next()` moves to the next group or step, `nextStep()` to the next step, `goTo(id)` to a step by id, `skip()` skips everything ("Skip"), `stop()` stops the onboarding.
For analytics there are the `onStepShown`, `onGroupShown`, `onStepCompleted(reason)`, `onTargetMissing`, `onSkip` and `onFinish` callbacks.

## Content

```dart
OnboardingContent(
  builder: (context, info) => MyCard(onNext: info.next, timer: info.timer),
  placement: const ContentPlacement.auto(preferred: [ContentSide.top]),
  // or .side(ContentSide.end), .aligned(Alignment.bottomCenter), .custom((bounds, size, anchor) => Offset(...))
  arrow: const OnboardingArrow.curved(dashed: true),
)
```

Inside content you can use `OnboardingStepInfo.of(context)` and `OnboardingTimerBar()`.

Arrows: `OnboardingArrow.curved(...)`, `OnboardingArrow.widget(child: Image.asset(...))` (the widget rotates to face the target), `OnboardingArrow.custom((ctx, geometry, progress) => ...)` and `OnboardingArrow.none`. With several targets, arrows appear one after another; the delay is set with `arrowStagger`.

## Theme and animations

```dart
SmartOnboarding.builder(
  controller: onboarding,
  theme: const OnboardingTheme(
    overlayColor: Color(0xB3000000),
    blurSigma: 3,
    padding: EdgeInsets.all(8),
    shape: HighlightShape.rect(radius: 12),
    animation: OnboardingAnimation(pulse: false), // or OnboardingAnimation.none
    skipLabel: 'Skip',
  ),
)
```

## Standalone tooltip

A tooltip without dimming that finds its own spot and follows the target:

```dart
final handle = showSmartTooltip(
  context,
  target: const OnboardingTargetRef.id('fab'),
  arrow: const OnboardingArrow.curved(color: Colors.indigo),
  duration: const Duration(seconds: 3),
  builder: (_) => const Text('New!'),
);
```

For custom scenarios there is the low-level `SmartTooltipLayer` widget: it places content and arrows around the rects you pass in.

## JSON

```dart
final steps = OnboardingJsonParser(
  conditions: {'isNewUser': () => user.isNew},
  contentFactories: {'promo': (json) => (context, info) => Promo(json['image'])},
).parseString(jsonFromBackend);
```

The format is described in the `OnboardingJsonParser` doc comment.

## Limitations

- Lazy lists (`ListView.builder`) don't build off-screen items, so such a target can't be found. Scroll to it in `onBeforeShow` (for example with `ScrollController.animateTo`); the onboarding then brings the target to the center on its own.
- Target positions are updated after each frame, so during fast scrolling the highlight may lag one frame behind.

## Using with AI assistants (Claude Code, Codex, Cursor)

The repository contains [AI_GUIDE.md](AI_GUIDE.md): an integration checklist, exact API signatures, recipes and pitfalls written for coding agents. To let an agent integrate the package into your app, add this to your app's `CLAUDE.md` or `AGENTS.md`:

```md
## Onboarding
We use the `smart_onboarding` package for spotlight onboarding.
Before writing onboarding code, read its AI_GUIDE.md
(in the package repository, or in the pub cache:
`~/.pub-cache/git/smart_onboarding-*/AI_GUIDE.md`; for a path dependency, at that path).
Target ids live in `lib/onboarding/onboarding_ids.dart`, steps in `lib/onboarding/onboarding_steps.dart`.
```

Or just tell the agent: *"Integrate smart_onboarding following its AI_GUIDE.md"*.

## License

[MIT](LICENSE) — free to use, modify and distribute, including in commercial projects. Just keep the license notice.
