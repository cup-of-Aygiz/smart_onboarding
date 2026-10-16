/// Spotlight onboarding: highlight widgets by id or GlobalKey, dim and blur
/// the rest, auto-position content and point at targets with arrows.
library;

export 'src/controller/onboarding_controller.dart'
    hide OnboardingControllerInternals;
export 'src/core/onboarding_target.dart';
export 'src/core/target_ref.dart';
export 'src/json/onboarding_json.dart';
export 'src/layout/arrow_geometry.dart' show ArrowGeometry;
export 'src/model/highlight_shape.dart';
export 'src/model/onboarding_arrow.dart';
export 'src/model/onboarding_content.dart';
export 'src/model/onboarding_highlight.dart';
export 'src/model/onboarding_step.dart';
export 'src/model/onboarding_theme.dart';
export 'src/model/step_info.dart' show OnboardingStepInfo;
export 'src/widgets/onboarding_timer_bar.dart';
export 'src/widgets/onboarding_tooltip.dart';
export 'src/widgets/smart_onboarding.dart';
export 'src/widgets/smart_tooltip.dart';
export 'src/widgets/smart_tooltip_layer.dart';
