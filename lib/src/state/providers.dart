import 'dart:async';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../logic/lrc.dart';
import '../logic/play_queue.dart';
import '../logic/source_resolver.dart';
import '../models/library.dart';
import '../models/settings.dart';
import '../models/sync.dart';
import '../models/user_library.dart';
import '../player/playback.dart';
import '../services/download_manager.dart';
import '../services/http_get.dart';
import '../services/library_repository.dart';
import '../services/lyrics_client.dart';
import '../services/settings_store.dart';
import '../services/sync_client.dart';
import '../services/user_library_store.dart';

final initialSettingsProvider = Provider<AppSettings>(
  (ref) => AppSettings.defaults(),
);

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(initialSettingsProvider);

  Future<void> update(AppSettings Function(AppSettings current) edit) async {
    final next = edit(state);
    state = next;
    try {
      await SettingsStore.save(next);
    } catch (error, stack) {
      log('Could not save settings.', error: error, stackTrace: stack);
    }
  }
}

final librarySeedProvider = Provider<LibraryIndex?>((ref) => null);

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepository(),
);

final libraryProvider = AsyncNotifierProvider<LibraryController, LibraryIndex>(
  LibraryController.new,
);

class LibraryController extends AsyncNotifier<LibraryIndex> {
  @override
  Future<LibraryIndex> build() async {
    final seed = ref.watch(librarySeedProvider);
    if (seed != null) return seed;
    final settings = ref.read(settingsProvider);
    final repository = ref.read(libraryRepositoryProvider);
    final initial = await repository.load(settings);
    final url = settings.manifestUrl.trim();
    if (url.isNotEmpty && settings.localLibraryPath.trim().isEmpty) {
      unawaited(_refreshQuiet(url));
    }
    return initial;
  }

  Future<void> _refreshQuiet(String url) async {
    try {
      final index = await ref.read(libraryRepositoryProvider).download(url);
      state = AsyncData(index);
    } catch (error, stack) {
      log(
        'Background manifest refresh failed.',
        error: error,
        stackTrace: stack,
      );
    }
  }

  Future<String?> refreshCloud() async {
    final url = ref.read(settingsProvider).manifestUrl.trim();
    if (url.isEmpty) return 'Add a cloud manifest URL first.';
    final previous = state.valueOrNull;
    try {
      final index = await ref.read(libraryRepositoryProvider).download(url);
      state = AsyncData(index);
      return null;
    } catch (error) {
      if (previous != null) state = AsyncData(previous);
      return 'Could not refresh the manifest. $error';
    }
  }

  Future<String?> reloadLocal() async {
    final path = ref.read(settingsProvider).localLibraryPath.trim();
    if (path.isEmpty) return 'Choose a local library folder first.';
    final previous = state.valueOrNull;
    try {
      final index = await ref.read(libraryRepositoryProvider).loadLocal(path);
      state = AsyncData(index);
      return null;
    } catch (error) {
      if (previous != null) state = AsyncData(previous);
      return 'Could not read library.json from that folder. $error';
    }
  }

  Future<void> useBundled() async {
    final index = await ref.read(libraryRepositoryProvider).loadBundled();
    state = AsyncData(index);
  }

  Future<String?> importJson(String raw) async {
    final current = state.valueOrNull;
    if (current == null) return 'The library is still opening.';
    try {
      final extra = parseManifestString(raw);
      state = AsyncData(current.merge(extra));
      return null;
    } catch (error) {
      return 'That file is not a library.json or playlist.json. $error';
    }
  }
}

final userLibraryProvider =
    AsyncNotifierProvider<UserLibraryController, UserLibraryData>(
      UserLibraryController.new,
    );

class UserLibraryController extends AsyncNotifier<UserLibraryData> {
  @override
  Future<UserLibraryData> build() async {
    try {
      final directory = await getApplicationSupportDirectory();
      return await UserLibraryStore(directory).load();
    } catch (error, stack) {
      log('User library could not be loaded.', error: error, stackTrace: stack);
      return UserLibraryData.empty();
    }
  }

  Future<void> _commit(UserLibraryData next) async {
    state = AsyncData(next);
    try {
      final directory = await getApplicationSupportDirectory();
      await UserLibraryStore(directory).save(next);
    } catch (error, stack) {
      log('User library could not be saved.', error: error, stackTrace: stack);
    }
  }

  Future<void> mutate(
    UserLibraryData Function(UserLibraryData current) edit,
  ) async {
    final current = state.valueOrNull ?? UserLibraryData.empty();
    await _commit(edit(current));
  }

  Future<void> saveBookmark(PlaybackBookmark bookmark) async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (current.bookmark?.trackId == bookmark.trackId &&
        current.bookmark?.index == bookmark.index &&
        (current.bookmark?.positionMs ?? 0) ~/ 2000 ==
            bookmark.positionMs ~/ 2000 &&
        _sameIds(current.bookmark?.queueIds, bookmark.queueIds)) {
      return;
    }
    await _commit(current.withBookmark(bookmark));
  }

  Future<void> applyRemote(SyncPayload remote, {bool force = false}) async {
    final current = state.valueOrNull ?? UserLibraryData.empty();
    var next = current;
    if (force ||
        isNewerStamp(remote.libraryUpdatedAt, current.libraryUpdatedAt)) {
      next = next.copyWith(
        favorites: remote.favorites,
        playlists: remote.playlists,
        libraryUpdatedAt: remote.libraryUpdatedAt,
      );
    }
    if (force ||
        isNewerStamp(remote.playbackUpdatedAt, current.playbackUpdatedAt)) {
      next = next.copyWith(
        bookmark: remote.bookmark,
        clearBookmark: remote.bookmark == null,
        playbackUpdatedAt: remote.playbackUpdatedAt,
      );
    }
    await _commit(next);
  }
}

bool _sameIds(List<String>? a, List<String> b) {
  if (a == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

final playerProvider = Provider<PlaybackPort>((ref) {
  throw StateError('Playback was not started.');
});

final playerSnapshotProvider = StreamProvider<PlayerSnapshot>((ref) {
  final player = ref.watch(playerProvider);
  return Stream<PlayerSnapshot>.multi((listener) {
    listener.add(player.snapshot);
    final subscription = player.snapshots.listen(
      listener.add,
      onError: listener.addError,
      onDone: listener.close,
    );
    listener.onCancel = subscription.cancel;
  });
});

PlayerSnapshot watchSnapshot(WidgetRef ref) {
  return ref.watch(playerSnapshotProvider).valueOrNull ??
      ref.read(playerProvider).snapshot;
}

/// Cover used behind the shell. Selects the art string so position ticks
/// do not rebuild the whole window.
final ambientCoverProvider = Provider<String?>((ref) {
  final art = ref.watch(
    playerSnapshotProvider.select((value) {
      final uri = value.valueOrNull?.track?.artUri?.toString();
      if (uri == null || uri.isEmpty) return null;
      return uri;
    }),
  );
  if (art != null) return art;
  final playlists = ref.watch(
    libraryProvider.select((value) => value.valueOrNull?.manifest.playlists),
  );
  if (playlists == null) return null;
  for (final playlist in playlists) {
    final cover = playlist.coverUrl;
    if (cover != null && cover.isNotEmpty) return cover;
  }
  return null;
});

final downloadManagerProvider = ChangeNotifierProvider<DownloadManager>((ref) {
  return DownloadManager();
});

final sourceResolverProvider = Provider<SourceResolver>(
  (ref) => const SourceResolver(),
);

final lyricsClientProvider = Provider<LyricsClient>(
  (ref) => LyricsClient(IoHttpGet()),
);

final lyricsProvider = FutureProvider.family<Lyrics, String>((
  ref,
  trackId,
) async {
  final catalog = await ref.watch(libraryProvider.future);
  final track = catalog.byId[trackId];
  if (track == null) return Lyrics.empty;
  return ref
      .read(lyricsClientProvider)
      .fetch(
        trackId: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
        durationSec: track.durationSec,
      );
});

final syncClientProvider = Provider<SyncClient>((ref) => SyncClient());

final syncStatusProvider = StateProvider<String>((ref) => '');

enum ShellSection {
  home,
  search,
  songs,
  artists,
  albums,
  downloads,
  settings,
  favorites,
  playlist,
}

class NavState {
  const NavState({
    this.section = ShellSection.home,
    this.playlistId,
    this.customPlaylist = false,
    this.artist,
    this.albumKey,
    this.query = '',
  });

  final ShellSection section;
  final String? playlistId;
  final bool customPlaylist;
  final String? artist;
  final String? albumKey;
  final String query;
}

final navProvider = NotifierProvider<NavController, NavState>(
  NavController.new,
);

class NavController extends Notifier<NavState> {
  @override
  NavState build() => const NavState();

  void go(ShellSection section) => state = NavState(section: section);

  void search(String query) =>
      state = NavState(section: ShellSection.search, query: query);

  void openPlaylist(String id, {bool custom = false}) {
    state = NavState(
      section: ShellSection.playlist,
      playlistId: id,
      customPlaylist: custom,
    );
  }

  void openArtist(String name) =>
      state = NavState(section: ShellSection.artists, artist: name);

  void openAlbum(String key) =>
      state = NavState(section: ShellSection.albums, albumKey: key);
}

RepeatMode repeatFromBookmark(String name) => repeatModeFromName(name);
