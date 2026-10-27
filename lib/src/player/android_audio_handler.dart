import 'package:audio_service/audio_service.dart';

import 'playback.dart';
import 'xerno_engine.dart';

class AndroidAudioHandler extends BaseAudioHandler with SeekHandler {
  AndroidAudioHandler(this.engine) {
    engine.snapshots.listen(_mirror);
    _mirror(engine.snapshot);
  }

  final XernoEngine engine;

  void _mirror(PlayerSnapshot snapshot) {
    final track = snapshot.track;
    if (track != null) {
      mediaItem.add(
        MediaItem(
          id: track.id,
          title: track.title,
          album: track.album,
          artist: track.artist,
          duration: snapshot.duration == Duration.zero
              ? track.duration
              : snapshot.duration,
          artUri: track.artUri,
          extras: {'source': track.sourceLabel},
        ),
      );
    }
    queue.add([
      for (final item in snapshot.queue)
        MediaItem(
          id: item.id,
          title: item.title,
          album: item.album,
          artist: item.artist,
          duration: item.duration,
          artUri: item.artUri,
        ),
    ]);
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          snapshot.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: track == null
            ? AudioProcessingState.idle
            : AudioProcessingState.ready,
        playing: snapshot.playing,
        updatePosition: snapshot.position,
        bufferedPosition: snapshot.buffered,
        speed: snapshot.speed,
        queueIndex: snapshot.index,
      ),
    );
  }

  @override
  Future<void> play() => engine.play();

  @override
  Future<void> pause() => engine.pause();

  @override
  Future<void> seek(Duration position) => engine.seek(position);

  @override
  Future<void> skipToNext() => engine.next();

  @override
  Future<void> skipToPrevious() => engine.previous();

  @override
  Future<void> stop() => engine.stop();
}
