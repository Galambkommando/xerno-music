import '../constants.dart';
import '../format.dart';
import '../logic/eq.dart';
import 'json_util.dart';

enum SourcePreference { auto, localFirst, cloudFirst }

SourcePreference sourcePreferenceFromName(String? raw) {
  return switch (raw) {
    'localFirst' => SourcePreference.localFirst,
    'cloudFirst' => SourcePreference.cloudFirst,
    _ => SourcePreference.auto,
  };
}

class AppSettings {
  AppSettings({
    this.manifestUrl = kDefaultManifestUrl,
    this.localLibraryPath = '',
    this.cloudBaseUrl = '',
    this.sourcePreference = SourcePreference.auto,
    this.frostedGlass = true,
    this.ambientGlow = true,
    this.volume = 0.9,
    this.crossfadeSeconds = 0,
    this.speed = 1,
    this.pitch = 1,
    this.eqEnabled = false,
    this.eqPreset = 'Flat',
    this.eqGains = const [0, 0, 0, 0, 0],
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
    this.syncRoomCode = '',
    this.restSyncBaseUrl = '',
    this.resumeOnLaunch = false,
    this.liveSync = false,
    required this.deviceId,
    this.miniPlayer = false,
  });

  final String manifestUrl;
  final String localLibraryPath;
  final String cloudBaseUrl;
  final SourcePreference sourcePreference;
  final bool frostedGlass;
  final bool ambientGlow;
  final double volume;
  final double crossfadeSeconds;
  final double speed;
  final double pitch;
  final bool eqEnabled;
  final String eqPreset;
  final List<double> eqGains;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String syncRoomCode;
  final String restSyncBaseUrl;
  final bool resumeOnLaunch;
  final bool liveSync;
  final String deviceId;
  final bool miniPlayer;

  factory AppSettings.defaults() => AppSettings(deviceId: newDeviceId());

  EqSettings get eq =>
      EqSettings(enabled: eqEnabled, preset: eqPreset, gains: eqGains);

  AppSettings copyWith({
    String? manifestUrl,
    String? localLibraryPath,
    String? cloudBaseUrl,
    SourcePreference? sourcePreference,
    bool? frostedGlass,
    bool? ambientGlow,
    double? volume,
    double? crossfadeSeconds,
    double? speed,
    double? pitch,
    bool? eqEnabled,
    String? eqPreset,
    List<double>? eqGains,
    String? supabaseUrl,
    String? supabaseAnonKey,
    String? syncRoomCode,
    String? restSyncBaseUrl,
    bool? resumeOnLaunch,
    bool? liveSync,
    String? deviceId,
    bool? miniPlayer,
  }) {
    return AppSettings(
      manifestUrl: manifestUrl ?? this.manifestUrl,
      localLibraryPath: localLibraryPath ?? this.localLibraryPath,
      cloudBaseUrl: cloudBaseUrl ?? this.cloudBaseUrl,
      sourcePreference: sourcePreference ?? this.sourcePreference,
      frostedGlass: frostedGlass ?? this.frostedGlass,
      ambientGlow: ambientGlow ?? this.ambientGlow,
      volume: volume ?? this.volume,
      crossfadeSeconds: crossfadeSeconds ?? this.crossfadeSeconds,
      speed: speed ?? this.speed,
      pitch: pitch ?? this.pitch,
      eqEnabled: eqEnabled ?? this.eqEnabled,
      eqPreset: eqPreset ?? this.eqPreset,
      eqGains: eqGains ?? this.eqGains,
      supabaseUrl: supabaseUrl ?? this.supabaseUrl,
      supabaseAnonKey: supabaseAnonKey ?? this.supabaseAnonKey,
      syncRoomCode: syncRoomCode ?? this.syncRoomCode,
      restSyncBaseUrl: restSyncBaseUrl ?? this.restSyncBaseUrl,
      resumeOnLaunch: resumeOnLaunch ?? this.resumeOnLaunch,
      liveSync: liveSync ?? this.liveSync,
      deviceId: deviceId ?? this.deviceId,
      miniPlayer: miniPlayer ?? this.miniPlayer,
    );
  }

  Map<String, Object?> toJson() => {
    'manifest_url': manifestUrl,
    'local_library_path': localLibraryPath,
    'cloud_base_url': cloudBaseUrl,
    'source_preference': sourcePreference.name,
    'frosted_glass': frostedGlass,
    'ambient_glow': ambientGlow,
    'volume': volume,
    'crossfade_seconds': crossfadeSeconds,
    'speed': speed,
    'pitch': pitch,
    'eq_enabled': eqEnabled,
    'eq_preset': eqPreset,
    'eq_gains': eqGains,
    'supabase_url': supabaseUrl,
    'supabase_anon_key': supabaseAnonKey,
    'sync_room_code': syncRoomCode,
    'rest_sync_base_url': restSyncBaseUrl,
    'resume_on_launch': resumeOnLaunch,
    'live_sync': liveSync,
    'device_id': deviceId,
    'mini_player': miniPlayer,
  };

  factory AppSettings.fromJson(Object? json) {
    final map = asMap(json);
    final gains = <double>[];
    final rawGains = map['eq_gains'];
    if (rawGains is List) {
      for (final item in rawGains) {
        if (item is num) gains.add(item.toDouble().clamp(-12, 12).toDouble());
      }
    }
    while (gains.length < 5) {
      gains.add(0);
    }
    return AppSettings(
      manifestUrl: asString(map['manifest_url'], kDefaultManifestUrl),
      localLibraryPath: asString(map['local_library_path']),
      cloudBaseUrl: asString(map['cloud_base_url']),
      sourcePreference: sourcePreferenceFromName(
        asStringOrNull(map['source_preference']),
      ),
      frostedGlass: asBool(map['frosted_glass'], true),
      ambientGlow: asBool(map['ambient_glow'], true),
      volume: asDouble(map['volume'], 0.9).clamp(0, 1).toDouble(),
      crossfadeSeconds: asDouble(map['crossfade_seconds'])
          .clamp(0, 12)
          .toDouble(),
      speed: asDouble(map['speed'], 1).clamp(0.5, 2).toDouble(),
      pitch: asDouble(map['pitch'], 1).clamp(0.5, 1.5).toDouble(),
      eqEnabled: asBool(map['eq_enabled']),
      eqPreset: asString(map['eq_preset'], 'Flat'),
      eqGains: gains.take(5).toList(),
      supabaseUrl: asString(map['supabase_url']),
      supabaseAnonKey: asString(map['supabase_anon_key']),
      syncRoomCode: asString(map['sync_room_code']),
      restSyncBaseUrl: asString(map['rest_sync_base_url']),
      resumeOnLaunch: asBool(map['resume_on_launch']),
      liveSync: asBool(map['live_sync']),
      deviceId: asString(map['device_id']),
      // Mini player is session-only. A saved true value would reopen the
      // compact window with no way back to the library.
      miniPlayer: false,
    );
  }
}
