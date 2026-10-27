import 'dart:async';
import 'dart:developer';
import 'dart:io';

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
  final mediaKitReady = !isLinuxDesktop || _startLinuxMediaKit();

  final settings = await _loadSettings();
  if (settings.supabaseUrl.trim().isNotEmpty &&
      settings.supabaseAnonKey.trim().isNotEmpty) {
    await SupabaseGate.ensure(settings);
  }

  final player = await _startPlayer(settings, mediaKitReady: mediaKitReady);
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

/// Loads libmpv without letting a missing library kill the process.
///
/// `JustAudioMediaKit.ensureInitialized` throws before `runApp` when mpv is
/// not installed. Creating a player would throw again, so callers must skip
/// it when this returns false.
bool _startLinuxMediaKit() {
  Object? lastError;
  StackTrace? lastStack;
  for (final candidate in _libmpvCandidates()) {
    try {
      JustAudioMediaKit.ensureInitialized(
        linux: true,
        windows: false,
        android: false,
        iOS: false,
        macOS: false,
        libmpv: candidate,
      );
      JustAudioMediaKit.pitch = true;
      JustAudioMediaKit.title = kAppName;
      return true;
    } catch (error, stack) {
      lastError = error;
      lastStack = stack;
    }
  }
  log(kMissingLibmpvMessage, error: lastError, stackTrace: lastStack);
  stderr.writeln(kMissingLibmpvMessage);
  return false;
}

List<String?> _libmpvCandidates() {
  final paths = <String?>[];
  final env = Platform.environment['LIBMPV_LIBRARY_PATH'];
  if (env != null && env.isNotEmpty && File(env).existsSync()) {
    paths.add(env);
  }
  const known = [
    '/usr/lib/libmpv.so.2',
    '/usr/lib/libmpv.so',
    '/usr/lib64/libmpv.so.2',
    '/usr/lib64/libmpv.so',
    '/usr/lib/x86_64-linux-gnu/libmpv.so.2',
    '/usr/lib/x86_64-linux-gnu/libmpv.so',
    '/lib/x86_64-linux-gnu/libmpv.so.2',
    '/lib/x86_64-linux-gnu/libmpv.so',
  ];
  for (final path in known) {
    if (File(path).existsSync()) paths.add(path);
  }
  // media_kit then tries the sonames libmpv.so, libmpv.so.2, and libmpv.so.1.
  paths.add(null);
  return paths;
}

Future<PlaybackPort> _startPlayer(
  AppSettings settings, {
  required bool mediaKitReady,
}) async {
  if (isLinuxDesktop && !mediaKitReady) {
    return ManualPlayback(failure: kMissingLibmpvMessage);
  }

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
    final missingLibmpv = error.toString().contains('libmpv');
    if (missingLibmpv) {
      stderr.writeln(kMissingLibmpvMessage);
    }
    return ManualPlayback(
      failure: missingLibmpv
          ? kMissingLibmpvMessage
          : 'Playback engine did not start.',
    );
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
