import 'package:flutter/material.dart';

import '../model/onboarding_step.dart';
import '../model/step_info.dart';
import 'onboarding_timer_bar.dart';

/// Default content card: title, text, "2 / 5" counter, timer bar and a
/// next button. Reads the current step from [OnboardingStepInfo], so it only
/// works inside onboarding content.
class OnboardingTooltip extends StatelessWidget {
  const OnboardingTooltip({
    super.key,
    this.title,
    required this.text,
    this.nextLabel,
    this.doneLabel,
    this.showNext = true,
    this.showCounter = true,
    this.backgroundColor,
    this.foregroundColor,
    this.accentColor,
  });

  final String? title;
  final String text;
  final String? nextLabel;
  final String? doneLabel;
  final bool showNext;
  final bool showCounter;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final info = OnboardingStepInfo.of(context);
    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.colorScheme.surface;
    final fg = foregroundColor ?? theme.colorScheme.onSurface;
    final accent = accentColor ?? theme.colorScheme.primary;
    final showTimer =
        info.timer != null &&
        info.progressPlacement == ProgressPlacement.content;

    return Material(
      color: bg,
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: fg)),
            if (showTimer) ...[
              const SizedBox(height: 12),
              OnboardingTimerBar(color: accent),
            ],
            if (showCounter || showNext) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (showCounter)
                    Text(
                      '${info.stepIndex + 1} / ${info.stepCount}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: fg.withValues(alpha: 0.6),
                      ),
                    ),
                  const Spacer(),
                  if (showNext)
                    TextButton(
                      onPressed: info.next,
                      style: TextButton.styleFrom(foregroundColor: accent),
                      child: Text(
                        info.isLast
                            ? (doneLabel ?? 'Done')
                            : (nextLabel ?? 'Next'),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
