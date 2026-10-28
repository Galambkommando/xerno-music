import 'dart:convert';

import '../logic/track_query.dart';
import 'json_util.dart';
import 'track.dart';

class AudioSpec {
  const AudioSpec({
    this.format = 'mp3',
    this.codec = 'libmp3lame',
    this.bitrateKbps = 320,
    this.sampleRateHz = 48000,
    this.channels = 2,
    this.id3Version = '',
    this.embeddedCoverArt = '',
  });

  final String format;
  final String codec;
  final int bitrateKbps;
  final int sampleRateHz;
  final int channels;
  final String id3Version;
  final String embeddedCoverArt;

  factory AudioSpec.fromJson(Object? json) {
    final map = asMap(json);
    return AudioSpec(
      format: asString(map['format'], 'mp3'),
      codec: asString(map['codec'], 'libmp3lame'),
      bitrateKbps: asInt(map['bitrate_kbps'], 320),
      sampleRateHz: asInt(map['sample_rate_hz'], 48000),
      channels: asInt(map['channels'], 2),
      id3Version: asString(map['id3_version']),
      embeddedCoverArt: asString(map['embedded_cover_art']),
    );
  }
}

class LibraryStats {
  const LibraryStats({
    this.totalPlaylists = 0,
    this.totalPlaylistEntries = 0,
    this.uniqueTracks = 0,
    this.downloadedUniqueTracks = 0,
  });

  final int totalPlaylists;
  final int totalPlaylistEntries;
  final int uniqueTracks;
  final int downloadedUniqueTracks;

  LibraryStats copyWith({
    int? totalPlaylists,
    int? totalPlaylistEntries,
    int? uniqueTracks,
    int? downloadedUniqueTracks,
  }) {
    return LibraryStats(
      totalPlaylists: totalPlaylists ?? this.totalPlaylists,
      totalPlaylistEntries: totalPlaylistEntries ?? this.totalPlaylistEntries,
      uniqueTracks: uniqueTracks ?? this.uniqueTracks,
      downloadedUniqueTracks:
          downloadedUniqueTracks ?? this.downloadedUniqueTracks,
    );
  }

  factory LibraryStats.fromJson(Object? json) {
    final map = asMap(json);
    return LibraryStats(
      totalPlaylists: asInt(map['total_playlists']),
      totalPlaylistEntries: asInt(map['total_playlist_entries']),
      uniqueTracks: asInt(map['unique_tracks']),
      downloadedUniqueTracks: asInt(map['downloaded_unique_tracks']),
    );
  }
}

class PlaylistSummary {
  const PlaylistSummary({
    required this.id,
    required this.slug,
    required this.name,
    this.spotifyUrl = '',
    this.description = '',
    this.authorName = '',
    this.coverUrl,
    this.status = 'pending_browser_extraction',
    this.trackCount = 0,
    this.downloadedCount = 0,
    this.folder = '',
    this.playlistJson = '',
    this.trackIds = const [],
  });

  final String id;
  final String slug;
  final String name;
  final String spotifyUrl;
  final String description;
  final String authorName;
  final String? coverUrl;
  final String status;
  final int trackCount;
  final int downloadedCount;
  final String folder;
  final String playlistJson;
  final List<String> trackIds;

  bool get isReady => status == 'complete';

  String get statusLabel => switch (status) {
    'complete' => 'Ready',
    'downloading' => 'Syncing',
    'pending_browser_extraction' => 'Pending',
    _ => status,
  };

  factory PlaylistSummary.fromJson(Object? json) {
    final map = asMap(json);
    final ids = asStringList(map['track_ids']);
    final count = asInt(map['track_count'], ids.length);
    return PlaylistSummary(
      id: asString(map['id'], asString(map['slug'])),
      slug: asString(map['slug'], asString(map['id'])),
      name: asString(map['name'], 'Untitled playlist'),
      spotifyUrl: asString(map['spotify_url']),
      description: asString(map['description']),
      authorName: asString(map['author_name']),
      coverUrl: asStringOrNull(map['cover_url']),
      status: asString(map['status'], 'pending_browser_extraction'),
      trackCount: count,
      downloadedCount: asInt(map['downloaded_count']),
      folder: asString(map['folder']),
      playlistJson: asString(map['playlist_json']),
      trackIds: ids,
    );
  }
}

class LibraryManifest {
  const LibraryManifest({
    this.schemaVersion = '1.0.0',
    this.generatedAt = '',
    this.owner = '',
    this.audioSpec = const AudioSpec(),
    this.stats = const LibraryStats(),
    this.playlists = const [],
    this.tracks = const [],
  });

  final String schemaVersion;
  final String generatedAt;
  final String owner;
  final AudioSpec audioSpec;
  final LibraryStats stats;
  final List<PlaylistSummary> playlists;
  final List<TrackRecord> tracks;

  static LibraryManifest parse(Object? json) {
    final map = asMap(json);
    if (map['playlists'] is List && map['tracks'] is List) {
      return LibraryManifest.fromJson(map);
    }
    if (map['tracks'] is List) {
      return LibraryManifest.fromPlaylistFile(map);
    }
    throw const FormatException(
      'Unrecognized library JSON. Expected library.json or playlist.json.',
    );
  }

  factory LibraryManifest.fromJson(Map<String, Object?> json) {
    return LibraryManifest(
      schemaVersion: asString(json['schema_version'], '1.0.0'),
      generatedAt: asString(json['generated_at']),
      owner: asString(json['owner']),
      audioSpec: AudioSpec.fromJson(json['audio_spec']),
      stats: LibraryStats.fromJson(json['stats']),
      playlists: [
        for (final item in asMapList(json['playlists']))
          PlaylistSummary.fromJson(item),
      ],
      tracks: [
        for (final item in asMapList(json['tracks']))
          TrackRecord.fromJson(item),
      ],
    );
  }

  factory LibraryManifest.fromPlaylistFile(Map<String, Object?> json) {
    final tracks = [
      for (final item in asMapList(json['tracks'])) TrackRecord.fromJson(item),
    ];
    final summary = PlaylistSummary.fromJson(json);
    final ids = summary.trackIds.isNotEmpty
        ? summary.trackIds
        : [for (final track in tracks) track.id];
    return LibraryManifest(
      schemaVersion: asString(json['schema_version'], '1.0.0'),
      generatedAt: asString(json['generated_at']),
      owner: asString(json['author_name']),
      playlists: [
        PlaylistSummary(
          id: summary.id,
          slug: summary.slug,
          name: summary.name,
          spotifyUrl: summary.spotifyUrl,
          description: summary.description,
          authorName: summary.authorName,
          coverUrl: summary.coverUrl,
          status: summary.status,
          trackCount: ids.length,
          downloadedCount: summary.downloadedCount,
          folder: summary.folder,
          playlistJson: summary.playlistJson,
          trackIds: ids,
        ),
      ],
      tracks: tracks,
      stats: LibraryStats(
        totalPlaylists: 1,
        totalPlaylistEntries: ids.length,
        uniqueTracks: tracks.length,
        downloadedUniqueTracks: tracks
            .where((track) => track.downloaded)
            .length,
      ),
    );
  }

  LibraryManifest copyWith({
    List<PlaylistSummary>? playlists,
    List<TrackRecord>? tracks,
    LibraryStats? stats,
  }) {
    return LibraryManifest(
      schemaVersion: schemaVersion,
      generatedAt: generatedAt,
      owner: owner,
      audioSpec: audioSpec,
      stats: stats ?? this.stats,
      playlists: playlists ?? this.playlists,
      tracks: tracks ?? this.tracks,
    );
  }
}

LibraryManifest parseManifestString(String raw) {
  return LibraryManifest.parse(jsonDecode(raw));
}

class ArtistGroup {
  const ArtistGroup({
    required this.name,
    required this.trackCount,
    this.primaryCount = 0,
    this.albumCount = 0,
    this.coverUrl,
  });

  final String name;
  final int trackCount;
  final int primaryCount;
  final int albumCount;
  final String? coverUrl;

  /// A main artist leads at least one track, or shows up more than once.
  bool get isMain => primaryCount >= 1 || trackCount >= 2;
}

/// Album artist when it names a real person, otherwise the first credited name.
String? primaryArtistName(TrackRecord track) {
  final album = track.albumArtist.trim();
  if (album.isNotEmpty && album.toLowerCase() != 'various artists') {
    return album;
  }
  for (final name in track.artists) {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  final artist = track.artist.trim();
  if (artist.isEmpty) return null;
  final first = artist.split(',').first.trim();
  return first.isEmpty ? null : first;
}

class AlbumGroup {
  const AlbumGroup({
    required this.key,
    required this.title,
    required this.artist,
    required this.trackCount,
    this.year,
    this.coverUrl,
  });

  final String key;
  final String title;
  final String artist;
  final int? year;
  final int trackCount;
  final String? coverUrl;
}

String albumKeyFor(TrackRecord track) =>
    '${track.albumArtist}\u0000${track.album}';

enum AlbumOrder { tracks, newest, name }

class _ArtistBucket {
  int credits = 0;
  int primary = 0;
  int coverScore = -1;
  String? cover;
  final albums = <String>{};
}

class LibraryIndex {
  LibraryIndex(this.manifest)
    : byId = {for (final track in manifest.tracks) track.id: track};

  final LibraryManifest manifest;
  final Map<String, TrackRecord> byId;

  List<TrackRecord> get tracks => manifest.tracks;

  PlaylistSummary? playlistById(String id) {
    for (final playlist in manifest.playlists) {
      if (playlist.slug == id || playlist.id == id) return playlist;
    }
    return null;
  }

  List<TrackRecord> tracksFor(PlaylistSummary playlist) {
    final result = <TrackRecord>[];
    for (final id in playlist.trackIds) {
      final track = byId[id];
      if (track != null) result.add(track);
    }
    return result;
  }

  Map<String, int> positionsFor(PlaylistSummary playlist) {
    final map = <String, int>{};
    for (var i = 0; i < playlist.trackIds.length; i++) {
      map.putIfAbsent(playlist.trackIds[i], () => i + 1);
    }
    return map;
  }

  List<TrackRecord> search(String query) => filterTracks(tracks, query);

  List<TrackRecord> byArtist(String name) {
    return tracks
        .where((track) => track.artist == name || track.artists.contains(name))
        .toList();
  }

  List<TrackRecord> byAlbum(String key) {
    return tracks.where((track) => albumKeyFor(track) == key).toList();
  }

  /// Main artists, most tracks first. Featured one-offs stay out of this list.
  List<ArtistGroup> get artists => listedArtists();

  int get creditArtistCount => _artistGroups().length;

  List<ArtistGroup> listedArtists({
    bool mainOnly = true,
    bool alphabetical = false,
    String query = '',
  }) {
    final needle = query.trim().toLowerCase();
    final groups = [
      for (final group in _artistGroups())
        if ((!mainOnly || group.isMain) &&
            (needle.isEmpty || group.name.toLowerCase().contains(needle)))
          group,
    ];
    groups.sort((a, b) {
      if (!alphabetical) {
        final byCount = b.trackCount.compareTo(a.trackCount);
        if (byCount != 0) return byCount;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return groups;
  }

  List<ArtistGroup> _artistGroups() {
    final buckets = <String, _ArtistBucket>{};
    for (final track in tracks) {
      final names = <String>{
        for (final name in track.artists)
          if (name.trim().isNotEmpty) name.trim(),
      };
      final primary = primaryArtistName(track);
      if (names.isEmpty && primary != null) names.add(primary);
      for (final name in names) {
        final bucket = buckets.putIfAbsent(name, _ArtistBucket.new);
        bucket.credits++;
        if (name == primary) bucket.primary++;
        if (track.album.trim().isNotEmpty) {
          bucket.albums.add(albumKeyFor(track));
        }
        final cover = track.coverUrl;
        if (cover == null || cover.isEmpty) continue;
        final score = (name == primary ? 100000 : 0) + track.popularity;
        if (score >= bucket.coverScore) {
          bucket.coverScore = score;
          bucket.cover = cover;
        }
      }
    }
    return [
      for (final entry in buckets.entries)
        ArtistGroup(
          name: entry.key,
          trackCount: entry.value.credits,
          primaryCount: entry.value.primary,
          albumCount: entry.value.albums.length,
          coverUrl: entry.value.cover,
        ),
    ];
  }

  List<AlbumGroup> get albums => listedAlbums();

  List<AlbumGroup> listedAlbums({
    AlbumOrder order = AlbumOrder.tracks,
    String query = '',
  }) {
    final grouped = <String, List<TrackRecord>>{};
    for (final track in tracks) {
      if (track.album.trim().isEmpty) continue;
      grouped.putIfAbsent(albumKeyFor(track), () => []).add(track);
    }
    final needle = query.trim().toLowerCase();
    final groups = <AlbumGroup>[];
    for (final entry in grouped.entries) {
      final sample = entry.value.first;
      final artist = sample.albumArtist.isEmpty
          ? sample.artist
          : sample.albumArtist;
      if (needle.isNotEmpty &&
          !sample.album.toLowerCase().contains(needle) &&
          !artist.toLowerCase().contains(needle)) {
        continue;
      }
      int? year;
      String? cover;
      var coverScore = -1;
      for (final track in entry.value) {
        final nextYear = track.year;
        if (nextYear != null && (year == null || nextYear > year)) {
          year = nextYear;
        }
        final art = track.coverUrl;
        if (art == null || art.isEmpty) continue;
        if (track.popularity >= coverScore) {
          coverScore = track.popularity;
          cover = art;
        }
      }
      groups.add(
        AlbumGroup(
          key: entry.key,
          title: sample.album,
          artist: artist,
          year: year,
          trackCount: entry.value.length,
          coverUrl: cover ?? sample.coverUrl,
        ),
      );
    }
    groups.sort((a, b) {
      switch (order) {
        case AlbumOrder.tracks:
          final byCount = b.trackCount.compareTo(a.trackCount);
          if (byCount != 0) return byCount;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case AlbumOrder.newest:
          final ay = a.year ?? -1;
          final by = b.year ?? -1;
          final byYear = by.compareTo(ay);
          if (byYear != 0) return byYear;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case AlbumOrder.name:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
    });
    return groups;
  }

  LibraryIndex merge(LibraryManifest extra) {
    final mergedById = {for (final track in manifest.tracks) track.id: track};
    for (final track in extra.tracks) {
      mergedById[track.id] = track;
    }
    final playlists = [...manifest.playlists];
    for (final playlist in extra.playlists) {
      final index = playlists.indexWhere((item) => item.slug == playlist.slug);
      if (index >= 0) {
        playlists[index] = playlist;
      } else {
        playlists.add(playlist);
      }
    }
    final mergedTracks = mergedById.values.toList();
    return LibraryIndex(
      manifest.copyWith(
        playlists: playlists,
        tracks: mergedTracks,
        stats: manifest.stats.copyWith(
          totalPlaylists: playlists.length,
          uniqueTracks: mergedTracks.length,
          totalPlaylistEntries: playlists.fold<int>(
            0,
            (sum, playlist) => sum + playlist.trackIds.length,
          ),
        ),
      ),
    );
  }
}
