/// How many floor tiles fit across the dungeon stage (phone “view scale”).
enum DungeonZoom {
  /// Larger sprites — less of the floor in view.
  close,

  /// Default ~20 tiles wide on phones.
  normal,

  /// Smaller sprites — more of the floor in view.
  wide;

  double get targetCols => switch (this) {
        DungeonZoom.close => 16,
        DungeonZoom.normal => 20,
        DungeonZoom.wide => 24,
      };

  String get settingsLabel => switch (this) {
        DungeonZoom.close => 'Zoom · Close',
        DungeonZoom.normal => 'Zoom · Normal',
        DungeonZoom.wide => 'Zoom · Wide',
      };

  String get settingsHint => switch (this) {
        DungeonZoom.close => 'Bigger sprites · less floor in view',
        DungeonZoom.normal => 'Default dungeon framing',
        DungeonZoom.wide => 'See more of the floor at once',
      };

  /// Compact in-dungeon chip label.
  String get hudChipLabel => switch (this) {
        DungeonZoom.close => 'NEAR',
        DungeonZoom.normal => 'MID',
        DungeonZoom.wide => 'FAR',
      };

  DungeonZoom get next => switch (this) {
        DungeonZoom.close => DungeonZoom.normal,
        DungeonZoom.normal => DungeonZoom.wide,
        DungeonZoom.wide => DungeonZoom.close,
      };

  static DungeonZoom fromJson(Object? raw) {
    if (raw is String) {
      return switch (raw) {
        'close' => DungeonZoom.close,
        'wide' => DungeonZoom.wide,
        'normal' => DungeonZoom.normal,
        _ => DungeonZoom.normal,
      };
    }
    return DungeonZoom.normal;
  }
}
