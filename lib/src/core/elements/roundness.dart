/// The type of corner rounding applied to a shape.
enum RoundnessType {
  adaptive,
  proportional,
}

/// Roundness configuration for shape corners.
class Roundness {
  final RoundnessType type;
  final double value;

  const Roundness._({required this.type, required this.value});

  const Roundness.adaptive({required double value})
      : this._(type: RoundnessType.adaptive, value: value);

  const Roundness.proportional({required double value})
      : this._(type: RoundnessType.proportional, value: value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Roundness && type == other.type && value == other.value;

  @override
  int get hashCode => Object.hash(type, value);

  @override
  String toString() => 'Roundness(${type.name}, $value)';
}
