import 'dart:async';
import 'dart:developer';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import 'app.dart';
import 'src/constants.dart';
import 'src/models/settings.dart';
import 'src/platform_info.dart';
import 'src/player/android_audio_handler.dart';
import 'src/player/mpris_bridge.dart';
import 'src/player/playback.dart';
import 'src/player/xerno_engine.dart';
import 'src/services/settings_store.dart';
import 'src/services/supabase_gate.dart';
import 'src/state/providers.dart';

/// Held for the process lifetime so the MPRIS bus name stays registered.
MprisBridge? xernoMprisBridge;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (isLinuxDesktop) {
    JustAudioMediaKit.ensureInitialized(
      linux: true,
      windows: false,
      android: false,
      iOS: false,
      macOS: false,
    );
    JustAudioMediaKit.pitch = true;
    JustAudioMediaKit.title = kAppName;
  }

  final settings = await _loadSettings();
  if (settings.supabaseUrl.trim().isNotEmpty &&
      settings.supabaseAnonKey.trim().isNotEmpty) {
    await SupabaseGate.ensure(settings);
  }

  final player = await _startPlayer(settings);
  runApp(
    ProviderScope(
      overrides: [
        initialSettingsProvider.overrideWithValue(settings),
        playerProvider.overrideWithValue(player),
      ],
      child: const XernoApp(),
    ),
  );
}

Future<AppSettings> _loadSettings() async {
  try {
    return await SettingsStore.load();
  } catch (error, stack) {
    log('Settings could not be loaded.', error: error, stackTrace: stack);
    return AppSettings.defaults();
  }
}

Future<PlaybackPort> _startPlayer(AppSettings settings) async {
  final XernoEngine engine;
  try {
    engine = XernoEngine();
    await engine.prepare(
      volume: settings.volume,
      speed: settings.speed,
      pitch: settings.pitch,
      crossfade: Duration(
        milliseconds: (settings.crossfadeSeconds * 1000).round(),
      ),
      eq: settings.eq,
    );
  } catch (error, stack) {
    log('Playback engine did not start.', error: error, stackTrace: stack);
    return ManualPlayback(failure: 'Playback engine did not start.');
  }

  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    session.interruptionEventStream.listen((event) {
      if (event.begin && event.type != AudioInterruptionType.duck) {
        unawaited(engine.pause());
      }
    });
    session.becomingNoisyEventStream.listen((_) {
      unawaited(engine.pause());
    });
  } catch (error, stack) {
    log('Audio session is unavailable.', error: error, stackTrace: stack);
  }

  if (isAndroidDevice) {
    try {
      await AudioService.init(
        builder: () => AndroidAudioHandler(engine),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'online.mucsarocsoge.xerno_music.audio',
          androidNotificationChannelName: 'Xerno Music playback',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          notificationColor: Color(0xFF2D6A4F),
        ),
      );
    } catch (error, stack) {
      log(
        'Android media session did not start.',
        error: error,
        stackTrace: stack,
      );
    }
  }

  if (isLinuxDesktop) {
    final bridge = MprisBridge(engine);
    await bridge.start();
    xernoMprisBridge = bridge;
  }
  return engine;
}
