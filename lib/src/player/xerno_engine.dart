import 'dart:async';
import 'dart:developer';

import 'package:just_audio/just_audio.dart';

import '../constants.dart';
import '../logic/eq.dart';
import '../logic/play_queue.dart';
import '../platform_info.dart';
import 'playback.dart';

class XernoEngine implements PlaybackPort {
  XernoEngine() {
    _eqA = isAndroidDevice ? AndroidEqualizer() : null;
    _eqB = isAndroidDevice ? AndroidEqualizer() : null;
    _primary = _newPlayer(_eqA);
    try {
      _secondary = _newPlayer(_eqB);
    } catch (error, stack) {
      log('Secondary player is unavailable.', error: error, stackTrace: stack);
      _secondary = null;
    }
    _listen(_primary);
    final secondary = _secondary;
    if (secondary != null) _listen(secondary);
    _snapshot = PlayerSnapshot.idle;
  }

  late final AudioPlayer _primary;
  AudioPlayer? _secondary;
  AndroidEqualizer? _eqA;
  AndroidEqualizer? _eqB;
  final PlayQueue _queue = PlayQueue();
  final Map<String, Playable> _catalog = {};
  final StreamController<PlayerSnapshot> _updates =
      StreamController<PlayerSnapshot>.broadcast();

  PlayerSnapshot _snapshot = PlayerSnapshot.idle;
  Future<void> _chain = Future<void>.value();
  double _userVolume = 0.9;
  double _speed = 1;
  double _pitch = 1;
  Duration _crossfade = Duration.zero;
  EqSettings _eq = const EqSettings();
  double _primaryFade = 1;
  double _secondaryFade = 0;
  bool _fading = false;
  int _fadeToken = 0;
  bool _secondaryReady = false;
  String? _secondaryLoadedId;
  String? _contextLabel;
  String? _error;
  Timer? _sleepTimer;
  DateTime? _sleepUntil;
  bool _sleepEndOfTrack = false;
  Timer? _emitTimer;
  bool _emitQueued = false;

  AudioPlayer _newPlayer(AndroidEqualizer? equalizer) {
    if (equalizer == null) return AudioPlayer();
    return AudioPlayer(
      audioPipeline: AudioPipeline(androidAudioEffects: [equalizer]),
    );
  }

  void _listen(AudioPlayer player) {
    player.playerStateStream.listen(
      (state) {
        if (!identical(player, _primary)) return;
        if (state.processingState == ProcessingState.completed && !_fading) {
          unawaited(_serialize(_handleNaturalEnd));
        } else {
          _emit();
        }
      },
      onError: (Object error, StackTrace stack) {
        log('Player state error.', error: error, stackTrace: stack);
      },
    );
    player.positionStream.listen(
      (_) {
        if (!identical(player, _primary) || _fading) return;
        _maybeStartFade();
        _emit();
      },
      onError: (Object error, StackTrace stack) {
        log('Position stream error.', error: error, stackTrace: stack);
      },
    );
  }

  Future<void> prepare({
    required double volume,
    required double speed,
    required double pitch,
    required Duration crossfade,
    required EqSettings eq,
  }) async {
    _userVolume = volume.clamp(0, 1).toDouble();
    _speed = speed.clamp(0.5, 2).toDouble();
    _pitch = pitch.clamp(0.5, 1.5).toDouble();
    _crossfade = crossfade;
    _eq = eq;
    await _applyVolumes();
    await _applyTransport();
    await _applyEqNow();
    _emit(force: true);
  }

  @override
  PlayerSnapshot get snapshot => _snapshot;

  @override
  Stream<PlayerSnapshot> get snapshots => _updates.stream;

  Future<void> _serialize(Future<void> Function() action) {
    final run = _chain.then((_) => action());
    _chain = run.then(
      (_) {},
      onError: (Object error, StackTrace stack) {
        log('Player command failed.', error: error, stackTrace: stack);
      },
    );
    return run;
  }

  @override
  Future<void> playAll(
    List<Playable> items, {
    int index = 0,
    String? contextLabel,
    bool autoplay = true,
    Duration position = Duration.zero,
  }) {
    return _serialize(() async {
      await _cancelFade();
      _error = null;
      _contextLabel = contextLabel;
      for (final item in items) {
        _catalog[item.id] = item;
      }
      _queue.replace([for (final item in items) item.id], index);
      await _loadCurrent(play: autoplay, position: position);
      await _preload();
      _emit(force: true);
    });
  }

  @override
  Future<void> toggle() {
    if (_primary.playing) return pause();
    return play();
  }

  @override
  Future<void> play() {
    return _serialize(() async {
      if (_queue.currentId == null) return;
      if (_primary.processingState == ProcessingState.idle ||
          _primary.processingState == ProcessingState.completed) {
        await _loadCurrent(play: true);
        await _preload();
      } else {
        await _playInternal();
      }
      _emit(force: true);
    });
  }

  @override
  Future<void> pause() {
    return _serialize(() async {
      await _pauseInternal();
      _emit(force: true);
    });
  }

  @override
  Future<void> next() {
    return _serialize(() async {
      await _cancelFade();
      final step = _queue.skipNext();
      if (step.stopped || step.id == null) {
        await _pauseInternal();
      } else {
        await _loadCurrent(play: true);
        await _preload();
      }
      _emit(force: true);
    });
  }

  @override
  Future<void> previous() {
    return _serialize(() async {
      await _cancelFade();
      final step = _queue.skipPrevious(_primary.position);
      if (step.restart) {
        await _primary.seek(Duration.zero);
        if (!_primary.playing) await _primary.play();
      } else if (step.id != null) {
        await _loadCurrent(play: true);
        await _preload();
      }
      _emit(force: true);
    });
  }

  @override
  Future<void> seek(Duration position) {
    return _serialize(() async {
      await _cancelFade();
      await _primary.seek(position);
      _emit(force: true);
    });
  }

  @override
  Future<void> setVolume(double volume) async {
    _userVolume = volume.clamp(0, 1).toDouble();
    await _applyVolumes();
    _emit(force: true);
  }

  @override
  Future<void> setSpeed(double speed) async {
    _speed = speed.clamp(0.5, 2).toDouble();
    await _applyTransport();
    _emit(force: true);
  }

  @override
  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 1.5).toDouble();
    await _applyTransport();
    _emit(force: true);
  }

  @override
  Future<void> setShuffle(bool enabled) {
    return _serialize(() async {
      _queue.setShuffle(enabled);
      await _preload();
      _emit(force: true);
    });
  }

  @override
  Future<void> cycleRepeat() {
    return _serialize(() async {
      _queue.cycleRepeat();
      await _preload();
      _emit(force: true);
    });
  }

  @override
  Future<void> setRepeat(RepeatMode mode) {
    return _serialize(() async {
      _queue.setRepeat(mode);
      await _preload();
      _emit(force: true);
    });
  }

  @override
  Future<void> addNext(Playable item) {
    return _serialize(() async {
      _catalog[item.id] = item;
      _queue.addNext(item.id);
      await _preload();
      _emit(force: true);
    });
  }

  @override
  Future<void> enqueue(Playable item) {
    return _serialize(() async {
      _catalog[item.id] = item;
      _queue.addLast(item.id);
      await _preload();
      _emit(force: true);
    });
  }

  @override
  Future<void> playIndex(int index) {
    return _serialize(() async {
      await _cancelFade();
      if (index < 0 || index >= _queue.order.length) return;
      _queue.index = index;
      await _loadCurrent(play: true);
      await _preload();
      _emit(force: true);
    });
  }

  @override
  Future<void> removeAt(int index) {
    return _serialize(() async {
      final removingCurrent = index == _queue.index;
      _queue.removeAt(index);
      if (_queue.order.isEmpty) {
        await _pauseInternal();
      } else if (removingCurrent) {
        await _loadCurrent(play: _snapshot.playing);
      }
      await _preload();
      _emit(force: true);
    });
  }

  @override
  Future<void> move(int from, int to) {
    return _serialize(() async {
      _queue.move(from, to);
      await _preload();
      _emit(force: true);
    });
  }

  @override
  Future<void> clearUpcoming() {
    return _serialize(() async {
      await _cancelFade();
      _queue.clearAfterCurrent();
      await _preload();
      _emit(force: true);
    });
  }

  @override
  Future<void> setCrossfade(Duration duration) async {
    final seconds = duration.inMilliseconds / 1000;
    _crossfade = Duration(milliseconds: (seconds.clamp(0, 12) * 1000).round());
    _emit(force: true);
  }

  @override
  Future<void> applyEq(EqSettings settings) async {
    _eq = settings;
    await _applyEqNow();
    _emit(force: true);
  }

  @override
  void setSleepMinutes(int minutes) {
    _sleepTimer?.cancel();
    _sleepEndOfTrack = false;
    if (minutes <= 0) {
      _sleepUntil = null;
      _emit(force: true);
      return;
    }
    _sleepUntil = DateTime.now().add(Duration(minutes: minutes));
    _sleepTimer = Timer(Duration(minutes: minutes), () {
      _sleepUntil = null;
      unawaited(pause());
    });
    _emit(force: true);
  }

  @override
  void setSleepEndOfTrack() {
    _sleepTimer?.cancel();
    _sleepUntil = null;
    _sleepEndOfTrack = true;
    _emit(force: true);
  }

  @override
  void clearSleep() {
    _sleepTimer?.cancel();
    _sleepUntil = null;
    _sleepEndOfTrack = false;
    _emit(force: true);
  }

  @override
  Future<void> stop() {
    return _serialize(() async {
      await _cancelFade();
      await _primary.stop();
      _queue.replace(const [], 0);
      _contextLabel = null;
      _error = null;
      _emit(force: true);
    });
  }

  Future<void> _handleNaturalEnd() async {
    if (_fading) return;
    if (_sleepEndOfTrack) {
      _sleepEndOfTrack = false;
      await _pauseInternal();
      _emit(force: true);
      return;
    }
    final upcoming = _queue.peekUpcomingId();
    final secondary = _secondary;
    if (_secondaryReady &&
        secondary != null &&
        _secondaryLoadedId != null &&
        _secondaryLoadedId == upcoming) {
      try {
        _secondaryFade = 1;
        await secondary.setVolume(_userVolume);
        await secondary.play();
        _queue.moveTo(_secondaryLoadedId!);
        await _primary.pause();
        _swap();
        await _preload();
        _emit(force: true);
        return;
      } catch (error, stack) {
        log('Gapless handoff failed.', error: error, stackTrace: stack);
      }
    }
    final step = _queue.complete();
    if (step.restart) {
      await _primary.seek(Duration.zero);
      await _primary.play();
      _emit(force: true);
      return;
    }
    if (step.stopped || step.id == null) {
      await _pauseInternal();
      _emit(force: true);
      return;
    }
    await _loadCurrent(play: true);
    await _preload();
    _emit(force: true);
  }

  Future<void> _loadCurrent({
    required bool play,
    Duration position = Duration.zero,
    int hops = 0,
  }) async {
    final id = _queue.currentId;
    final item = id == null ? null : _catalog[id];
    if (item == null) {
      _error = 'Nothing is queued.';
      return;
    }
    try {
      await _primary.setAudioSource(
        AudioSource.uri(item.uri, headers: const {'User-Agent': kUserAgent}),
      );
      await _applyTransport();
      _primaryFade = 1;
      _secondaryFade = 0;
      await _applyVolumes();
      if (position > Duration.zero) await _primary.seek(position);
      if (play) {
        await _primary.play();
      } else {
        await _primary.pause();
      }
      _error = null;
      unawaited(_applyEqNow());
    } catch (error, stack) {
      log('Could not open ${item.title}.', error: error, stackTrace: stack);
      _error = 'Could not play ${item.title}.';
      if (!play || hops >= 3) return;
      final step = _queue.skipNext();
      if (step.stopped || step.id == null) return;
      await _loadCurrent(play: true, hops: hops + 1);
    }
  }

  Future<void> _preload() async {
    _secondaryReady = false;
    _secondaryLoadedId = null;
    final secondary = _secondary;
    final nextId = _queue.peekUpcomingId();
    if (secondary == null || nextId == null) return;
    final item = _catalog[nextId];
    if (item == null) return;
    try {
      await secondary.setAudioSource(
        AudioSource.uri(item.uri, headers: const {'User-Agent': kUserAgent}),
      );
      await secondary.setSpeed(_speed);
      try {
        await secondary.setPitch(_pitch);
      } catch (_) {}
      await secondary.pause();
      await secondary.seek(Duration.zero);
      _secondaryLoadedId = nextId;
      _secondaryReady = true;
      _secondaryFade = 0;
      await _applyVolumes();
    } catch (error, stack) {
      _secondaryReady = false;
      log('Preload failed.', error: error, stackTrace: stack);
    }
  }

  void _maybeStartFade() {
    if (_fading || _crossfade <= Duration.zero || !_secondaryReady) return;
    final duration = _primary.duration;
    if (duration == null || duration == Duration.zero) return;
    final remaining = duration - _primary.position;
    if (remaining < const Duration(milliseconds: 350)) return;
    if (remaining <= _crossfade) {
      unawaited(_serialize(_beginFade));
    }
  }

  Future<void> _beginFade() async {
    if (_fading || !_secondaryReady) return;
    final secondary = _secondary;
    final incoming = _secondaryLoadedId;
    if (secondary == null || incoming == null) return;
    _fading = true;
    final token = ++_fadeToken;
    try {
      _secondaryFade = 0;
      await secondary.setVolume(0);
      await secondary.play();
    } catch (error, stack) {
      _fading = false;
      log('Crossfade could not start.', error: error, stackTrace: stack);
      return;
    }
    final remaining = (_primary.duration ?? Duration.zero) - _primary.position;
    var fadeFor = _crossfade;
    if (remaining > const Duration(milliseconds: 350) && remaining < fadeFor) {
      fadeFor = remaining;
    }
    unawaited(_runFade(token, fadeFor, incoming));
  }

  Future<void> _runFade(int token, Duration fadeFor, String incoming) async {
    const steps = 24;
    final step = Duration(
      microseconds: (fadeFor.inMicroseconds / steps).round().clamp(1, 1 << 30),
    );
    for (var i = 1; i <= steps; i++) {
      if (token != _fadeToken) return;
      _primaryFade = 1 - (i / steps);
      _secondaryFade = i / steps;
      try {
        await _applyVolumes();
      } catch (_) {}
      await Future<void>.delayed(step);
    }
    if (token != _fadeToken) return;
    await _serialize(() async {
      if (token != _fadeToken) return;
      await _primary.pause();
      _queue.moveTo(incoming);
      _swap();
      _fading = false;
      await _preload();
      _emit(force: true);
    });
  }

  Future<void> _cancelFade() async {
    _fadeToken++;
    _fading = false;
    _primaryFade = 1;
    _secondaryFade = 0;
    final secondary = _secondary;
    if (secondary != null) {
      try {
        await secondary.pause();
      } catch (_) {}
    }
    await _applyVolumes();
  }

  void _swap() {
    final secondary = _secondary;
    if (secondary == null) return;
    final previous = _primary;
    _primary = secondary;
    _secondary = previous;
    _primaryFade = 1;
    _secondaryFade = 0;
    _secondaryReady = false;
    _secondaryLoadedId = null;
  }

  Future<void> _applyVolumes() async {
    try {
      await _primary.setVolume((_userVolume * _primaryFade).clamp(0, 1));
    } catch (_) {}
    final secondary = _secondary;
    if (secondary == null) return;
    try {
      await secondary.setVolume((_userVolume * _secondaryFade).clamp(0, 1));
    } catch (_) {}
  }

  Future<void> _applyTransport() async {
    try {
      await _primary.setSpeed(_speed);
    } catch (_) {}
    try {
      await _primary.setPitch(_pitch);
    } catch (_) {}
    final secondary = _secondary;
    if (secondary == null) return;
    try {
      await secondary.setSpeed(_speed);
    } catch (_) {}
    try {
      await secondary.setPitch(_pitch);
    } catch (_) {}
  }

  Future<void> _playInternal() async {
    await _primary.play();
    if (_fading) {
      try {
        await _secondary?.play();
      } catch (_) {}
    }
  }

  Future<void> _pauseInternal() async {
    await _primary.pause();
    if (_fading) {
      try {
        await _secondary?.pause();
      } catch (_) {}
    }
  }

  Future<void> _applyEqNow() async {
    await _applyEq(_eqA);
    await _applyEq(_eqB);
  }

  Future<void> _applyEq(AndroidEqualizer? equalizer) async {
    if (equalizer == null || !isAndroidDevice) return;
    try {
      final enabled = _eq.enabled && _eq.gains.any((gain) => gain.abs() > 0.05);
      await equalizer.setEnabled(enabled);
      if (!enabled) return;
      final parameters = await equalizer.parameters.timeout(
        const Duration(seconds: 2),
      );
      final bands = parameters.bands;
      for (var i = 0; i < bands.length; i++) {
        final gain = mapEqGain(
          i,
          bands.length,
          _eq.gains,
        ).clamp(parameters.minDecibels, parameters.maxDecibels).toDouble();
        await bands[i].setGain(gain);
      }
    } catch (error, stack) {
      log('Equalizer was not applied.', error: error, stackTrace: stack);
    }
  }

  void _emit({bool force = false}) {
    _snapshot = _capture();
    if (force) {
      _emitTimer?.cancel();
      _emitQueued = false;
      if (!_updates.isClosed) _updates.add(_snapshot);
      return;
    }
    if (_emitQueued) return;
    _emitQueued = true;
    _emitTimer = Timer(const Duration(milliseconds: 200), () {
      _emitQueued = false;
      if (!_updates.isClosed) _updates.add(_snapshot);
    });
  }

  PlayerSnapshot _capture() {
    final id = _queue.currentId;
    final track = id == null ? null : _catalog[id];
    final duration = _primary.duration ?? track?.duration ?? Duration.zero;
    return PlayerSnapshot(
      track: track,
      playing: _primary.playing,
      position: _primary.position,
      buffered: _primary.bufferedPosition,
      duration: duration,
      volume: _userVolume,
      speed: _speed,
      pitch: _pitch,
      queue: [
        for (final queued in _queue.order)
          if (_catalog[queued] != null) _catalog[queued]!,
      ],
      index: _queue.index,
      shuffle: _queue.shuffle,
      repeat: _queue.repeat,
      contextLabel: _contextLabel,
      sourceLabel: track?.sourceLabel,
      error: _error,
      sleepUntil: _sleepUntil,
      sleepEndOfTrack: _sleepEndOfTrack,
      crossfade: _crossfade,
      eq: _eq,
    );
  }

  Future<void> dispose() async {
    _sleepTimer?.cancel();
    _emitTimer?.cancel();
    await _primary.dispose();
    await _secondary?.dispose();
    await _updates.close();
  }
}
