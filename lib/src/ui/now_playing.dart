import 'dart:async';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../format.dart';
import '../logic/lrc.dart';
import '../logic/play_queue.dart';
import '../player/playback.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import 'sound_controls.dart';
import 'widgets.dart';

class NowPlayingSlot extends ConsumerWidget {
  const NowPlayingSlot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = watchSnapshot(ref);
    if (!snapshot.hasTrack) return const SizedBox.shrink();
    final frosted = ref.watch(settingsProvider).frostedGlass;
    return GlassSurface(
      frosted: frosted,
      color: AppColors.surface,
      border: const Border(top: BorderSide(color: AppColors.border)),
      child: NowPlayingBar(snapshot: snapshot),
    );
  }
}

class NowPlayingBar extends ConsumerWidget {
  const NowPlayingBar({required this.snapshot, super.key});

  final PlayerSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = snapshot.track;
    if (track == null) return const SizedBox.shrink();
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final player = ref.read(playerProvider);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => openNowPlaying(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CoverImage(
                    url: track.artUri?.toString(),
                    size: 46,
                    radius: 8,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w500,
                            color: AppColors.ivory,
                          ),
                        ),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (wide) ...[
                    IconButton(
                      tooltip: 'Previous',
                      onPressed: () => unawaited(player.previous()),
                      icon: const Icon(Icons.skip_previous_rounded),
                    ),
                  ],
                  IconButton(
                    tooltip: snapshot.playing ? 'Pause' : 'Play',
                    onPressed: () => unawaited(player.toggle()),
                    icon: Icon(
                      snapshot.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: AppColors.mint,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next',
                    onPressed: () => unawaited(player.next()),
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                  if (wide)
                    SizedBox(
                      width: 120,
                      child: Slider(
                        value: snapshot.volume.clamp(0, 1).toDouble(),
                        onChanged: (value) =>
                            unawaited(player.setVolume(value)),
                        onChangeEnd: (value) => unawaited(
                          ref
                              .read(settingsProvider.notifier)
                              .update(
                                (current) => current.copyWith(volume: value),
                              ),
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Queue',
                    onPressed: () => showQueueSheet(context),
                    icon: const Icon(Icons.queue_music_rounded),
                  ),
                ],
              ),
              SeekBar(
                position: snapshot.position,
                duration: snapshot.duration == Duration.zero
                    ? track.duration
                    : snapshot.duration,
                buffered: snapshot.buffered,
                onSeek: (position) => unawaited(player.seek(position)),
              ),
            ],
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
    return GlassSurface(
      frosted: frosted,
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            CoverImage(url: track?.artUri?.toString(), size: 42, radius: 8),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track?.title ?? 'Nothing playing',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w500,
                      color: AppColors.ivory,
                    ),
                  ),
                  Text(
                    track?.artist ?? 'Xerno',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (track != null)
                    SeekBar(
                      position: snapshot.position,
                      duration: snapshot.duration == Duration.zero
                          ? track.duration
                          : snapshot.duration,
                      onSeek: (position) => unawaited(player.seek(position)),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: snapshot.playing ? 'Pause' : 'Play',
              onPressed: track == null
                  ? null
                  : () => unawaited(player.toggle()),
              icon: Icon(
                snapshot.playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: AppColors.mint,
              ),
            ),
            IconButton(
              tooltip: 'Next',
              onPressed: track == null ? null : () => unawaited(player.next()),
              icon: const Icon(Icons.skip_next_rounded),
            ),
          ],
        ),
      ),
    );
  }
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
                  TextButton(
                    onPressed: () => unawaited(player.clearUpcoming()),
                    child: const Text('Clear upcoming'),
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
