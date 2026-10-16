import 'package:flutter/widgets.dart';

/// Reference to a widget that onboarding can highlight.
///
/// Prefer [OnboardingTargetRef.id] together with `OnboardingTarget`: ids are
/// plain strings, so they can be declared anywhere (including JSON) and they
/// survive navigation. [OnboardingTargetRef.key] exists for widgets where
/// wrapping is inconvenient.
@immutable
sealed class OnboardingTargetRef {
  const OnboardingTargetRef();

  /// Target registered with `OnboardingTarget(id: id)`.
  ///
  /// When several visible widgets share the same [id], they are ordered in
  /// reading order (top to bottom, then start to end) and [occurrence] picks
  /// one of them.
  const factory OnboardingTargetRef.id(String id, {int occurrence}) =
      IdTargetRef;

  /// Target identified by a [GlobalKey] attached to the widget.
  const factory OnboardingTargetRef.key(GlobalKey key) = KeyTargetRef;
}

final class IdTargetRef extends OnboardingTargetRef {
  const IdTargetRef(this.id, {this.occurrence = 0}) : assert(occurrence >= 0);

  final String id;
  final int occurrence;

  @override
  bool operator ==(Object other) =>
      other is IdTargetRef && other.id == id && other.occurrence == occurrence;

  @override
  int get hashCode => Object.hash(id, occurrence);

  @override
  String toString() => 'OnboardingTargetRef.id($id#$occurrence)';
}

final class KeyTargetRef extends OnboardingTargetRef {
  const KeyTargetRef(this.key);

  final GlobalKey key;

  @override
  bool operator ==(Object other) => other is KeyTargetRef && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'OnboardingTargetRef.key($key)';
}
