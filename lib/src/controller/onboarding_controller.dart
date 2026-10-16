import 'dart:async';

import 'package:flutter/foundation.dart';

import '../model/onboarding_step.dart';

enum OnboardingResult { completed, skipped, stopped }

/// Why a step (or group) ended.
enum StepCompletionReason {
  timer,
  tapTarget,
  tapOutside,

  /// `controller.next()`, `nextStep()` or a content button.
  manual,

  /// `goTo()` jumped away from the step.
  jump,
  skipped,
  stopped,
  targetMissing,
  conditionFalse,
}

typedef StepCallback = void Function(OnboardingStep step, int index);
typedef StepCompletedCallback =
    void Function(OnboardingStep step, int index, StepCompletionReason reason);
typedef GroupCallback =
    void Function(OnboardingStep step, int stepIndex, int groupIndex);

/// Drives an onboarding flow shown by `SmartOnboarding`.
///
/// The controller is plain state; persistence ("already shown") belongs to
/// the app — use [onFinish] to store it.
class OnboardingController extends ChangeNotifier {
  OnboardingController({
    this.onStart,
    this.onStepShown,
    this.onGroupShown,
    this.onStepCompleted,
    this.onTargetMissing,
    this.onSkip,
    this.onFinish,
  });

  final VoidCallback? onStart;

  /// The step's targets were found and the step is visible.
  final StepCallback? onStepShown;
  final GroupCallback? onGroupShown;
  final StepCompletedCallback? onStepCompleted;
  final StepCallback? onTargetMissing;
  final StepCallback? onSkip;
  final ValueChanged<OnboardingResult>? onFinish;

  List<OnboardingStep> _steps = const [];
  int _stepIndex = -1;
  int _groupIndex = 0;
  bool _active = false;
  bool _preparing = false;
  int _token = 0;
  bool _stepAnnounced = false;
  Completer<OnboardingResult>? _completer;

  bool get isActive => _active;

  List<OnboardingStep> get steps => List.unmodifiable(_steps);

  /// Step currently on screen; null while not running or while
  /// `condition`/`onBeforeShow` of the next step are being awaited.
  OnboardingStep? get currentStep =>
      _active && !_preparing && _stepIndex >= 0 ? _steps[_stepIndex] : null;

  HighlightGroup? get currentGroup => currentStep?.groups[_groupIndex];

  int get stepIndex => _stepIndex;
  int get groupIndex => _groupIndex;

  /// Starts [steps]. Completes when the flow ends in any way.
  Future<OnboardingResult> start(
    List<OnboardingStep> steps, {
    int startAt = 0,
  }) {
    assert(steps.isNotEmpty, 'Onboarding needs at least one step.');
    if (_active) _finish(OnboardingResult.stopped);
    _steps = List.of(steps);
    _active = true;
    final completer = _completer = Completer<OnboardingResult>();
    onStart?.call();
    _enterStep(startAt);
    return completer.future;
  }

  /// Next group of the current step, or the next step.
  void next() => _advance(StepCompletionReason.manual);

  /// Next step, skipping remaining groups of the current one.
  void nextStep() {
    if (currentStep == null) return;
    _completeStep(StepCompletionReason.manual);
    _enterStep(_stepIndex + 1);
  }

  /// Jumps to the step with [id].
  void goTo(String id) {
    if (!_active) return;
    final index = _steps.indexWhere((s) => s.id == id);
    assert(index >= 0, 'No onboarding step with id "$id".');
    if (index < 0) return;
    if (currentStep != null) _completeStep(StepCompletionReason.jump);
    _enterStep(index);
  }

  /// Ends the whole flow at once ("Skip all").
  void skip() {
    if (!_active) return;
    final step = currentStep;
    if (step != null) {
      onSkip?.call(step, _stepIndex);
      _completeStep(StepCompletionReason.skipped);
    }
    _finish(OnboardingResult.skipped);
  }

  /// Hides onboarding without reporting a skip.
  void stop() {
    if (!_active) return;
    if (currentStep != null) _completeStep(StepCompletionReason.stopped);
    _finish(OnboardingResult.stopped);
  }

  void _advance(StepCompletionReason reason) {
    final step = currentStep;
    if (step == null) return;
    if (_groupIndex < step.groups.length - 1) {
      _groupIndex++;
      _token++;
      notifyListeners();
      return;
    }
    _completeStep(reason);
    _enterStep(_stepIndex + 1);
  }

  void _completeStep(StepCompletionReason reason) {
    onStepCompleted?.call(_steps[_stepIndex], _stepIndex, reason);
  }

  Future<void> _enterStep(int index) async {
    final token = ++_token;
    _preparing = true;
    notifyListeners();

    for (var i = index; i < _steps.length; i++) {
      final step = _steps[i];
      if (step.condition != null) {
        final ok = await step.condition!();
        if (token != _token) return;
        if (!ok) {
          onStepCompleted?.call(step, i, StepCompletionReason.conditionFalse);
          continue;
        }
      }
      _stepIndex = i;
      if (step.onBeforeShow != null) {
        await step.onBeforeShow!();
        if (token != _token) return;
      }
      _groupIndex = 0;
      _stepAnnounced = false;
      _preparing = false;
      _token++;
      notifyListeners();
      return;
    }
    _finish(OnboardingResult.completed);
  }

  void _finish(OnboardingResult result) {
    _active = false;
    _preparing = false;
    _stepIndex = -1;
    _groupIndex = 0;
    _token++;
    notifyListeners();
    onFinish?.call(result);
    _completer?.complete(result);
    _completer = null;
  }

  @override
  void dispose() {
    if (_active) _finish(OnboardingResult.stopped);
    super.dispose();
  }
}

/// Hooks used by `SmartOnboarding`; not exported from the package.
extension OnboardingControllerInternals on OnboardingController {
  /// Changes whenever the visible step or group changes.
  int get position => _token;

  /// Advances only if nothing moved the flow since [token] was read, so a
  /// tap that also triggers `next()` in app code advances once.
  void advanceFrom(int token, StepCompletionReason reason) {
    if (token == _token) _advance(reason);
  }

  void reportShown(int token) {
    if (token != _token || currentStep == null) return;
    if (!_stepAnnounced) {
      _stepAnnounced = true;
      onStepShown?.call(_steps[_stepIndex], _stepIndex);
    }
    onGroupShown?.call(_steps[_stepIndex], _stepIndex, _groupIndex);
  }

  void reportMissing(int token) {
    if (token != _token || currentStep == null) return;
    onTargetMissing?.call(_steps[_stepIndex], _stepIndex);
    _completeStep(StepCompletionReason.targetMissing);
    _enterStep(_stepIndex + 1);
  }
}
