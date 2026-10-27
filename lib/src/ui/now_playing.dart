import 'dart:async';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../format.dart';
import '../logic/lrc.dart';
import '../logic/play_queue.dart';
import '../player/desktop_window.dart';
import '../player/playback.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import 'playback_actions.dart';
import 'sound_controls.dart';
import 'widgets.dart';

class PlaybackFailureBanner extends ConsumerWidget {
  const PlaybackFailureBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = watchSnapshot(ref);
    final message = snapshot.error;
    if (message == null || message.isEmpty || snapshot.hasTrack) {
      return const SizedBox.shrink();
    }
    return Material(
      color: AppColors.elevated,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.mint, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  color: AppColors.ivory,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NowPlayingSlot extends ConsumerWidget {
  const NowPlayingSlot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = watchSnapshot(ref);
    final frosted = ref.watch(
      settingsProvider.select((settings) => settings.frostedGlass),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GlassSurface(
        frosted: frosted,
        radius: 18,
        shadow: true,
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        child: NowPlayingBar(snapshot: snapshot),
      ),
    );
  }
}

class NowPlayingBar extends ConsumerWidget {
  const NowPlayingBar({required this.snapshot, super.key});

  final PlayerSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 920) {
            return _WideBar(snapshot: snapshot);
          }
          return _CompactBar(snapshot: snapshot);
        },
      ),
    );
  }
}

class _WideBar extends StatelessWidget {
  const _WideBar({required this.snapshot});

  final PlayerSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(flex: 5, child: _Identity(snapshot: snapshot)),
            Expanded(flex: 4, child: _Transport(snapshot: snapshot)),
            Expanded(flex: 4, child: _Tools(snapshot: snapshot, volume: true)),
          ],
        ),
        const SizedBox(height: 6),
        _SeekLine(snapshot: snapshot),
      ],
    );
  }
}

class _CompactBar extends ConsumerWidget {
  const _CompactBar({required this.snapshot});

  final PlayerSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = snapshot.track;
    final mini = ref.watch(
      settingsProvider.select((settings) => settings.miniPlayer),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _CoverButton(snapshot: snapshot, size: 44),
            const SizedBox(width: 8),
            Expanded(child: _TitleBlock(snapshot: snapshot)),
            if (track != null) ...[
              const SizedBox(width: 4),
              _FavoriteButton(trackId: track.id),
            ],
            const SizedBox(width: 4),
            _PlayButton(
              playing: snapshot.playing,
              tooltip: track == null
                  ? 'Play library'
                  : snapshot.playing
                  ? 'Pause'
                  : 'Play',
              onPressed: () => unawaited(_toggleOrStart(ref, snapshot)),
            ),
            const SizedBox(width: 4),
            GlassIconButton(
              tooltip: 'Next',
              icon: Icons.skip_next_rounded,
              onPressed: track == null
                  ? null
                  : () => unawaited(ref.read(playerProvider).next()),
            ),
            const SizedBox(width: 4),
            GlassIconButton(
              tooltip: mini ? 'Exit mini player' : 'Mini player',
              icon: Icons.picture_in_picture_alt_rounded,
              active: mini,
              onPressed: () => unawaited(setMiniPlayer(ref, !mini)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _SeekLine(snapshot: snapshot),
      ],
    );
  }
}

class _Identity extends ConsumerWidget {
  const _Identity({required this.snapshot});

  final PlayerSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = snapshot.track;
    final quality = _qualityLabel(snapshot);
    return Row(
      children: [
        _CoverButton(snapshot: snapshot, size: 52),
        const SizedBox(width: 10),
        Expanded(
          child: _TitleBlock(snapshot: snapshot, quality: quality),
        ),
        if (track != null) ...[
          const SizedBox(width: 6),
          _FavoriteButton(trackId: track.id),
        ],
      ],
    );
  }
}

class _CoverButton extends StatelessWidget {
  const _CoverButton({required this.snapshot, required this.size});

  final PlayerSnapshot snapshot;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openNowPlaying(context),
      child: CoverImage(
        url: snapshot.track?.artUri?.toString(),
        size: size,
        radius: 10,
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.snapshot, this.quality});

  final PlayerSnapshot snapshot;
  final String? quality;

  @override
  Widget build(BuildContext context) {
    final track = snapshot.track;
    final title = track?.title ?? 'Ready to play';
    final subtitle = track == null
        ? 'Click Play or pick any track'
        : track.album.isEmpty
        ? track.artist
        : '${track.artist}  ·  ${track.album}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
            color: AppColors.ivory,
          ),
        ),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (quality != null) ...[
          const SizedBox(height: 4),
          SourceBadge(quality!),
        ],
      ],
    );
  }
}

class _FavoriteButton extends ConsumerWidget {
  const _FavoriteButton({required this.trackId});

  final String trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorite =
        ref.watch(userLibraryProvider).valueOrNull?.isFavorite(trackId) ??
        false;
    return GlassIconButton(
      tooltip: favorite ? 'Remove from favorites' : 'Favorite',
      icon: favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      active: favorite,
      onPressed: () => unawaited(
        ref
            .read(userLibraryProvider.notifier)
            .mutate((current) => current.toggleFavorite(trackId)),
      ),
    );
  }
}

class _Transport extends ConsumerWidget {
  const _Transport({required this.snapshot});

  final PlayerSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.read(playerProvider);
    final track = snapshot.track;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GlassIconButton(
          tooltip: snapshot.shuffle ? 'Shuffle on' : 'Shuffle',
          icon: Icons.shuffle_rounded,
          active: snapshot.shuffle,
          onPressed: track == null
              ? null
              : () => unawaited(player.setShuffle(!snapshot.shuffle)),
        ),
        const SizedBox(width: 4),
        GlassIconButton(
          tooltip: 'Previous',
          icon: Icons.skip_previous_rounded,
          onPressed: track == null ? null : () => unawaited(player.previous()),
        ),
        const SizedBox(width: 6),
        _PlayButton(
          playing: snapshot.playing,
          tooltip: track == null
              ? 'Play library'
              : snapshot.playing
              ? 'Pause'
              : 'Play',
          onPressed: () => unawaited(_toggleOrStart(ref, snapshot)),
        ),
        const SizedBox(width: 6),
        GlassIconButton(
          tooltip: 'Next',
          icon: Icons.skip_next_rounded,
          onPressed: track == null ? null : () => unawaited(player.next()),
        ),
        const SizedBox(width: 4),
        GlassIconButton(
          tooltip: 'Repeat ${_repeatLabel(snapshot.repeat)}',
          icon: snapshot.repeat == RepeatMode.one
              ? Icons.repeat_one_rounded
              : Icons.repeat_rounded,
          active: snapshot.repeat != RepeatMode.off,
          onPressed: track == null
              ? null
              : () => unawaited(player.cycleRepeat()),
        ),
      ],
    );
  }
}

class _Tools extends ConsumerWidget {
  const _Tools({required this.snapshot, required this.volume});

  final PlayerSnapshot snapshot;
  final bool volume;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.read(playerProvider);
    final mini = ref.watch(
      settingsProvider.select((settings) => settings.miniPlayer),
    );
    final muted = snapshot.volume < 0.01;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        GlassIconButton(
          tooltip: 'Lyrics',
          icon: Icons.lyrics_outlined,
          size: 32,
          onPressed: () => openNowPlaying(context),
        ),
        const SizedBox(width: 2),
        GlassIconButton(
          tooltip: 'Now playing',
          icon: Icons.open_in_full_rounded,
          size: 32,
          onPressed: () => openNowPlaying(context),
        ),
        const SizedBox(width: 2),
        GlassIconButton(
          tooltip: 'Sound',
          icon: Icons.equalizer_rounded,
          size: 32,
          onPressed: () => showSoundSheet(context, ref),
        ),
        const SizedBox(width: 2),
        GlassIconButton(
          tooltip: 'Queue',
          icon: Icons.queue_music_rounded,
          size: 32,
          onPressed: () => showQueueSheet(context),
        ),
        const SizedBox(width: 2),
        GlassIconButton(
          tooltip: muted ? 'Unmute' : 'Mute',
          icon: muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          active: muted,
          size: 32,
          onPressed: () => unawaited(_setVolume(ref, muted ? 0.9 : 0)),
        ),
        if (volume) ...[
          const SizedBox(width: 2),
          SizedBox(
            width: 68,
            child: Slider(
              value: snapshot.volume.clamp(0, 1).toDouble(),
              onChanged: (value) => unawaited(player.setVolume(value)),
              onChangeEnd: (value) => unawaited(_rememberVolume(ref, value)),
            ),
          ),
        ],
        const SizedBox(width: 2),
        GlassIconButton(
          tooltip: mini ? 'Exit mini player' : 'Mini player',
          icon: Icons.picture_in_picture_alt_rounded,
          active: mini,
          size: 32,
          onPressed: () => unawaited(setMiniPlayer(ref, !mini)),
        ),
      ],
    );
  }
}

class _SeekLine extends ConsumerWidget {
  const _SeekLine({required this.snapshot});

  final PlayerSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duration = _duration(snapshot);
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            formatClock(snapshot.position),
            style: AppTheme.tabular.copyWith(fontSize: 11),
          ),
        ),
        Expanded(
          child: SeekBar(
            position: snapshot.position,
            duration: duration,
            buffered: snapshot.buffered,
            onSeek: (position) =>
                unawaited(ref.read(playerProvider).seek(position)),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            formatClock(duration),
            textAlign: TextAlign.right,
            style: AppTheme.tabular.copyWith(fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.playing,
    required this.tooltip,
    required this.onPressed,
  });

  final bool playing;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: playing ? AppColors.ivory : AppColors.accent,
        shape: const CircleBorder(
          side: BorderSide(color: AppColors.mint, width: 1.2),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: playing ? AppColors.obsidian : AppColors.ivory,
            ),
          ),
        ),
      ),
    );
  }
}

class MiniPlayerView extends ConsumerWidget {
  const MiniPlayerView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = watchSnapshot(ref);
    final track = snapshot.track;
    final player = ref.read(playerProvider);
    final frosted = ref.watch(settingsProvider).frostedGlass;
    final favorite = track == null
        ? false
        : ref.watch(userLibraryProvider).valueOrNull?.isFavorite(track.id) ??
              false;
    final muted = snapshot.volume < 0.01;
    final title =
        track?.title ??
        (snapshot.error == null ? 'Nothing playing' : 'Playback unavailable');
    final subtitle = track == null
        ? (snapshot.error ?? 'Xerno')
        : track.album.isEmpty
        ? track.artist
        : '${track.artist}  ·  ${track.album}';
    return Padding(
      padding: const EdgeInsets.all(10),
      child: GlassSurface(
        frosted: frosted,
        radius: 18,
        shadow: true,
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => unawaited(setMiniPlayer(ref, false)),
                    child: CoverImage(
                      url: track?.artUri?.toString(),
                      size: 48,
                      radius: 10,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => unawaited(setMiniPlayer(ref, false)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w600,
                              color: AppColors.ivory,
                            ),
                          ),
                          Text(
                            subtitle,
                            maxLines: track == null && snapshot.error != null
                                ? 2
                                : 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GlassIconButton(
                    tooltip: muted ? 'Unmute' : 'Mute',
                    icon: muted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    active: muted,
                    onPressed: () =>
                        unawaited(_setVolume(ref, muted ? 0.9 : 0)),
                  ),
                  if (track != null) ...[
                    const SizedBox(width: 4),
                    GlassIconButton(
                      tooltip: favorite ? 'Remove from favorites' : 'Favorite',
                      icon: favorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      active: favorite,
                      onPressed: () => unawaited(
                        ref
                            .read(userLibraryProvider.notifier)
                            .mutate(
                              (current) => current.toggleFavorite(track.id),
                            ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  GlassActionButton(
                    label: 'Expand',
                    icon: Icons.open_in_full_rounded,
                    tooltip: 'Expand to full window',
                    onPressed: () => unawaited(setMiniPlayer(ref, false)),
                  ),
                ],
              ),
              if (track != null) ...[
                const SizedBox(height: 4),
                SeekBar(
                  position: snapshot.position,
                  duration: _duration(snapshot),
                  buffered: snapshot.buffered,
                  onSeek: (position) => unawaited(player.seek(position)),
                ),
              ],
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GlassIconButton(
                    tooltip: 'Previous',
                    icon: Icons.skip_previous_rounded,
                    onPressed: track == null
                        ? null
                        : () => unawaited(player.previous()),
                  ),
                  const SizedBox(width: 8),
                  _PlayButton(
                    playing: snapshot.playing,
                    tooltip: track == null
                        ? 'Play library'
                        : snapshot.playing
                        ? 'Pause'
                        : 'Play',
                    onPressed: () => unawaited(_toggleOrStart(ref, snapshot)),
                  ),
                  const SizedBox(width: 8),
                  GlassIconButton(
                    tooltip: 'Next',
                    icon: Icons.skip_next_rounded,
                    onPressed: track == null
                        ? null
                        : () => unawaited(player.next()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> setMiniPlayer(WidgetRef ref, bool enabled) async {
  await ref
      .read(settingsProvider.notifier)
      .update((current) => current.copyWith(miniPlayer: enabled));
  await DesktopWindow.setMini(enabled);
}

Future<void> _toggleOrStart(WidgetRef ref, PlayerSnapshot snapshot) async {
  if (snapshot.track == null) {
    final catalog = ref.read(libraryProvider).valueOrNull;
    if (catalog == null || catalog.tracks.isEmpty) return;
    await playTracks(ref, tracks: catalog.tracks, contextLabel: 'Library');
    return;
  }
  await ref.read(playerProvider).toggle();
}

Future<void> _setVolume(WidgetRef ref, double volume) async {
  await ref.read(playerProvider).setVolume(volume);
  await _rememberVolume(ref, volume);
}

Future<void> _rememberVolume(WidgetRef ref, double volume) async {
  await ref
      .read(settingsProvider.notifier)
      .update((current) => current.copyWith(volume: volume));
}

String? _qualityLabel(PlayerSnapshot snapshot) {
  final track = snapshot.track;
  if (track == null) return null;
  final source = snapshot.sourceLabel;
  final word = source == 'Pinned' || source == 'Local' ? source! : 'Cloud';
  return '${track.bitrateKbps} kbps · $word';
}

void openNowPlaying(BuildContext context) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondary) => const NowPlayingScreen(),
      transitionsBuilder: (context, animation, secondary, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = watchSnapshot(ref);
    final settings = ref.watch(settingsProvider);
    final track = snapshot.track;
    final player = ref.read(playerProvider);
    final wide = MediaQuery.sizeOf(context).width >= 980;
    return Scaffold(
      body: AmbientBackdrop(
        enabled: settings.ambientGlow,
        coverUrl: track?.artUri?.toString(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                    const Spacer(),
                    if (snapshot.sourceLabel != null)
                      SourceBadge(snapshot.sourceLabel!),
                    IconButton(
                      tooltip: 'Sound',
                      onPressed: () => showSoundSheet(context, ref),
                      icon: const Icon(Icons.tune_rounded),
                    ),
                    IconButton(
                      tooltip: 'Queue',
                      onPressed: () => showQueueSheet(context),
                      icon: const Icon(Icons.queue_music_rounded),
                    ),
                  ],
                ),
                Expanded(
                  child: wide
                      ? Row(
                          children: [
                            Expanded(child: _Stage(snapshot: snapshot)),
                            const SizedBox(width: 28),
                            Expanded(child: _LyricsPane(snapshot: snapshot)),
                          ],
                        )
                      : Column(
                          children: [
                            _Stage(snapshot: snapshot, compact: true),
                            const SizedBox(height: 8),
                            Expanded(child: _LyricsPane(snapshot: snapshot)),
                          ],
                        ),
                ),
                const SizedBox(height: 8),
                SeekBar(
                  position: snapshot.position,
                  duration: _duration(snapshot),
                  buffered: snapshot.buffered,
                  onSeek: (position) => unawaited(player.seek(position)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      formatClock(snapshot.position),
                      style: AppTheme.tabular,
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: snapshot.shuffle ? 'Shuffle on' : 'Shuffle off',
                      onPressed: () =>
                          unawaited(player.setShuffle(!snapshot.shuffle)),
                      icon: Icon(
                        Icons.shuffle_rounded,
                        color: snapshot.shuffle
                            ? AppColors.mint
                            : AppColors.sage,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Previous',
                      onPressed: () => unawaited(player.previous()),
                      icon: const Icon(Icons.skip_previous_rounded, size: 32),
                    ),
                    IconButton(
                      tooltip: snapshot.playing ? 'Pause' : 'Play',
                      onPressed: () => unawaited(player.toggle()),
                      icon: Icon(
                        snapshot.playing
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded,
                        size: 56,
                        color: AppColors.ivory,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next',
                      onPressed: () => unawaited(player.next()),
                      icon: const Icon(Icons.skip_next_rounded, size: 32),
                    ),
                    IconButton(
                      tooltip: 'Repeat ${_repeatLabel(snapshot.repeat)}',
                      onPressed: () => unawaited(player.cycleRepeat()),
                      icon: Icon(
                        snapshot.repeat == RepeatMode.one
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        color: snapshot.repeat == RepeatMode.off
                            ? AppColors.sage
                            : AppColors.mint,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatClock(_duration(snapshot)),
                      style: AppTheme.tabular,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({required this.snapshot, this.compact = false});

  final PlayerSnapshot snapshot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final track = snapshot.track;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CoverImage(
          url: track?.artUri?.toString(),
          size: compact ? 180 : 320,
          radius: 18,
        ),
        const SizedBox(height: 18),
        Text(
          track?.title ?? 'Nothing playing',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text(
          track == null
              ? ''
              : '${track.artist}${track.album.isEmpty ? '' : '  ·  ${track.album}'}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.sage),
        ),
        if (snapshot.contextLabel != null) ...[
          const SizedBox(height: 8),
          Text(
            snapshot.contextLabel!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _LyricsPane extends ConsumerWidget {
  const _LyricsPane({required this.snapshot});

  final PlayerSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = snapshot.track;
    if (track == null) {
      return const Center(child: Text('Queue a track to look up lyrics.'));
    }
    final lyrics = ref.watch(lyricsProvider(track.id));
    return lyrics.when(
      loading: () => const Center(child: Text('Looking up lyrics')),
      error: (error, _) =>
          const Center(child: Text('Lyrics are unavailable right now.')),
      data: (value) {
        if (value.instrumental) {
          return const Center(child: Text('Instrumental'));
        }
        if (value.hasSynced) {
          return _SyncedLyrics(
            lines: value.synced,
            position: snapshot.position,
          );
        }
        if (value.plain != null) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              value.plain!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        }
        return const Center(
          child: Text('LRCLIB has no lyrics for this track yet.'),
        );
      },
    );
  }
}

class _SyncedLyrics extends StatefulWidget {
  const _SyncedLyrics({required this.lines, required this.position});

  final List<LyricLine> lines;
  final Duration position;

  @override
  State<_SyncedLyrics> createState() => _SyncedLyricsState();
}

class _SyncedLyricsState extends State<_SyncedLyrics> {
  final _controller = ScrollController();
  int _shown = -2;

  @override
  void didUpdateWidget(_SyncedLyrics oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reveal();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  void _reveal() {
    final index = activeLyricIndex(widget.lines, widget.position);
    if (index == _shown || !_controller.hasClients) return;
    _shown = index;
    final target =
        (index * 48.0) - (_controller.position.viewportDimension / 2) + 24;
    final max = _controller.position.maxScrollExtent;
    _controller.animateTo(
      target.clamp(0, max),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = activeLyricIndex(widget.lines, widget.position);
    return ListView.builder(
      controller: _controller,
      padding: const EdgeInsets.symmetric(vertical: 24),
      itemCount: widget.lines.length,
      itemBuilder: (context, index) {
        final line = widget.lines[index];
        final current = index == active;
        return SizedBox(
          height: 48,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              line.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Newsreader',
                fontSize: current ? 26 : 18,
                height: 1.15,
                color: current
                    ? AppColors.ivory
                    : AppColors.sage.withValues(alpha: 0.72),
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> showQueueSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const _QueueSheet(),
  );
}

class _QueueSheet extends ConsumerWidget {
  const _QueueSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = watchSnapshot(ref);
    final frosted = ref.watch(settingsProvider).frostedGlass;
    final player = ref.read(playerProvider);
    final height = MediaQuery.sizeOf(context).height * 0.72;
    return GlassSurface(
      frosted: frosted,
      color: AppColors.surface,
      radius: 20,
      border: Border.all(color: AppColors.border),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Text('Queue', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  GlassActionButton(
                    label: 'Clear upcoming',
                    icon: Icons.playlist_remove_rounded,
                    onPressed: () => unawaited(player.clearUpcoming()),
                  ),
                ],
              ),
            ),
            Expanded(
              child: snapshot.queue.isEmpty
                  ? const Center(child: Text('The queue is empty.'))
                  : ListView.builder(
                      itemCount: snapshot.queue.length,
                      itemBuilder: (context, index) {
                        final item = snapshot.queue[index];
                        final current = index == snapshot.index;
                        return ListTile(
                          onTap: () => unawaited(player.playIndex(index)),
                          leading: Text(
                            '${index + 1}'.padLeft(2, '0'),
                            style: AppTheme.tabular.copyWith(
                              color: current ? AppColors.mint : AppColors.sage,
                            ),
                          ),
                          title: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: current ? AppColors.mint : AppColors.ivory,
                            ),
                          ),
                          subtitle: Text(
                            item.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            tooltip: 'Remove',
                            onPressed: () => unawaited(player.removeAt(index)),
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showSoundSheet(BuildContext context, WidgetRef ref) {
  final frosted = ref.read(settingsProvider).frostedGlass;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => GlassSurface(
      frosted: frosted,
      color: AppColors.surface,
      radius: 20,
      border: Border.all(color: AppColors.border),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Text('Sound', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const SoundControls(),
          ],
        ),
      ),
    ),
  );
}

Duration _duration(PlayerSnapshot snapshot) {
  if (snapshot.duration > Duration.zero) return snapshot.duration;
  return snapshot.track?.duration ?? Duration.zero;
}

String _repeatLabel(RepeatMode mode) {
  return switch (mode) {
    RepeatMode.off => 'off',
    RepeatMode.all => 'all',
    RepeatMode.one => 'one',
  };
}
