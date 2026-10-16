import 'package:flutter/widgets.dart';

/// Marks [child] as something onboarding can highlight by [id].
///
/// The wrapper does not change layout or painting; it only registers its
/// [BuildContext] in [OnboardingTargetRegistry] while it is in the tree.
class OnboardingTarget extends StatefulWidget {
  const OnboardingTarget({super.key, required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  State<OnboardingTarget> createState() => _OnboardingTargetState();
}

class _OnboardingTargetState extends State<OnboardingTarget> {
  @override
  void initState() {
    super.initState();
    OnboardingTargetRegistry.instance._add(widget.id, context);
  }

  @override
  void didUpdateWidget(OnboardingTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      OnboardingTargetRegistry.instance._remove(oldWidget.id, context);
      OnboardingTargetRegistry.instance._add(widget.id, context);
    }
  }

  @override
  void activate() {
    super.activate();
    OnboardingTargetRegistry.instance._add(widget.id, context);
  }

  @override
  void deactivate() {
    OnboardingTargetRegistry.instance._remove(widget.id, context);
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Global lookup table of mounted [OnboardingTarget]s.
///
/// It is global on purpose: targets can live in any route, dialog or nested
/// navigator and still be found by id.
class OnboardingTargetRegistry {
  OnboardingTargetRegistry._();

  static final OnboardingTargetRegistry instance = OnboardingTargetRegistry._();

  final Map<String, List<BuildContext>> _entries = {};

  void _add(String id, BuildContext context) {
    final list = _entries.putIfAbsent(id, () => []);
    if (!list.contains(context)) list.add(context);
  }

  void _remove(String id, BuildContext context) {
    final list = _entries[id];
    if (list == null) return;
    list.remove(context);
    if (list.isEmpty) _entries.remove(id);
  }

  /// All mounted contexts registered under [id], in registration order.
  List<BuildContext> contextsFor(String id) =>
      List.unmodifiable(_entries[id] ?? const <BuildContext>[]);

  /// Ids that currently have at least one mounted target.
  Iterable<String> get ids => _entries.keys;
}
