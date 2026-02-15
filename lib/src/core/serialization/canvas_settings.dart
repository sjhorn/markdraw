/// Canvas-level settings from the .markdraw frontmatter.
class CanvasSettings {
  final int formatVersion;
  final String background;
  final int? grid;

  const CanvasSettings({
    this.formatVersion = 1,
    this.background = '#ffffff',
    this.grid,
  });

  bool get isDefault =>
      formatVersion == 1 && background == '#ffffff' && grid == null;

  CanvasSettings copyWith({
    int? formatVersion,
    String? background,
    int? grid,
    bool clearGrid = false,
  }) {
    return CanvasSettings(
      formatVersion: formatVersion ?? this.formatVersion,
      background: background ?? this.background,
      grid: clearGrid ? null : (grid ?? this.grid),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanvasSettings &&
          formatVersion == other.formatVersion &&
          background == other.background &&
          grid == other.grid;

  @override
  int get hashCode => Object.hash(formatVersion, background, grid);

  @override
  String toString() =>
      'CanvasSettings(v$formatVersion, bg=$background, grid=$grid)';
}
