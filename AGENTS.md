# AGENTS.md

Instructions for AI coding agents (Codex, Claude Code, Cursor, ...).

## Using this package in an app

Read [AI_GUIDE.md](AI_GUIDE.md) before writing integration code. It has the
integration checklist, exact API signatures, recipes and pitfalls.

## Working on this package

- Flutter package, no third-party dependencies. Keep it that way.
- Public API is exported only from `lib/smart_onboarding.dart`; everything
  else lives in `lib/src/`. `OnboardingControllerInternals` must stay hidden.
- Layout: `core/` target lookup, `model/` immutable config, `controller/`
  state machine, `layout/` pure geometry (content placement, arrows),
  `render/` painting and hit testing, `widgets/` the overlay and tooltips,
  `json/` the JSON parser.
- Before finishing a change run, from the repo root:
  ```sh
  dart format lib test example/lib example/test
  flutter analyze
  flutter test
  (cd example && flutter test)
  ```
- When the public API changes, update `README.md`, `README.ru.md`,
  `AI_GUIDE.md` and `CHANGELOG.md` together.
