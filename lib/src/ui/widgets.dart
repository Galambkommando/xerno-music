import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../format.dart';
import '../logic/track_query.dart';
import '../models/library.dart';
import '../models/track.dart';
import '../models/user_library.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import 'playback_actions.dart';

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    required this.child,
    required this.frosted,
    this.color = AppColors.surface,
    this.border,
    this.radius = 0,
    super.key,
  });

  final Widget child;
  final bool frosted;
  final Color color;
  final BoxBorder? border;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: frosted ? color.withValues(alpha: 0.72) : color,
      borderRadius: BorderRadius.circular(radius),
      border: border,
    );
    if (!frosted) {
      return DecoratedBox(decoration: decoration, child: child);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(decoration: decoration, child: child),
      ),
    );
  }
}

class CoverImage extends StatelessWidget {
  const CoverImage({this.url, this.size, this.radius = 12, super.key});

  final String? url;
  final double? size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final child = url == null || url!.isEmpty
        ? const _CoverFallback()
        : Image.network(
            url!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => const _CoverFallback(),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const _CoverFallback();
            },
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.elevated, AppColors.accent],
        ),
      ),
      child: Center(
        child: Icon(Icons.graphic_eq_rounded, color: AppColors.ivory, size: 28),
      ),
    );
  }
}

class AmbientBackdrop extends StatelessWidget {
  const AmbientBackdrop({
    required this.child,
    required this.enabled,
    this.coverUrl,
    super.key,
  });

  final Widget child;
  final bool enabled;
  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.background),
        if (enabled && coverUrl != null && coverUrl!.isNotEmpty)
          Opacity(
            opacity: 0.38,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
              child: Image.network(
                coverUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x552D6A4F),
                Color(0xCC0A0D0B),
                AppColors.background,
              ],
              stops: [0, 0.42, 1],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.labelSmall);
  }
}

class SeekBar extends StatelessWidget {
  const SeekBar({
    required this.position,
    required this.duration,
    required this.onSeek,
    this.buffered = Duration.zero,
    super.key,
  });

  final Duration position;
  final Duration duration;
  final Duration buffered;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    final total = duration.inMilliseconds <= 0 ? 1 : duration.inMilliseconds;
    final played = (position.inMilliseconds / total).clamp(0.0, 1.0);
    final loaded = (buffered.inMilliseconds / total).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        void seekAt(double dx) {
          final fraction = (dx / constraints.maxWidth).clamp(0.0, 1.0);
          onSeek(Duration(milliseconds: (fraction * total).round()));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => seekAt(details.localPosition.dx),
          onHorizontalDragUpdate: (details) => seekAt(details.localPosition.dx),
          child: SizedBox(
            height: 22,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(height: 2, color: AppColors.border),
                FractionallySizedBox(
                  widthFactor: loaded.toDouble(),
                  child: Container(height: 2, color: AppColors.elevated),
                ),
                FractionallySizedBox(
                  widthFactor: played.toDouble(),
                  child: Container(height: 2, color: AppColors.mint),
                ),
                Align(
                  alignment: Alignment(played * 2 - 1, 0),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.ivory,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SourceBadge extends StatelessWidget {
  const SourceBadge(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
      ),
    );
  }
}

class ChoicePill extends StatelessWidget {
  const ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected ? AppColors.accentBright : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              color: selected ? AppColors.ivory : AppColors.sage,
            ),
          ),
        ),
      ),
    );
  }
}

class PlaylistCard extends StatelessWidget {
  const PlaylistCard({required this.playlist, required this.onTap, super.key});

  final PlaylistSummary playlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: CoverImage(url: playlist.coverUrl, radius: 12)),
              const SizedBox(height: 14),
              Text(
                playlist.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 6),
              Text(
                '${playlist.trackCount} tracks · ${playlist.statusLabel}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TrackBrowser extends ConsumerStatefulWidget {
  const TrackBrowser({
    required this.tracks,
    required this.title,
    this.eyebrow = 'LIBRARY',
    this.subtitle,
    this.coverUrl,
    this.positions,
    this.contextLabel,
    this.onPinAll,
    this.customPlaylistId,
    this.trailing,
    this.initialQuery = '',
    super.key,
  });

  final List<TrackRecord> tracks;
  final String title;
  final String eyebrow;
  final String? subtitle;
  final String? coverUrl;
  final Map<String, int>? positions;
  final String? contextLabel;
  final VoidCallback? onPinAll;
  final String? customPlaylistId;
  final Widget? trailing;
  final String initialQuery;

  @override
  ConsumerState<TrackBrowser> createState() => _TrackBrowserState();
}

class _TrackBrowserState extends ConsumerState<TrackBrowser> {
  TrackSort _sort = TrackSort.position;
  bool _ascending = true;
  late String _query;
  late final TextEditingController _filter;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _filter = TextEditingController(text: widget.initialQuery);
  }

  @override
  void didUpdateWidget(TrackBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialQuery != oldWidget.initialQuery &&
        widget.initialQuery.isNotEmpty &&
        widget.initialQuery != _filter.text) {
      _query = widget.initialQuery;
      _filter.text = widget.initialQuery;
    }
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = sortTracks(
      filterTracks(widget.tracks, _query),
      _sort,
      ascending: _ascending,
      positions: widget.positions,
    );
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (widget.coverUrl != null) ...[
                CoverImage(
                  url: widget.coverUrl,
                  size: wide ? 148 : 92,
                  radius: 14,
                ),
                const SizedBox(width: 22),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(widget.eyebrow),
                    const SizedBox(height: 8),
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.subtitle!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 16),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${filtered.length} tracks',
                          style: AppTheme.tabular.copyWith(fontSize: 13),
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          onPressed: () => _play(context, filtered, 0),
                          icon: const Icon(
                            Icons.play_arrow_rounded,
                            color: AppColors.mint,
                          ),
                          label: const Text('Play'),
                        ),
                        if (widget.onPinAll != null)
                          TextButton.icon(
                            onPressed: widget.onPinAll,
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('Pin offline'),
                          ),
                        if (widget.trailing != null) widget.trailing!,
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _filter,
                  decoration: xernoField(
                    'Filter',
                    hint: 'Title, artist, album, year',
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              const SizedBox(width: 12),
              PopupMenuButton<TrackSort>(
                initialValue: _sort,
                onSelected: (value) => setState(() => _sort = value),
                itemBuilder: (context) => [
                  for (final entry in trackSortLabels.entries)
                    PopupMenuItem(value: entry.key, child: Text(entry.value)),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  child: Text(
                    trackSortLabels[_sort] ?? 'Sort',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              IconButton(
                tooltip: _ascending ? 'Ascending' : 'Descending',
                onPressed: () => setState(() => _ascending = !_ascending),
                icon: Icon(
                  _ascending ? Icons.arrow_upward : Icons.arrow_downward,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('Nothing matches this view yet.'))
              : widget.customPlaylistId == null
              ? ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final track = filtered[index];
                    return TrackRow(
                      track: track,
                      number: widget.positions?[track.id] ?? index + 1,
                      onPlay: () => _play(context, filtered, index),
                    );
                  },
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  buildDefaultDragHandles: false,
                  itemCount: filtered.length,
                  onReorderItem: (from, to) {
                    final playlistId = widget.customPlaylistId!;
                    final data = ref.read(userLibraryProvider).valueOrNull;
                    final playlist = data?.playlists
                        .where((item) => item.id == playlistId)
                        .firstOrNull;
                    if (playlist == null) return;
                    final moving = filtered[from];
                    final source = playlist.trackIds.indexOf(moving.id);
                    final destinationId =
                        filtered[to.clamp(0, filtered.length - 1)].id;
                    final destination = playlist.trackIds.indexOf(
                      destinationId,
                    );
                    if (source < 0 || destination < 0) return;
                    unawaited(
                      ref
                          .read(userLibraryProvider.notifier)
                          .mutate(
                            (current) => current.reorderTracks(
                              playlistId,
                              source,
                              destination,
                            ),
                          ),
                    );
                  },
                  itemBuilder: (context, index) {
                    final track = filtered[index];
                    return TrackRow(
                      key: ValueKey('${track.id}-$index'),
                      track: track,
                      number: index + 1,
                      dragIndex: _query.isEmpty && _sort == TrackSort.position
                          ? index
                          : null,
                      customPlaylistId: widget.customPlaylistId,
                      onPlay: () => _play(context, filtered, index),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _play(
    BuildContext context,
    List<TrackRecord> tracks,
    int index,
  ) async {
    final note = await playTracks(
      ref,
      tracks: tracks,
      index: index,
      contextLabel: widget.contextLabel ?? widget.title,
    );
    if (!context.mounted) return;
    showNote(context, note);
  }
}

class TrackRow extends ConsumerWidget {
  const TrackRow({
    required this.track,
    required this.number,
    required this.onPlay,
    this.dragIndex,
    this.customPlaylistId,
    super.key,
  });

  final TrackRecord track;
  final int number;
  final VoidCallback onPlay;
  final int? dragIndex;
  final String? customPlaylistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(playerProvider).snapshot;
    final favorite =
        ref.watch(userLibraryProvider).valueOrNull?.isFavorite(track.id) ??
        false;
    final active = snapshot.track?.id == track.id;
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    return Material(
      color: active ? AppColors.elevated : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPlay,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              if (dragIndex != null)
                ReorderableDragStartListener(
                  index: dragIndex!,
                  child: const Icon(Icons.drag_indicator, size: 18),
                ),
              SizedBox(
                width: 36,
                child: Text(
                  active ? '▶' : number.toString().padLeft(2, '0'),
                  style: AppTheme.tabular.copyWith(
                    color: active ? AppColors.mint : AppColors.sage,
                    fontSize: 13,
                  ),
                ),
              ),
              CoverImage(url: track.coverUrl, size: 42, radius: 8),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w500,
                              color: active ? AppColors.mint : AppColors.ivory,
                            ),
                          ),
                        ),
                        if (track.explicit) ...[
                          const SizedBox(width: 6),
                          const _ExplicitMark(),
                        ],
                      ],
                    ),
                    Text(
                      track.displayArtist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (wide)
                Expanded(
                  flex: 3,
                  child: Text(
                    track.album,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              SizedBox(
                width: 52,
                child: Text(
                  track.durationFormatted,
                  textAlign: TextAlign.right,
                  style: AppTheme.tabular.copyWith(fontSize: 13),
                ),
              ),
              IconButton(
                tooltip: favorite ? 'Remove from favorites' : 'Favorite',
                onPressed: () {
                  unawaited(
                    ref
                        .read(userLibraryProvider.notifier)
                        .mutate((current) => current.toggleFavorite(track.id)),
                  );
                },
                icon: Icon(
                  favorite ? Icons.favorite : Icons.favorite_border,
                  color: favorite ? AppColors.mint : AppColors.sage,
                  size: 18,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Track actions',
                onSelected: (value) => _action(context, ref, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'next', child: Text('Play next')),
                  const PopupMenuItem(
                    value: 'queue',
                    child: Text('Add to queue'),
                  ),
                  const PopupMenuItem(
                    value: 'playlist',
                    child: Text('Add to playlist'),
                  ),
                  const PopupMenuItem(value: 'pin', child: Text('Pin offline')),
                  const PopupMenuItem(
                    value: 'artist',
                    child: Text('Go to artist'),
                  ),
                  const PopupMenuItem(
                    value: 'album',
                    child: Text('Go to album'),
                  ),
                  const PopupMenuItem(value: 'details', child: Text('Details')),
                  if (customPlaylistId != null)
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('Remove from playlist'),
                    ),
                ],
                icon: const Icon(Icons.more_horiz, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _action(
    BuildContext context,
    WidgetRef ref,
    String value,
  ) async {
    if (value == 'next' || value == 'queue') {
      final playable = await resolveOne(ref, track);
      if (!context.mounted) return;
      if (playable == null) {
        showNote(context, 'No audio source for ${track.title}.');
        return;
      }
      if (value == 'next') {
        await ref.read(playerProvider).addNext(playable);
      } else {
        await ref.read(playerProvider).enqueue(playable);
      }
      return;
    }
    if (value == 'playlist') {
      if (!context.mounted) return;
      await _addToPlaylist(context, ref);
      return;
    }
    if (value == 'pin') {
      final error = await ref
          .read(downloadManagerProvider)
          .pinTrack(track, ref.read(settingsProvider));
      if (!context.mounted) return;
      showNote(context, error ?? 'Pinned ${track.title}.');
      return;
    }
    if (value == 'artist') {
      ref.read(navProvider.notifier).openArtist(track.artist);
      return;
    }
    if (value == 'album') {
      ref.read(navProvider.notifier).openAlbum(albumKeyFor(track));
      return;
    }
    if (value == 'details') {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _DetailsDialog(track: track),
      );
      return;
    }
    if (value == 'remove') {
      final playlistId = customPlaylistId;
      final data = ref.read(userLibraryProvider).valueOrNull;
      final playlist = data?.playlists
          .where((item) => item.id == playlistId)
          .firstOrNull;
      final index = playlist?.trackIds.indexOf(track.id) ?? -1;
      if (playlistId != null && index >= 0) {
        await ref
            .read(userLibraryProvider.notifier)
            .mutate((current) => current.removeTrack(playlistId, index));
      }
    }
  }

  Future<void> _addToPlaylist(BuildContext context, WidgetRef ref) async {
    final data =
        ref.read(userLibraryProvider).valueOrNull ?? UserLibraryData.empty();
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Add to playlist'),
        children: [
          for (final playlist in data.playlists)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, playlist.id),
              child: Text(playlist.name),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, '__new__'),
            child: const Text('New playlist'),
          ),
        ],
      ),
    );
    if (chosen == null) return;
    if (chosen == '__new__') {
      if (!context.mounted) return;
      final name = await promptText(
        context,
        title: 'New playlist',
        confirm: 'Create',
      );
      if (name == null || name.trim().isEmpty) return;
      await ref.read(userLibraryProvider.notifier).mutate((current) {
        final created = current.addPlaylist(name);
        final id = created.playlists.last.id;
        return created.addTrack(id, track.id);
      });
      return;
    }
    await ref
        .read(userLibraryProvider.notifier)
        .mutate((current) => current.addTrack(chosen, track.id));
  }
}

class _ExplicitMark extends StatelessWidget {
  const _ExplicitMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'E',
        style: TextStyle(
          fontSize: 10,
          color: AppColors.sage,
          fontFamily: 'Outfit',
        ),
      ),
    );
  }
}

class _DetailsDialog extends ConsumerWidget {
  const _DetailsDialog({required this.track});

  final TrackRecord track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quality = track.audioQuality;
    final lines = [
      track.displayArtist,
      if (track.album.isNotEmpty)
        '${track.album}${track.year == null ? '' : ' · ${track.year}'}',
      '${track.durationFormatted} · ${quality.bitrateKbps} kbps · ${quality.sampleRateHz} Hz',
      'Popularity ${formatInt(track.popularity)}',
      if (track.file.relativePath.isNotEmpty) track.file.relativePath,
      if (track.isrc.isNotEmpty) 'ISRC ${track.isrc}',
    ];
    return AlertDialog(
      title: Text(track.title, style: Theme.of(context).textTheme.titleLarge),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(line),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

Future<String?> promptText(
  BuildContext context, {
  required String title,
  String initial = '',
  String confirm = 'Save',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: xernoField('Name'),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text(confirm),
        ),
      ],
    ),
  );
}
