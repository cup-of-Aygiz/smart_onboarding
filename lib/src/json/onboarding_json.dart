import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../core/target_ref.dart';
import '../model/highlight_shape.dart';
import '../model/onboarding_arrow.dart';
import '../model/onboarding_content.dart';
import '../model/onboarding_highlight.dart';
import '../model/onboarding_step.dart';

/// Builds content for a custom `content.type` from its JSON object.
typedef JsonContentFactory =
    OnboardingContentBuilder Function(Map<String, dynamic> json);

/// Parses onboarding steps from JSON (e.g. delivered by a backend).
///
/// ```json
/// [
///   {
///     "id": "profile",
///     "highlights": [{"target": "profile_button", "shape": "circle"}],
///     "content": {"type": "tooltip", "title": "Profile", "text": "..."},
///     "advance": {"timerMs": 4000, "tap": "anywhere", "progress": "content"}
///   },
///   {
///     "id": "tabs",
///     "sequence": [
///       {"highlights": ["tab_home"], "content": {"text": "Home"}},
///       {"highlights": ["tab_search", "tab_feed"]}
///     ]
///   }
/// ]
/// ```
///
/// Behaviour that cannot be expressed as data (conditions, `onBeforeShow`,
/// custom content) is referenced by name and looked up in the registries
/// passed to the constructor.
class OnboardingJsonParser {
  const OnboardingJsonParser({
    this.contentFactories = const {},
    this.conditions = const {},
    this.beforeShow = const {},
  });

  /// `content.type` → builder. `tooltip` is built in.
  final Map<String, JsonContentFactory> contentFactories;

  /// `condition` name → condition.
  final Map<String, StepCondition> conditions;

  /// `beforeShow` name → callback.
  final Map<String, Future<void> Function()> beforeShow;

  List<OnboardingStep> parseString(String source) =>
      parseSteps(jsonDecode(source) as List<dynamic>);

  List<OnboardingStep> parseSteps(List<dynamic> json) => [
    for (final step in json) parseStep((step as Map).cast<String, dynamic>()),
  ];

  OnboardingStep parseStep(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final content = _content(json['content']);
    final advance = _advance(json['advance']) ?? const StepAdvance();
    final conditionName = json['condition'] as String?;
    final beforeShowName = json['beforeShow'] as String?;
    final condition = conditionName == null
        ? null
        : conditions[conditionName] ??
              (throw FormatException('Unknown condition "$conditionName"'));
    final onBeforeShow = beforeShowName == null
        ? null
        : beforeShow[beforeShowName] ??
              (throw FormatException('Unknown beforeShow "$beforeShowName"'));
    final missing = switch (json['missingTarget']) {
      'show' || 'showAvailable' => MissingTargetBehavior.showAvailable,
      _ => MissingTargetBehavior.skip,
    };
    final timeout = json['targetTimeoutMs'] is num
        ? Duration(milliseconds: (json['targetTimeoutMs'] as num).toInt())
        : const Duration(seconds: 10);
    final overlayColor = _color(json['overlayColor']);
    final blur = (json['blur'] as num?)?.toDouble();
    final blockOutside = json['blockOutside'] as bool?;
    final showSkip = json['showSkip'] as bool?;

    final sequence = json['sequence'] as List<dynamic>?;
    if (sequence != null) {
      return OnboardingStep.sequence(
        id: id,
        groups: [
          for (final g in sequence)
            HighlightGroup(
              highlights: _highlights((g as Map)['highlights']),
              content: _content(g['content']),
              advance: _advance(g['advance']),
            ),
        ],
        content: content,
        advance: advance,
        condition: condition,
        onBeforeShow: onBeforeShow,
        missingTarget: missing,
        targetTimeout: timeout,
        blockOutside: blockOutside,
        showSkip: showSkip,
        overlayColor: overlayColor,
        blurSigma: blur,
      );
    }
    return OnboardingStep(
      id: id,
      highlights: _highlights(json['highlights']),
      content: content,
      advance: advance,
      condition: condition,
      onBeforeShow: onBeforeShow,
      missingTarget: missing,
      targetTimeout: timeout,
      blockOutside: blockOutside,
      showSkip: showSkip,
      overlayColor: overlayColor,
      blurSigma: blur,
    );
  }

  List<OnboardingHighlight> _highlights(Object? json) {
    if (json == null) return const [];
    return [
      for (final h in json as List<dynamic>)
        if (h is String)
          OnboardingHighlight.id(h)
        else
          _highlight((h as Map).cast<String, dynamic>()),
    ];
  }

  OnboardingHighlight _highlight(Map<String, dynamic> json) {
    final target = json['target'];
    final ref = switch (target) {
      String id => OnboardingTargetRef.id(
        id,
        occurrence: (json['occurrence'] as num?)?.toInt() ?? 0,
      ),
      _ => throw FormatException('Highlight needs a string "target": $json'),
    };
    return OnboardingHighlight(
      ref,
      padding: _insets(json['padding']),
      shape: _shape(json['shape']),
      arrow: _arrow(json['arrow']),
      interactive: json['interactive'] as bool?,
      autoScroll: json['autoScroll'] as bool? ?? true,
    );
  }

  OnboardingContent? _content(Object? json) {
    if (json == null) return null;
    final map = (json as Map).cast<String, dynamic>();
    final type = map['type'] as String? ?? 'tooltip';
    final placement = _placement(map['placement']);
    final maxWidth = (map['maxWidth'] as num?)?.toDouble() ?? 320;
    final gap = (map['gap'] as num?)?.toDouble();
    final arrow = _arrow(map['arrow']);
    final anchor = (map['anchor'] as num?)?.toInt();
    if (type == 'tooltip') {
      return OnboardingContent.tooltip(
        title: map['title'] as String?,
        text: map['text'] as String? ?? '',
        nextLabel: map['nextLabel'] as String?,
        doneLabel: map['doneLabel'] as String?,
        showNext: map['showNext'] as bool? ?? true,
        showCounter: map['showCounter'] as bool? ?? true,
        placement: placement,
        maxWidth: maxWidth,
        gap: gap,
        arrow: arrow,
        anchor: anchor,
      );
    }
    final factory =
        contentFactories[type] ??
        (throw FormatException('Unknown content type "$type"'));
    return OnboardingContent(
      builder: factory(map),
      placement: placement,
      maxWidth: maxWidth,
      gap: gap,
      arrow: arrow,
      anchor: anchor,
    );
  }

  ContentPlacement _placement(Object? json) {
    ContentSide side(Object? s) => ContentSide.values.byName(s as String);
    return switch (json) {
      null || 'auto' => const ContentPlacement.auto(),
      'center' => const ContentPlacement.aligned(Alignment.center),
      'screenTop' => const ContentPlacement.aligned(Alignment.topCenter),
      'screenBottom' => const ContentPlacement.aligned(Alignment.bottomCenter),
      String s => ContentPlacement.side(side(s)),
      {'auto': List<dynamic> preferred} => ContentPlacement.auto(
        preferred: [for (final p in preferred) side(p)],
      ),
      {'alignment': [num x, num y]} => ContentPlacement.aligned(
        Alignment(x.toDouble(), y.toDouble()),
      ),
      _ => throw FormatException('Bad placement: $json'),
    };
  }

  StepAdvance? _advance(Object? json) {
    if (json == null) return null;
    final map = (json as Map).cast<String, dynamic>();
    final ms = (map['timerMs'] as num?)?.toInt();
    return StepAdvance(
      duration: ms == null ? null : Duration(milliseconds: ms),
      tap: TapToAdvance.values.byName(map['tap'] as String? ?? 'target'),
      progress: ProgressPlacement.values.byName(
        map['progress'] as String? ?? 'content',
      ),
    );
  }

  HighlightShape? _shape(Object? json) => switch (json) {
    null => null,
    'rect' => const HighlightShape.rect(),
    'circle' => const HighlightShape.circle(),
    'stadium' => const HighlightShape.stadium(),
    {'type': 'rect', 'radius': num r} => HighlightShape.rect(
      radius: r.toDouble(),
    ),
    _ => throw FormatException('Bad shape: $json'),
  };

  OnboardingArrow? _arrow(Object? json) => switch (json) {
    null => null,
    false => OnboardingArrow.none,
    true => const OnboardingArrow.curved(),
    Map m => OnboardingArrow.curved(
      color: _color(m['color']),
      strokeWidth: (m['strokeWidth'] as num?)?.toDouble() ?? 2.5,
      curvature: (m['curvature'] as num?)?.toDouble() ?? 0.3,
      headSize: (m['headSize'] as num?)?.toDouble() ?? 11,
      dashed: m['dashed'] as bool? ?? false,
    ),
    _ => throw FormatException('Bad arrow: $json'),
  };

  EdgeInsets? _insets(Object? json) => switch (json) {
    null => null,
    num v => EdgeInsets.all(v.toDouble()),
    [num h, num v] => EdgeInsets.symmetric(
      horizontal: h.toDouble(),
      vertical: v.toDouble(),
    ),
    [num l, num t, num r, num b] => EdgeInsets.fromLTRB(
      l.toDouble(),
      t.toDouble(),
      r.toDouble(),
      b.toDouble(),
    ),
    _ => throw FormatException('Bad padding: $json'),
  };

  /// `#RRGGBB` or `#AARRGGBB`.
  Color? _color(Object? json) {
    if (json == null) return null;
    var hex = (json as String).replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}
