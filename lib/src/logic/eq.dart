class EqSettings {
  const EqSettings({
    this.enabled = false,
    this.preset = 'Flat',
    this.gains = const [0, 0, 0, 0, 0],
  });

  final bool enabled;
  final String preset;
  final List<double> gains;

  static const bandLabels = ['60', '230', '910', '3.6k', '14k'];

  static const presets = <String, List<double>>{
    'Flat': [0, 0, 0, 0, 0],
    'Forest Night': [2, 1, -1, 1, 2],
    'Vocal': [-2, -1, 3, 3, 1],
    'Bass': [6, 4, 1, 0, 0],
    'Treble': [0, 0, 1, 4, 5],
    'Late Night': [3, 1, -2, -2, -3],
  };

  EqSettings copyWith({bool? enabled, String? preset, List<double>? gains}) {
    return EqSettings(
      enabled: enabled ?? this.enabled,
      preset: preset ?? this.preset,
      gains: gains ?? this.gains,
    );
  }
}

double mapEqGain(int index, int bandCount, List<double> gains) {
  if (gains.isEmpty || bandCount <= 0) return 0;
  if (bandCount == gains.length) {
    return gains[index.clamp(0, gains.length - 1)];
  }
  if (bandCount == 1) return gains[gains.length ~/ 2];
  final position = index / (bandCount - 1) * (gains.length - 1);
  final lower = position.floor().clamp(0, gains.length - 1);
  final upper = (lower + 1).clamp(0, gains.length - 1);
  final fraction = position - lower;
  return gains[lower] + (gains[upper] - gains[lower]) * fraction;
}
