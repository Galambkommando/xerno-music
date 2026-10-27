import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../format.dart';
import '../models/library.dart';
import '../models/settings.dart';
import '../models/sync.dart';
import '../player/desktop_window.dart';
import '../player/playback.dart';
import '../services/supabase_gate.dart';
import '../services/sync_realtime.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import 'downloads_screen.dart';
import 'home_screen.dart';
import 'library_views.dart';
import 'now_playing.dart';
import 'playback_actions.dart';
import 'playlist_io.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'sync_actions.dart';
import 'widgets.dart';

class XernoShell extends ConsumerStatefulWidget {
  const XernoShell({super.key});

  @override
  ConsumerState<XernoShell> createState() => _XernoShellState();
}

class _XernoShellState extends ConsumerState<XernoShell> {
  final _realtime = SyncRealtime();
  StreamSubscription<PlayerSnapshot>? _snapshots;
  Timer? _pushTimer;
  var _restored = false;
  var _readyForPush = false;
  var _suppressPush = false;
  var _booted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_boot()));
  }

  Future<void> _boot() async {
    if (_booted) return;
    _booted = true;
    final settings = ref.read(settingsProvider);
    await DesktopWindow.setMini(settings.miniPlayer);
    final player = ref.read(playerProvider);
    _snapshots = player.snapshots.listen((snapshot) {
      final bookmark = snapshot.toBookmark();
      if (bookmark.isEmpty) return;
      unawaited(ref.read(userLibraryProvider.notifier).saveBookmark(bookmark));
    });
    _suppressPush = true;
    try {
      await _bindLive(settings);
    } finally {
      _suppressPush = false;
      _readyForPush = true;
    }
    await _maybeRestore();
  }

  Future<void> _bindLive(AppSettings settings) async {
    await _realtime.stop();
    if (!settings.liveSync) return;
    final error = await SupabaseGate.ensure(settings);
    if (error != null) {
      ref.read(syncStatusProvider.notifier).state = error;
      return;
    }
    if (settings.syncRoomCode.trim().isNotEmpty) {
      await pullRoomNow(ref, force: false);
      final code = normalizeRoomCode(settings.syncRoomCode);
      await _realtime.listenRoom(code, (payload) {
        unawaited(_onRemote(payload));
      });
      return;
    }
    final userId = SupabaseGate.currentUserId();
    if (userId == null) return;
    await pullAccountNow(ref, force: false);
    await _realtime.listenAccount(userId, (payload) {
      unawaited(_onRemote(payload));
    });
  }

  Future<void> _onRemote(SyncPayload payload) async {
    if (!mounted) return;
    if (payload.deviceId == ref.read(settingsProvider).deviceId) return;
    _suppressPush = true;
    try {
      await applyPulled(ref, payload, force: false);
    } finally {
      _suppressPush = false;
    }
  }

  void _schedulePush() {
    if (!_readyForPush || _suppressPush) return;
    if (!ref.read(settingsProvider).liveSync) return;
    _pushTimer?.cancel();
    _pushTimer = Timer(const Duration(seconds: 3), () {
      unawaited(_pushLive());
    });
  }

  Future<void> _pushLive() async {
    final error = await pushCurrent(ref);
    if (error != null) {
      ref.read(syncStatusProvider.notifier).state = error;
    }
  }

  Future<void> _maybeRestore() async {
    if (_restored) return;
    final settings = ref.read(settingsProvider);
    if (!settings.resumeOnLaunch) {
      _restored = true;
      return;
    }
    final catalog = ref.read(libraryProvider).valueOrNull;
    final user = ref.read(userLibraryProvider).valueOrNull;
    if (catalog == null || user == null) return;
    _restored = true;
    final bookmark = user.bookmark;
    if (bookmark == null || bookmark.isEmpty) return;
    if (ref.read(playerProvider).snapshot.hasTrack) return;
    await restoreBookmark(ref, bookmark, autoplay: false);
  }

  @override
  void dispose() {
    _pushTimer?.cancel();
    unawaited(_snapshots?.cancel());
    unawaited(_realtime.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final nav = ref.watch(navProvider);
    final library = ref.watch(libraryProvider);
    ref.listen(settingsProvider, (previous, next) {
      if (previous?.miniPlayer != next.miniPlayer) {
        unawaited(DesktopWindow.setMini(next.miniPlayer));
      }
      final liveChanged =
          previous?.liveSync != next.liveSync ||
          previous?.syncRoomCode != next.syncRoomCode ||
          previous?.supabaseUrl != next.supabaseUrl ||
          previous?.restSyncBaseUrl != next.restSyncBaseUrl;
      if (liveChanged) unawaited(_rebind(next));
    });
    ref.listen(userLibraryProvider, (previous, next) {
      unawaited(_maybeRestore());
      if (next.hasValue) _schedulePush();
    });
    ref.listen(libraryProvider, (previous, next) {
      if (next.hasValue) unawaited(_maybeRestore());
    });

    final wide = MediaQuery.sizeOf(context).width >= 900;
    final page = _page(library, nav);
    final cover = ref.watch(ambientCoverProvider);
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.space): _ToggleIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _ExpandIntent(),
        SingleActivator(LogicalKeyboardKey.arrowRight, control: true):
            _NextIntent(),
        SingleActivator(LogicalKeyboardKey.arrowLeft, control: true):
            _PreviousIntent(),
      },
      child: Actions(
        actions: {
          _ToggleIntent: CallbackAction<_ToggleIntent>(
            onInvoke: (_) {
              if (_typing()) return null;
              unawaited(ref.read(playerProvider).toggle());
              return null;
            },
          ),
          _ExpandIntent: CallbackAction<_ExpandIntent>(
            onInvoke: (_) {
              if (_typing()) return null;
              if (!ref.read(settingsProvider).miniPlayer) return null;
              unawaited(setMiniPlayer(ref, false));
              return null;
            },
          ),
          _NextIntent: CallbackAction<_NextIntent>(
            onInvoke: (_) {
              unawaited(ref.read(playerProvider).next());
              return null;
            },
          ),
          _PreviousIntent: CallbackAction<_PreviousIntent>(
            onInvoke: (_) {
              unawaited(ref.read(playerProvider).previous());
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: AmbientBackdrop(
            enabled: settings.ambientGlow,
            coverUrl: cover,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  const KeptIconGlyphs(),
                  settings.miniPlayer
                      ? const MiniPlayerView()
                      : wide
                      ? Row(
                          children: [
                            const _Sidebar(),
                            Expanded(child: _Stage(page: page)),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(child: _Stage(page: page)),
                            const _MobileNav(),
                          ],
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _rebind(AppSettings settings) async {
    _suppressPush = true;
    try {
      await _bindLive(settings);
    } finally {
      _suppressPush = false;
    }
  }

  Widget _page(AsyncValue<LibraryIndex> library, NavState nav) {
    return switch (nav.section) {
      ShellSection.settings => const SettingsScreen(),
      ShellSection.downloads => const DownloadsScreen(),
      _ => library.when(
        data: (catalog) => switch (nav.section) {
          ShellSection.home => HomeScreen(catalog: catalog),
          ShellSection.search => SearchScreen(catalog: catalog),
          _ => LibraryViews(catalog: catalog),
        },
        loading: () => const Center(child: Text('Opening the library')),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'The library could not be opened.\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    };
  }
}

bool _typing() {
  final widget = FocusManager.instance.primaryFocus?.context?.widget;
  return widget is EditableText;
}

class _Stage extends StatelessWidget {
  const _Stage({required this.page});

  final Widget page;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const PlaybackFailureBanner(),
        const _TopBar(),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: page),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: NowPlayingSlot(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      settingsProvider.select((settings) => settings.miniPlayer),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          const Spacer(),
          GlassIconButton(
            tooltip: enabled ? 'Exit mini player' : 'Mini player',
            icon: Icons.picture_in_picture_alt_rounded,
            active: enabled,
            onPressed: () => unawaited(setMiniPlayer(ref, !enabled)),
          ),
        ],
      ),
    );
  }
}

class _ToggleIntent extends Intent {
  const _ToggleIntent();
}

class _ExpandIntent extends Intent {
  const _ExpandIntent();
}

class _NextIntent extends Intent {
  const _NextIntent();
}

class _PreviousIntent extends Intent {
  const _PreviousIntent();
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nav = ref.watch(navProvider);
    final settings = ref.watch(settingsProvider);
    final catalog = ref.watch(libraryProvider).valueOrNull;
    final user = ref.watch(userLibraryProvider).valueOrNull;
    final pinned = ref.watch(downloadManagerProvider).pinnedCount;
    final premade = catalog?.manifest.playlists ?? const [];
    final custom = user?.playlists ?? const [];
    final songs = catalog?.tracks.length;
    final favorites = user?.favorites.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
      child: SizedBox(
        width: 268,
        child: GlassSurface(
          frosted: settings.frostedGlass,
          radius: 20,
          shadow: true,
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
            children: [
              const _Brand(),
              const SizedBox(height: 18),
              _NavRow(
                label: 'Home',
                icon: Icons.home_rounded,
                section: ShellSection.home,
                selected: nav.section,
              ),
              _NavRow(
                label: 'Search',
                icon: Icons.search_rounded,
                section: ShellSection.search,
                selected: nav.section,
              ),
              _NavRow(
                label: 'All songs',
                icon: Icons.library_music_rounded,
                section: ShellSection.songs,
                selected: nav.section,
                badge: songs == null ? null : formatInt(songs),
              ),
              _NavRow(
                label: 'Artists',
                icon: Icons.person_rounded,
                section: ShellSection.artists,
                selected: nav.section,
              ),
              _NavRow(
                label: 'Albums',
                icon: Icons.album_rounded,
                section: ShellSection.albums,
                selected: nav.section,
              ),
              _NavRow(
                label: 'Favorites',
                icon: Icons.favorite_rounded,
                section: ShellSection.favorites,
                selected: nav.section,
                badge: favorites == null ? null : formatInt(favorites),
              ),
              _NavRow(
                label: 'Pinned',
                icon: Icons.download_done_rounded,
                section: ShellSection.downloads,
                selected: nav.section,
                badge: formatInt(pinned),
              ),
              _NavRow(
                label: 'Settings',
                icon: Icons.tune_rounded,
                section: ShellSection.settings,
                selected: nav.section,
              ),
              const SizedBox(height: 18),
              const Eyebrow('PLAYLISTS'),
              const SizedBox(height: 8),
              for (final playlist in premade)
                _PlaylistTile(
                  name: playlist.name,
                  coverUrl: playlist.coverUrl,
                  badge: formatInt(playlist.trackCount),
                  selected:
                      !nav.customPlaylist &&
                      nav.section == ShellSection.playlist &&
                      nav.playlistId == playlist.slug,
                  onTap: () => ref
                      .read(navProvider.notifier)
                      .openPlaylist(playlist.slug),
                ),
              for (final playlist in custom)
                _PlaylistTile(
                  name: playlist.name,
                  badge: formatInt(playlist.trackIds.length),
                  selected: nav.customPlaylist && nav.playlistId == playlist.id,
                  onTap: () => ref
                      .read(navProvider.notifier)
                      .openPlaylist(playlist.id, custom: true),
                ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: GlassActionButton(
                  label: 'New playlist',
                  icon: Icons.add_rounded,
                  onPressed: () => unawaited(createUserPlaylist(context, ref)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.asset(
              'assets/icons/xerno-256.png',
              width: 44,
              height: 44,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Xerno',
                style: TextStyle(
                  fontFamily: 'Newsreader',
                  fontSize: 28,
                  height: 1,
                  color: AppColors.ivory,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'MUSIC · STUDIO',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 10,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w600,
                  color: AppColors.sage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavRow extends ConsumerWidget {
  const _NavRow({
    required this.label,
    required this.icon,
    required this.section,
    required this.selected,
    this.badge,
  });

  final String label;
  final IconData icon;
  final ShellSection section;
  final ShellSection selected;
  final String? badge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SideButton(
      label: label,
      icon: icon,
      badge: badge,
      selected: selected == section,
      onTap: () => ref.read(navProvider.notifier).go(section),
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.glowIvory : AppColors.ivory;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.accent.withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? AppColors.mint.withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 16,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.mint : Colors.transparent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    icon,
                    size: 18,
                    color: selected ? AppColors.mint : AppColors.sage,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (badge != null) _CountBadge(badge!),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({
    required this.name,
    required this.badge,
    required this.selected,
    required this.onTap,
    this.coverUrl,
  });

  final String name;
  final String badge;
  final bool selected;
  final VoidCallback onTap;
  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.accent.withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? AppColors.mint.withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(
                children: [
                  CoverImage(url: coverUrl, size: 28, radius: 6),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        color: selected ? AppColors.glowIvory : AppColors.ivory,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  _CountBadge(badge),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: AppTheme.tabular.copyWith(fontSize: 11, color: AppColors.sage),
      ),
    );
  }
}

class _MobileNav extends ConsumerWidget {
  const _MobileNav();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(navProvider).section;
    const items = [
      (ShellSection.home, Icons.home_outlined, 'Home'),
      (ShellSection.search, Icons.search, 'Search'),
      (ShellSection.songs, Icons.queue_music_outlined, 'Songs'),
      (ShellSection.downloads, Icons.download_outlined, 'Pinned'),
      (ShellSection.settings, Icons.settings_outlined, 'Settings'),
    ];
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final item in items)
                IconButton(
                  tooltip: item.$3,
                  onPressed: () => ref.read(navProvider.notifier).go(item.$1),
                  icon: Icon(
                    item.$2,
                    color: section == item.$1 ? AppColors.mint : AppColors.sage,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
