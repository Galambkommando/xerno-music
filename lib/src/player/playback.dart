import 'dart:async';

import '../logic/eq.dart';
import '../logic/play_queue.dart';
import '../models/user_library.dart';

class Playable {
  const Playable({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.uri,
    required this.sourceLabel,
    this.year,
    this.explicit = false,
    this.artUri,
    this.bitrateKbps = 320,
    this.sampleRateHz = 48000,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final int? year;
  final bool explicit;
  final Duration duration;
  final Uri uri;
  final String sourceLabel;
  final Uri? artUri;
  final int bitrateKbps;
  final int sampleRateHz;
}

class PlayerSnapshot {
  const PlayerSnapshot({
    this.track,
    this.playing = false,
    this.position = Duration.zero,
    this.buffered = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 0.9,
    this.speed = 1,
    this.pitch = 1,
    this.queue = const [],
    this.index = 0,
    this.shuffle = false,
    this.repeat = RepeatMode.off,
    this.contextLabel,
    this.sourceLabel,
    this.error,
    this.sleepUntil,
    this.sleepEndOfTrack = false,
    this.crossfade = Duration.zero,
    this.eq = const EqSettings(),
  });

  static const idle = PlayerSnapshot();

  final Playable? track;
  final bool playing;
  final Duration position;
  final Duration buffered;
  final Duration duration;
  final double volume;
  final double speed;
  final double pitch;
  final List<Playable> queue;
  final int index;
  final bool shuffle;
  final RepeatMode repeat;
  final String? contextLabel;
  final String? sourceLabel;
  final String? error;
  final DateTime? sleepUntil;
  final bool sleepEndOfTrack;
  final Duration crossfade;
  final EqSettings eq;

  bool get hasTrack => track != null;

  PlaybackBookmark toBookmark() {
    return PlaybackBookmark(
      trackId: track?.id,
      positionMs: position.inMilliseconds,
      queueIds: [for (final item in queue) item.id],
      index: index,
      shuffle: shuffle,
      repeat: repeat.name,
      contextLabel: contextLabel,
    );
  }
}

abstract class PlaybackPort {
  PlayerSnapshot get snapshot;
  Stream<PlayerSnapshot> get snapshots;

  Future<void> playAll(
    List<Playable> items, {
    int index = 0,
    String? contextLabel,
    bool autoplay = true,
    Duration position = Duration.zero,
  });

  Future<void> toggle();
  Future<void> play();
  Future<void> pause();
  Future<void> next();
  Future<void> previous();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> setSpeed(double speed);
  Future<void> setPitch(double pitch);
  Future<void> setShuffle(bool enabled);
  Future<void> cycleRepeat();
  Future<void> setRepeat(RepeatMode mode);
  Future<void> addNext(Playable item);
  Future<void> enqueue(Playable item);
  Future<void> playIndex(int index);
  Future<void> removeAt(int index);
  Future<void> move(int from, int to);
  Future<void> clearUpcoming();
  Future<void> setCrossfade(Duration duration);
  Future<void> applyEq(EqSettings settings);
  void setSleepMinutes(int minutes);
  void setSleepEndOfTrack();
  void clearSleep();
  Future<void> stop();
}

class ManualPlayback implements PlaybackPort {
  ManualPlayback({PlayerSnapshot? initial, this.failure})
    : snapshot =
          initial ??
          (failure == null
              ? PlayerSnapshot.idle
              : PlayerSnapshot(error: failure));

  final String? failure;

  @override
  PlayerSnapshot snapshot;

  void _emit(PlayerSnapshot next) {
    snapshot = next;
    _controller.add(next);
  }

  final _controller = _Broadcast();

  @override
  Stream<PlayerSnapshot> get snapshots => _controller.stream;

  @override
  Future<void> playAll(
    List<Playable> items, {
    int index = 0,
    String? contextLabel,
    bool autoplay = true,
    Duration position = Duration.zero,
  }) async {
    if (items.isEmpty) {
      _emit(snapshot.copy(error: failure ?? 'Nothing to play.'));
      return;
    }
    final start = index.clamp(0, items.length - 1);
    final track = items[start];
    _emit(
      PlayerSnapshot(
        track: track,
        playing: failure == null && autoplay,
        position: position,
        duration: track.duration,
        queue: items,
        index: start,
        contextLabel: contextLabel,
        sourceLabel: track.sourceLabel,
        error: failure,
        volume: snapshot.volume,
        speed: snapshot.speed,
        pitch: snapshot.pitch,
        crossfade: snapshot.crossfade,
        eq: snapshot.eq,
      ),
    );
  }

  @override
  Future<void> toggle() async {
    if (snapshot.track == null) return;
    _emit(snapshot.copy(playing: !snapshot.playing));
  }

  @override
  Future<void> play() async =>
      _emit(snapshot.copy(playing: snapshot.track != null));

  @override
  Future<void> pause() async => _emit(snapshot.copy(playing: false));

  @override
  Future<void> next() async => _step(1);

  @override
  Future<void> previous() async => _step(-1);

  Future<void> _step(int delta) async {
    if (snapshot.queue.isEmpty) return;
    final next = (snapshot.index + delta).clamp(0, snapshot.queue.length - 1);
    final track = snapshot.queue[next];
    _emit(
      snapshot.copy(
        track: track,
        index: next,
        playing: true,
        position: Duration.zero,
        duration: track.duration,
        sourceLabel: track.sourceLabel,
      ),
    );
  }

  @override
  Future<void> seek(Duration position) async =>
      _emit(snapshot.copy(position: position));

  @override
  Future<void> setVolume(double volume) async =>
      _emit(snapshot.copy(volume: volume.clamp(0, 1).toDouble()));

  @override
  Future<void> setSpeed(double speed) async =>
      _emit(snapshot.copy(speed: speed.clamp(0.5, 2).toDouble()));

  @override
  Future<void> setPitch(double pitch) async =>
      _emit(snapshot.copy(pitch: pitch.clamp(0.5, 1.5).toDouble()));

  @override
  Future<void> setShuffle(bool enabled) async =>
      _emit(snapshot.copy(shuffle: enabled));

  @override
  Future<void> cycleRepeat() async {
    final next = switch (snapshot.repeat) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    _emit(snapshot.copy(repeat: next));
  }

  @override
  Future<void> setRepeat(RepeatMode mode) async =>
      _emit(snapshot.copy(repeat: mode));

  @override
  Future<void> addNext(Playable item) async {
    final queue = [...snapshot.queue];
    final at = queue.isEmpty ? 0 : snapshot.index + 1;
    queue.insert(at.clamp(0, queue.length), item);
    _emit(snapshot.copy(queue: queue, track: snapshot.track ?? item));
  }

  @override
  Future<void> enqueue(Playable item) async {
    _emit(
      snapshot.copy(
        queue: [...snapshot.queue, item],
        track: snapshot.track ?? item,
      ),
    );
  }

  @override
  Future<void> playIndex(int index) async {
    if (index < 0 || index >= snapshot.queue.length) return;
    final track = snapshot.queue[index];
    _emit(
      snapshot.copy(
        index: index,
        track: track,
        playing: true,
        position: Duration.zero,
        duration: track.duration,
        sourceLabel: track.sourceLabel,
      ),
    );
  }

  @override
  Future<void> removeAt(int index) async {
    if (index < 0 || index >= snapshot.queue.length) return;
    final queue = [...snapshot.queue]..removeAt(index);
    final nextIndex = queue.isEmpty
        ? 0
        : snapshot.index.clamp(0, queue.length - 1);
    _emit(
      snapshot.copy(
        queue: queue,
        index: nextIndex,
        track: queue.isEmpty ? null : queue[nextIndex],
      ),
    );
  }

  @override
  Future<void> move(int from, int to) async {
    if (from < 0 ||
        to < 0 ||
        from >= snapshot.queue.length ||
        to >= snapshot.queue.length) {
      return;
    }
    final queue = [...snapshot.queue];
    final item = queue.removeAt(from);
    queue.insert(to, item);
    _emit(snapshot.copy(queue: queue));
  }

  @override
  Future<void> clearUpcoming() async {
    if (snapshot.queue.isEmpty) return;
    final keep = snapshot.queue.take(snapshot.index + 1).toList();
    _emit(snapshot.copy(queue: keep));
  }

  @override
  Future<void> setCrossfade(Duration duration) async =>
      _emit(snapshot.copy(crossfade: duration));

  @override
  Future<void> applyEq(EqSettings settings) async =>
      _emit(snapshot.copy(eq: settings));

  @override
  void setSleepMinutes(int minutes) {
    _emit(
      snapshot.copy(
        sleepUntil: minutes <= 0
            ? null
            : DateTime.now().add(Duration(minutes: minutes)),
        sleepEndOfTrack: false,
      ),
    );
  }

  @override
  void setSleepEndOfTrack() =>
      _emit(snapshot.copy(sleepEndOfTrack: true, clearSleepUntil: true));

  @override
  void clearSleep() =>
      _emit(snapshot.copy(sleepEndOfTrack: false, clearSleepUntil: true));

  @override
  Future<void> stop() async =>
      _emit(PlayerSnapshot(volume: snapshot.volume, eq: snapshot.eq));
}

class _Broadcast {
  final _controller = StreamController<PlayerSnapshot>.broadcast();
  Stream<PlayerSnapshot> get stream => _controller.stream;
  void add(PlayerSnapshot snapshot) => _controller.add(snapshot);
}

extension on PlayerSnapshot {
  PlayerSnapshot copy({
    Playable? track,
    bool clearTrack = false,
    bool? playing,
    Duration? position,
    Duration? duration,
    double? volume,
    double? speed,
    double? pitch,
    List<Playable>? queue,
    int? index,
    bool? shuffle,
    RepeatMode? repeat,
    String? contextLabel,
    String? sourceLabel,
    String? error,
    DateTime? sleepUntil,
    bool clearSleepUntil = false,
    bool? sleepEndOfTrack,
    Duration? crossfade,
    EqSettings? eq,
  }) {
    return PlayerSnapshot(
      track: clearTrack ? null : (track ?? this.track),
      playing: playing ?? this.playing,
      position: position ?? this.position,
      buffered: buffered,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      speed: speed ?? this.speed,
      pitch: pitch ?? this.pitch,
      queue: queue ?? this.queue,
      index: index ?? this.index,
      shuffle: shuffle ?? this.shuffle,
      repeat: repeat ?? this.repeat,
      contextLabel: contextLabel ?? this.contextLabel,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      error: error,
      sleepUntil: clearSleepUntil ? null : (sleepUntil ?? this.sleepUntil),
      sleepEndOfTrack: sleepEndOfTrack ?? this.sleepEndOfTrack,
      crossfade: crossfade ?? this.crossfade,
      eq: eq ?? this.eq,
    );
  }
}
