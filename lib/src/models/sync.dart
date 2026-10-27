import '../constants.dart';
import '../format.dart';
import 'json_util.dart';
import 'user_library.dart';

class SyncPayload {
  const SyncPayload({
    required this.deviceId,
    required this.libraryUpdatedAt,
    required this.playbackUpdatedAt,
    this.favorites = const [],
    this.playlists = const [],
    this.bookmark,
  });

  final String deviceId;
  final String libraryUpdatedAt;
  final String playbackUpdatedAt;
  final List<String> favorites;
  final List<UserPlaylist> playlists;
  final PlaybackBookmark? bookmark;

  factory SyncPayload.fromLibrary(UserLibraryData data, String deviceId) {
    return SyncPayload(
      deviceId: deviceId,
      libraryUpdatedAt: data.libraryUpdatedAt,
      playbackUpdatedAt: data.playbackUpdatedAt,
      favorites: data.favorites,
      playlists: data.playlists,
      bookmark: data.bookmark,
    );
  }

  Map<String, Object?> toJson() => {
    'schema': kSyncSchema,
    'device_id': deviceId,
    'library_updated_at': libraryUpdatedAt,
    'playback_updated_at': playbackUpdatedAt,
    'favorites': favorites,
    'playlists': [for (final playlist in playlists) playlist.toJson()],
    'playback': bookmark?.toJson(),
  };

  factory SyncPayload.fromJson(Object? json) {
    final map = asMap(json);
    final playback = map['playback'];
    return SyncPayload(
      deviceId: asString(map['device_id']),
      libraryUpdatedAt: asString(map['library_updated_at'], epochIso()),
      playbackUpdatedAt: asString(map['playback_updated_at'], epochIso()),
      favorites: asStringList(map['favorites']),
      playlists: [
        for (final item in asMapList(map['playlists']))
          UserPlaylist.fromJson(item),
      ],
      bookmark: playback == null ? null : PlaybackBookmark.fromJson(playback),
    );
  }
}

bool isNewerStamp(String remote, String local) => remote.compareTo(local) > 0;
