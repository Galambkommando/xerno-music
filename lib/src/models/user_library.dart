import '../constants.dart';
import '../format.dart';
import 'json_util.dart';

class PlaybackBookmark {
  const PlaybackBookmark({
    this.trackId,
    this.positionMs = 0,
    this.queueIds = const [],
    this.index = 0,
    this.shuffle = false,
    this.repeat = 'off',
    this.contextLabel,
  });

  final String? trackId;
  final int positionMs;
  final List<String> queueIds;
  final int index;
  final bool shuffle;
  final String repeat;
  final String? contextLabel;

  bool get isEmpty => queueIds.isEmpty && (trackId == null || trackId!.isEmpty);

  Map<String, Object?> toJson() => {
    'track_id': trackId,
    'position_ms': positionMs,
    'queue_ids': queueIds,
    'queue_index': index,
    'shuffle': shuffle,
    'repeat': repeat,
    'context_label': contextLabel,
  };

  factory PlaybackBookmark.fromJson(Object? json) {
    final map = asMap(json);
    return PlaybackBookmark(
      trackId: asStringOrNull(map['track_id']),
      positionMs: asInt(map['position_ms']),
      queueIds: asStringList(map['queue_ids']),
      index: asInt(map['queue_index']),
      shuffle: asBool(map['shuffle']),
      repeat: asString(map['repeat'], 'off'),
      contextLabel: asStringOrNull(map['context_label']),
    );
  }
}

class UserPlaylist {
  const UserPlaylist({
    required this.id,
    required this.name,
    required this.trackIds,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final List<String> trackIds;
  final String createdAt;
  final String updatedAt;

  UserPlaylist copyWith({
    String? name,
    List<String>? trackIds,
    String? updatedAt,
  }) {
    return UserPlaylist(
      id: id,
      name: name ?? this.name,
      trackIds: trackIds ?? this.trackIds,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'track_ids': trackIds,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  factory UserPlaylist.fromJson(Object? json) {
    final map = asMap(json);
    final now = nowIso();
    return UserPlaylist(
      id: asString(map['id'], newPlaylistId()),
      name: asString(map['name'], 'Untitled'),
      trackIds: asStringList(map['track_ids']),
      createdAt: asString(map['created_at'], now),
      updatedAt: asString(map['updated_at'], now),
    );
  }
}

class UserLibraryData {
  const UserLibraryData({
    this.favorites = const [],
    this.playlists = const [],
    this.bookmark,
    this.libraryUpdatedAt = '',
    this.playbackUpdatedAt = '',
  });

  final List<String> favorites;
  final List<UserPlaylist> playlists;
  final PlaybackBookmark? bookmark;
  final String libraryUpdatedAt;
  final String playbackUpdatedAt;

  static UserLibraryData empty() => UserLibraryData(
    libraryUpdatedAt: epochIso(),
    playbackUpdatedAt: epochIso(),
  );

  bool isFavorite(String id) => favorites.contains(id);

  UserLibraryData copyWith({
    List<String>? favorites,
    List<UserPlaylist>? playlists,
    PlaybackBookmark? bookmark,
    bool clearBookmark = false,
    String? libraryUpdatedAt,
    String? playbackUpdatedAt,
  }) {
    return UserLibraryData(
      favorites: favorites ?? this.favorites,
      playlists: playlists ?? this.playlists,
      bookmark: clearBookmark ? null : (bookmark ?? this.bookmark),
      libraryUpdatedAt: libraryUpdatedAt ?? this.libraryUpdatedAt,
      playbackUpdatedAt: playbackUpdatedAt ?? this.playbackUpdatedAt,
    );
  }

  UserLibraryData toggleFavorite(String id) {
    final next = [...favorites];
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    return copyWith(favorites: next, libraryUpdatedAt: nowIso());
  }

  UserLibraryData addPlaylist(String name) {
    final stamp = nowIso();
    final playlist = UserPlaylist(
      id: newPlaylistId(),
      name: name.trim().isEmpty ? 'Untitled' : name.trim(),
      trackIds: const [],
      createdAt: stamp,
      updatedAt: stamp,
    );
    return copyWith(
      playlists: [...playlists, playlist],
      libraryUpdatedAt: stamp,
    );
  }

  UserLibraryData renamePlaylist(String id, String name) {
    final stamp = nowIso();
    return copyWith(
      playlists: [
        for (final playlist in playlists)
          if (playlist.id == id)
            playlist.copyWith(name: name.trim(), updatedAt: stamp)
          else
            playlist,
      ],
      libraryUpdatedAt: stamp,
    );
  }

  UserLibraryData deletePlaylist(String id) {
    return copyWith(
      playlists: playlists.where((playlist) => playlist.id != id).toList(),
      libraryUpdatedAt: nowIso(),
    );
  }

  UserLibraryData reorderPlaylists(int from, int to) {
    if (from < 0 ||
        to < 0 ||
        from >= playlists.length ||
        to >= playlists.length ||
        from == to) {
      return this;
    }
    final next = [...playlists];
    final item = next.removeAt(from);
    next.insert(to, item);
    return copyWith(playlists: next, libraryUpdatedAt: nowIso());
  }

  UserLibraryData addTrack(String playlistId, String trackId) {
    final stamp = nowIso();
    return copyWith(
      playlists: [
        for (final playlist in playlists)
          if (playlist.id == playlistId && !playlist.trackIds.contains(trackId))
            playlist.copyWith(
              trackIds: [...playlist.trackIds, trackId],
              updatedAt: stamp,
            )
          else
            playlist,
      ],
      libraryUpdatedAt: stamp,
    );
  }

  UserLibraryData removeTrack(String playlistId, int index) {
    final stamp = nowIso();
    return copyWith(
      playlists: [
        for (final playlist in playlists)
          if (playlist.id == playlistId &&
              index >= 0 &&
              index < playlist.trackIds.length)
            playlist.copyWith(
              trackIds: [...playlist.trackIds]..removeAt(index),
              updatedAt: stamp,
            )
          else
            playlist,
      ],
      libraryUpdatedAt: stamp,
    );
  }

  UserLibraryData reorderTracks(String playlistId, int from, int to) {
    final stamp = nowIso();
    return copyWith(
      playlists: [
        for (final playlist in playlists)
          if (playlist.id == playlistId)
            playlist.copyWith(
              trackIds: _moved(playlist.trackIds, from, to),
              updatedAt: stamp,
            )
          else
            playlist,
      ],
      libraryUpdatedAt: stamp,
    );
  }

  UserLibraryData withBookmark(PlaybackBookmark bookmark) {
    return copyWith(bookmark: bookmark, playbackUpdatedAt: nowIso());
  }

  Map<String, Object?> toExport() => {
    'schema': kUserLibrarySchema,
    'exported_at': nowIso(),
    'library_updated_at': libraryUpdatedAt,
    'favorites': favorites,
    'playlists': [for (final playlist in playlists) playlist.toJson()],
  };

  Map<String, Object?> toJson() => {
    'schema': kUserLibrarySchema,
    'library_updated_at': libraryUpdatedAt,
    'playback_updated_at': playbackUpdatedAt,
    'favorites': favorites,
    'playlists': [for (final playlist in playlists) playlist.toJson()],
    'bookmark': bookmark?.toJson(),
  };

  factory UserLibraryData.fromJson(Object? json) {
    final map = asMap(json);
    final bookmarkRaw = map['bookmark'];
    return UserLibraryData(
      favorites: asStringList(map['favorites']),
      playlists: [
        for (final item in asMapList(map['playlists']))
          UserPlaylist.fromJson(item),
      ],
      bookmark: bookmarkRaw == null
          ? null
          : PlaybackBookmark.fromJson(bookmarkRaw),
      libraryUpdatedAt: asString(map['library_updated_at'], epochIso()),
      playbackUpdatedAt: asString(map['playback_updated_at'], epochIso()),
    );
  }

  factory UserLibraryData.fromExport(Object? json) {
    final map = asMap(json);
    return UserLibraryData(
      favorites: asStringList(map['favorites']),
      playlists: [
        for (final item in asMapList(map['playlists']))
          UserPlaylist.fromJson(item),
      ],
      libraryUpdatedAt: asString(map['library_updated_at'], nowIso()),
      playbackUpdatedAt: epochIso(),
    );
  }
}

List<String> _moved(List<String> ids, int from, int to) {
  if (from < 0 ||
      to < 0 ||
      from >= ids.length ||
      to >= ids.length ||
      from == to) {
    return ids;
  }
  final next = [...ids];
  final item = next.removeAt(from);
  next.insert(to, item);
  return next;
}

UserLibraryData mergeUserLibraries(
  UserLibraryData local,
  UserLibraryData incoming, {
  required bool replace,
}) {
  if (replace) {
    return local.copyWith(
      favorites: incoming.favorites,
      playlists: incoming.playlists,
      libraryUpdatedAt: nowIso(),
    );
  }
  final favorites = [...local.favorites];
  for (final id in incoming.favorites) {
    if (!favorites.contains(id)) favorites.add(id);
  }
  final playlists = [...local.playlists];
  for (final playlist in incoming.playlists) {
    final index = playlists.indexWhere(
      (item) => item.id == playlist.id || item.name == playlist.name,
    );
    if (index < 0) {
      playlists.add(playlist);
      continue;
    }
    final existing = playlists[index];
    final ids = [...existing.trackIds];
    for (final id in playlist.trackIds) {
      if (!ids.contains(id)) ids.add(id);
    }
    playlists[index] = existing.copyWith(trackIds: ids, updatedAt: nowIso());
  }
  return local.copyWith(
    favorites: favorites,
    playlists: playlists,
    libraryUpdatedAt: nowIso(),
  );
}
