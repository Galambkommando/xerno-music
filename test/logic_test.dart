import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xerno_music/src/logic/eq.dart';
import 'package:xerno_music/src/logic/lrc.dart';
import 'package:xerno_music/src/logic/play_queue.dart';
import 'package:xerno_music/src/logic/source_resolver.dart';
import 'package:xerno_music/src/logic/track_query.dart';
import 'package:xerno_music/src/models/settings.dart';
import 'package:xerno_music/src/models/sync.dart';
import 'package:xerno_music/src/models/track.dart';
import 'package:xerno_music/src/models/user_library.dart';

void main() {
  group('play queue', () {
    test('shuffles only the upcoming tail', () {
      final queue = PlayQueue(random: Random(7));
      queue.replace(const ['a', 'b', 'c', 'd', 'e'], 0);
      queue.setShuffle(true);
      expect(queue.currentId, 'a');
      expect(queue.order.first, 'a');
      expect(queue.order.toSet(), {'a', 'b', 'c', 'd', 'e'});
      queue.setShuffle(false);
      expect(queue.order, ['a', 'b', 'c', 'd', 'e']);
      expect(queue.index, 0);
    });

    test('repeat one restarts and user skip still wraps', () {
      final queue = PlayQueue();
      queue.replace(const ['a', 'b'], 1);
      queue.setRepeat(RepeatMode.one);
      expect(queue.peekUpcomingId(), isNull);
      expect(queue.complete().restart, isTrue);
      expect(queue.index, 1);
      expect(queue.skipNext().id, 'a');
    });

    test('previous restarts after three seconds', () {
      final queue = PlayQueue();
      queue.replace(const ['a', 'b'], 1);
      final step = queue.skipPrevious(const Duration(seconds: 4));
      expect(step.restart, isTrue);
      expect(queue.index, 1);
      expect(queue.skipPrevious(Duration.zero).id, 'a');
    });

    test('move follows the current item and remove keeps the index', () {
      final queue = PlayQueue();
      queue.replace(const ['a', 'b', 'c'], 0);
      queue.move(0, 2);
      expect(queue.order, ['b', 'c', 'a']);
      expect(queue.index, 2);
      queue.removeAt(0);
      expect(queue.order, ['c', 'a']);
      expect(queue.index, 1);
      expect(queue.linear, ['a', 'c']);
    });
  });

  group('sources', () {
    test('joins a cloud base without encoding slashes', () {
      expect(
        joinCloudUrl('https://cloud.example/audio/', 'liked/My Song.mp3'),
        'https://cloud.example/audio/liked/My%20Song.mp3',
      );
    });

    test('auto prefers a pin and cloud first prefers the remote url', () {
      final root = Directory.systemTemp.createTempSync('xerno-src');
      addTearDown(() => root.deleteSync(recursive: true));
      final library = Directory('${root.path}/library')..createSync();
      final pins = Directory('${root.path}/pins')..createSync();
      File('${library.path}/liked/song.mp3')
        ..createSync(recursive: true)
        ..writeAsStringSync('local');
      File('${pins.path}/t1.mp3').writeAsStringSync('pin');
      const track = TrackRecord(
        id: 't1',
        title: 'Song',
        artist: 'Artist',
        file: TrackFile(
          relativePath: 'liked/song.mp3',
          ziplineUrl: 'https://cdn.example/song.mp3',
        ),
      );
      const resolver = SourceResolver();
      final settings = AppSettings(
        deviceId: 'device',
        localLibraryPath: library.path,
      );
      final pinned = resolver.resolve(
        track: track,
        settings: settings,
        pinDirectory: pins.path,
      );
      expect(pinned!.label, 'Pinned');
      final remote = resolver.resolve(
        track: track,
        settings: settings.copyWith(
          sourcePreference: SourcePreference.cloudFirst,
        ),
        pinDirectory: pins.path,
      );
      expect(remote!.label, 'Zipline');
      expect(remote.uri.toString(), 'https://cdn.example/song.mp3');
      final local = resolver.resolve(track: track, settings: settings);
      expect(local!.label, 'Local');
      expect(
        resolver.resolve(
          track: const TrackRecord(id: 'missing', title: 'No', artist: 'No'),
          settings: settings,
        ),
        isNull,
      );
    });
  });

  group('lyrics and sorting', () {
    test('parses multi-stamp LRC lines', () {
      final lines = parseLrc('[00:01.5] Hello\n[00:01.50][00:03] Again');
      expect(lines, hasLength(3));
      expect(lines.first.time, const Duration(seconds: 1, milliseconds: 500));
      expect(lines[1].text, 'Again');
      expect(lines[2].time, const Duration(seconds: 3));
      expect(activeLyricIndex(lines, const Duration(seconds: 2)), 1);
      expect(
        closestLrclibRow(const [
          {'duration': 200, 'id': 'far'},
          {'duration': 181, 'id': 'near'},
        ], 180)!['id'],
        'near',
      );
    });

    test('keeps unknown years last while sorting', () {
      const tracks = [
        TrackRecord(
          id: 'b',
          title: 'Beta',
          artist: 'B',
          year: null,
          durationSec: 10,
        ),
        TrackRecord(
          id: 'a',
          title: 'Alpha',
          artist: 'A',
          year: 2001,
          durationSec: 30,
        ),
        TrackRecord(
          id: 'c',
          title: 'Gamma',
          artist: 'A',
          year: 2020,
          durationSec: 20,
        ),
      ];
      final sorted = sortTracks(tracks, TrackSort.year, ascending: false);
      expect(sorted.map((track) => track.id).toList(), ['c', 'a', 'b']);
      final filtered = filterTracks(tracks, 'alpha 2001');
      expect(filtered.single.id, 'a');
    });
  });

  group('libraries and sync', () {
    test('clamps settings and round-trips them', () {
      final settings = AppSettings.fromJson(const {
        'volume': 4,
        'crossfade_seconds': 40,
        'speed': 9,
        'pitch': 0.1,
        'eq_gains': [1, 2],
        'device_id': 'abc',
        'frosted_glass': false,
      });
      expect(settings.volume, 1);
      expect(settings.crossfadeSeconds, 12);
      expect(settings.speed, 2);
      expect(settings.pitch, 0.5);
      expect(settings.eqGains, [1, 2, 0, 0, 0]);
      expect(settings.frostedGlass, isFalse);
      final again = AppSettings.fromJson(settings.toJson());
      expect(again.deviceId, 'abc');
      expect(again.eqPreset, 'Flat');
    });

    test('merges custom playlists by name and can replace them', () {
      final local = UserLibraryData.empty().addPlaylist('Night');
      final localId = local.playlists.single.id;
      final withTrack = local.addTrack(localId, 'a').toggleFavorite('a');
      final incoming = UserLibraryData.empty().addPlaylist('Night');
      final incomingId = incoming.playlists.single.id;
      final merged = mergeUserLibraries(
        withTrack,
        incoming.addTrack(incomingId, 'b').toggleFavorite('b'),
        replace: false,
      );
      expect(merged.favorites, containsAll(['a', 'b']));
      expect(merged.playlists.single.trackIds, ['a', 'b']);
      final replaced = mergeUserLibraries(withTrack, incoming, replace: true);
      expect(replaced.favorites, isEmpty);
      expect(replaced.playlists.single.trackIds, isEmpty);
    });

    test('round-trips a sync payload', () {
      final playlist = UserLibraryData.empty()
          .addPlaylist('Road')
          .playlists
          .single;
      final payload = SyncPayload(
        deviceId: 'dev',
        libraryUpdatedAt: '2026-01-01T00:00:00.000Z',
        playbackUpdatedAt: '2026-01-02T00:00:00.000Z',
        favorites: const ['a'],
        playlists: [playlist],
        bookmark: const PlaybackBookmark(
          trackId: 'a',
          positionMs: 1500,
          queueIds: ['a'],
        ),
      );
      final again = SyncPayload.fromJson(payload.toJson());
      expect(again.deviceId, 'dev');
      expect(again.favorites, ['a']);
      expect(again.playlists.single.name, 'Road');
      expect(again.bookmark!.positionMs, 1500);
      expect(
        isNewerStamp('2026-02-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
        isTrue,
      );
      expect(
        isNewerStamp('2026-01-01T00:00:00.000Z', '2026-02-01T00:00:00.000Z'),
        isFalse,
      );
    });

    test('maps five bands onto a device equalizer', () {
      expect(mapEqGain(0, 5, const [1, 2, 3, 4, 5]), 1);
      expect(mapEqGain(4, 5, const [1, 2, 3, 4, 5]), 5);
      expect(mapEqGain(0, 1, const [1, 2, 3, 4, 5]), 3);
      expect(mapEqGain(1, 2, const [0, 10]), closeTo(10, 0.001));
    });
  });
}
