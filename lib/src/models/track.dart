import 'json_util.dart';

class AudioQuality {
  const AudioQuality({
    this.format = 'mp3',
    this.codec = 'mp3',
    this.bitrateKbps = 320,
    this.sampleRateHz = 48000,
    this.channels = 2,
    this.durationSec = 0,
    this.filesizeBytes = 0,
    this.hasCoverArt = false,
  });

  final String format;
  final String codec;
  final int bitrateKbps;
  final int sampleRateHz;
  final int channels;
  final double durationSec;
  final int filesizeBytes;
  final bool hasCoverArt;

  factory AudioQuality.fromJson(Object? json) {
    final map = asMap(json);
    return AudioQuality(
      format: asString(map['format'], 'mp3'),
      codec: asString(map['codec'], 'mp3'),
      bitrateKbps: asInt(map['bitrate_kbps'], 320),
      sampleRateHz: asInt(map['sample_rate_hz'], 48000),
      channels: asInt(map['channels'], 2),
      durationSec: asDouble(map['duration_sec']),
      filesizeBytes: asInt(map['filesize_bytes']),
      hasCoverArt: asBool(map['has_cover_art']),
    );
  }
}

class TrackFile {
  const TrackFile({
    this.playlistSlug = '',
    this.playlistName = '',
    this.position = 0,
    this.filename = '',
    this.localPath = '',
    this.relativePath = '',
    this.ziplineUrl,
  });

  final String playlistSlug;
  final String playlistName;
  final int position;
  final String filename;
  final String localPath;
  final String relativePath;
  final String? ziplineUrl;

  factory TrackFile.fromJson(Object? json) {
    final map = asMap(json);
    return TrackFile(
      playlistSlug: asString(map['playlist_slug']),
      playlistName: asString(map['playlist_name']),
      position: asInt(map['position']),
      filename: asString(map['filename']),
      localPath: asString(map['local_path']),
      relativePath: asString(map['relative_path']),
      ziplineUrl: asStringOrNull(map['zipline_url']),
    );
  }
}

class TrackAppearance {
  const TrackAppearance({
    required this.id,
    required this.name,
    required this.position,
    this.relativePath = '',
    this.filename = '',
    this.ziplineUrl,
  });

  final String id;
  final String name;
  final int position;
  final String relativePath;
  final String filename;
  final String? ziplineUrl;

  factory TrackAppearance.fromJson(Object? json) {
    final map = asMap(json);
    return TrackAppearance(
      id: asString(map['id']),
      name: asString(map['name']),
      position: asInt(map['position']),
      relativePath: asString(map['relative_path']),
      filename: asString(map['filename']),
      ziplineUrl: asStringOrNull(map['zipline_url']),
    );
  }
}

class TrackRecord {
  const TrackRecord({
    required this.id,
    required this.title,
    required this.artist,
    this.spotifyUrl = '',
    this.spotifyUri = '',
    this.artists = const [],
    this.artistId,
    this.album = '',
    this.albumId,
    this.albumArtist = '',
    this.albumType = '',
    this.releaseDate,
    this.year,
    this.trackNumber = 0,
    this.tracksCount = 0,
    this.discNumber = 1,
    this.durationSec = 0,
    this.durationFormatted = '0:00',
    this.explicit = false,
    this.popularity = 0,
    this.publisher = '',
    this.isrc = '',
    this.coverUrl,
    this.downloaded = false,
    this.audioQuality = const AudioQuality(),
    this.file = const TrackFile(),
    this.appearances = const [],
  });

  final String id;
  final String spotifyUrl;
  final String spotifyUri;
  final String title;
  final String artist;
  final List<String> artists;
  final String? artistId;
  final String album;
  final String? albumId;
  final String albumArtist;
  final String albumType;
  final String? releaseDate;
  final int? year;
  final int trackNumber;
  final int tracksCount;
  final int discNumber;
  final int durationSec;
  final String durationFormatted;
  final bool explicit;
  final int popularity;
  final String publisher;
  final String isrc;
  final String? coverUrl;
  final bool downloaded;
  final AudioQuality audioQuality;
  final TrackFile file;
  final List<TrackAppearance> appearances;

  String get displayArtist {
    if (artists.isNotEmpty) return artists.join(', ');
    return artist;
  }

  factory TrackRecord.fromJson(Object? json) {
    final map = asMap(json);
    final duration = asInt(map['duration_sec']);
    final formatted = asString(map['duration_formatted']);
    return TrackRecord(
      id: asString(map['id']),
      spotifyUrl: asString(map['spotify_url']),
      spotifyUri: asString(map['spotify_uri']),
      title: asString(map['title'], 'Untitled'),
      artist: asString(map['artist'], 'Unknown artist'),
      artists: asStringList(map['artists']),
      artistId: asStringOrNull(map['artist_id']),
      album: asString(map['album']),
      albumId: asStringOrNull(map['album_id']),
      albumArtist: asString(map['album_artist']),
      albumType: asString(map['album_type']),
      releaseDate: asStringOrNull(map['release_date']),
      year: asIntOrNull(map['year']),
      trackNumber: asInt(map['track_number']),
      tracksCount: asInt(map['tracks_count']),
      discNumber: asInt(map['disc_number'], 1),
      durationSec: duration,
      durationFormatted: formatted.isEmpty ? _format(duration) : formatted,
      explicit: asBool(map['explicit']),
      popularity: asInt(map['popularity']),
      publisher: asString(map['publisher']),
      isrc: asString(map['isrc']),
      coverUrl: asStringOrNull(map['cover_url']),
      downloaded: asBool(map['downloaded']),
      audioQuality: AudioQuality.fromJson(map['audio_quality']),
      file: TrackFile.fromJson(map['file']),
      appearances: [
        for (final item in asMapList(map['playlists']))
          TrackAppearance.fromJson(item),
      ],
    );
  }

  static String _format(int seconds) {
    final minutes = seconds ~/ 60;
    final remain = seconds % 60;
    return '$minutes:${remain.toString().padLeft(2, '0')}';
  }
}
