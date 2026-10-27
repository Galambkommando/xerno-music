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

    final mini = settings.miniPlayer || MediaQuery.sizeOf(context).height < 220;
    if (mini) {
      return const Scaffold(body: MiniPlayerView());
    }

    final wide = MediaQuery.sizeOf(context).width >= 900;
    final page = _page(library, nav);
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.space): _ToggleIntent(),
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
          child: Scaffold(
            body: wide
                ? Row(
                    children: [
                      const _Sidebar(),
                      Expanded(
                        child: Column(
                          children: [
                            const PlaybackFailureBanner(),
                            Expanded(child: page),
                            const NowPlayingSlot(),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      const PlaybackFailureBanner(),
                      Expanded(child: page),
                      const NowPlayingSlot(),
                      const _MobileNav(),
                    ],
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

class _ToggleIntent extends Intent {
  const _ToggleIntent();
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
    final playlists =
        ref.watch(userLibraryProvider).valueOrNull?.playlists ?? const [];
    return Container(
      width: 248,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
        children: [
          const Text(
            'Xerno',
            style: TextStyle(
              fontFamily: 'Newsreader',
              fontSize: 36,
              color: AppColors.ivory,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text('Music', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 22),
          _NavRow(
            label: 'Home',
            section: ShellSection.home,
            selected: nav.section,
          ),
          _NavRow(
            label: 'Search',
            section: ShellSection.search,
            selected: nav.section,
          ),
          _NavRow(
            label: 'All songs',
            section: ShellSection.songs,
            selected: nav.section,
          ),
          _NavRow(
            label: 'Artists',
            section: ShellSection.artists,
            selected: nav.section,
          ),
          _NavRow(
            label: 'Albums',
            section: ShellSection.albums,
            selected: nav.section,
          ),
          _NavRow(
            label: 'Favorites',
            section: ShellSection.favorites,
            selected: nav.section,
          ),
          _NavRow(
            label: 'Pinned',
            section: ShellSection.downloads,
            selected: nav.section,
          ),
          _NavRow(
            label: 'Settings',
            section: ShellSection.settings,
            selected: nav.section,
          ),
          const SizedBox(height: 22),
          const Eyebrow('PLAYLISTS'),
          const SizedBox(height: 8),
          for (final playlist in playlists)
            _SideButton(
              label: playlist.name,
              selected: nav.customPlaylist && nav.playlistId == playlist.id,
              onTap: () => ref
                  .read(navProvider.notifier)
                  .openPlaylist(playlist.id, custom: true),
            ),
        ],
      ),
    );
  }
}

class _NavRow extends ConsumerWidget {
  const _NavRow({
    required this.label,
    required this.section,
    required this.selected,
  });

  final String label;
  final ShellSection section;
  final ShellSection selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SideButton(
      label: label,
      selected: selected == section,
      onTap: () => ref.read(navProvider.notifier).go(section),
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Outfit',
              color: selected ? AppColors.mint : AppColors.ivory,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
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
