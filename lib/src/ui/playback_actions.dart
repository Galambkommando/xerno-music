import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/source_resolver.dart';
import '../models/track.dart';
import '../models/user_library.dart';
import '../player/playback.dart';
import '../state/providers.dart';

Future<String?> playTracks(
  WidgetRef ref, {
  required List<TrackRecord> tracks,
  int index = 0,
  String? contextLabel,
  bool autoplay = true,
  Duration position = Duration.zero,
}) async {
  if (tracks.isEmpty) return 'This list has no tracks yet.';
  final settings = ref.read(settingsProvider);
  final downloads = ref.read(downloadManagerProvider);
  await downloads.ensureLoaded();
  final resolver = ref.read(sourceResolverProvider);
  final playables = <Playable>[];
  int? selected;
  int? after;
  for (var i = 0; i < tracks.length; i++) {
    final track = tracks[i];
    final resolved = resolver.resolve(
      track: track,
      settings: settings,
      pinDirectory: downloads.directoryPath,
    );
    if (resolved == null) continue;
    if (i == index) selected = playables.length;
    if (after == null && i > index) after = playables.length;
    playables.add(_playable(track, resolved));
  }
  if (playables.isEmpty) {
    return 'No audio source for these tracks. Set a local library folder, a cloud base URL, or pin a download.';
  }
  await ref
      .read(playerProvider)
      .playAll(
        playables,
        index: selected ?? after ?? 0,
        contextLabel: contextLabel,
        autoplay: autoplay,
        position: selected == null ? Duration.zero : position,
      );
  if (selected == null) {
    return 'The chosen track has no audio yet. Playing the nearest one that does.';
  }
  return null;
}

Future<void> restoreBookmark(
  WidgetRef ref,
  PlaybackBookmark bookmark, {
  required bool autoplay,
}) async {
  final catalog = ref.read(libraryProvider).valueOrNull;
  if (catalog == null || bookmark.isEmpty) return;
  final tracks = <TrackRecord>[];
  for (final id in bookmark.queueIds) {
    final track = catalog.byId[id];
    if (track != null) tracks.add(track);
  }
  if (tracks.isEmpty && bookmark.trackId != null) {
    final track = catalog.byId[bookmark.trackId!];
    if (track != null) tracks.add(track);
  }
  if (tracks.isEmpty) return;
  final index = bookmark.index.clamp(0, tracks.length - 1);
  await playTracks(
    ref,
    tracks: tracks,
    index: index,
    contextLabel: bookmark.contextLabel,
    autoplay: autoplay,
    position: Duration(milliseconds: bookmark.positionMs),
  );
  final player = ref.read(playerProvider);
  await player.setShuffle(bookmark.shuffle);
  await player.setRepeat(repeatFromBookmark(bookmark.repeat));
}

Future<Playable?> resolveOne(WidgetRef ref, TrackRecord track) async {
  final settings = ref.read(settingsProvider);
  final downloads = ref.read(downloadManagerProvider);
  await downloads.ensureLoaded();
  final resolved = ref
      .read(sourceResolverProvider)
      .resolve(
        track: track,
        settings: settings,
        pinDirectory: downloads.directoryPath,
      );
  if (resolved == null) return null;
  return _playable(track, resolved);
}

Playable _playable(TrackRecord track, ResolvedAudio resolved) {
  return Playable(
    id: track.id,
    title: track.title,
    artist: track.artist,
    album: track.album,
    year: track.year,
    explicit: track.explicit,
    duration: Duration(seconds: track.durationSec),
    uri: resolved.uri,
    sourceLabel: resolved.label,
    artUri: track.coverUrl == null ? null : Uri.tryParse(track.coverUrl!),
    bitrateKbps: track.audioQuality.bitrateKbps,
    sampleRateHz: track.audioQuality.sampleRateHz,
  );
}

void showNote(BuildContext context, String? message) {
  if (message == null || message.isEmpty || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
