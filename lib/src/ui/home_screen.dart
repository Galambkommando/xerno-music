import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../format.dart';
import '../models/library.dart';
import '../models/track.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import 'playback_actions.dart';
import 'playlist_io.dart';
import 'widgets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({required this.catalog, super.key});

  final LibraryIndex catalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frosted = ref.watch(settingsProvider).frostedGlass;
    final featured = catalog.tracks.take(8).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 148),
      children: [
        GlassSurface(
          frosted: frosted,
          radius: 20,
          shadow: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final search = TextField(
                  decoration: xernoField(
                    'Search the library',
                    hint: 'Title, artist, album, year',
                  ).copyWith(prefixIcon: const Icon(Icons.search_rounded)),
                  onSubmitted: (value) =>
                      ref.read(navProvider.notifier).search(value),
                );
                final copy = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('ON THE GO'),
                    const SizedBox(height: 4),
                    Text(
                      'Xerno',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Editorial playback for the Xernover library.',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: AppColors.sage),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatPill('${formatInt(catalog.tracks.length)} Tracks'),
                        const _StatPill('320 kbps MP3'),
                        const _StatPill('RöcsögeCloud'),
                        _StatPill(
                          '${formatInt(catalog.manifest.playlists.length)} Playlists',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        PrimaryActionPill(
                          label: 'Play library',
                          icon: Icons.play_arrow_rounded,
                          onPressed: catalog.tracks.isEmpty
                              ? null
                              : () => unawaited(
                                  _play(
                                    context,
                                    ref,
                                    catalog.tracks,
                                    shuffle: false,
                                  ),
                                ),
                        ),
                        GlassActionButton(
                          label: 'Shuffle all',
                          icon: Icons.shuffle_rounded,
                          onPressed: catalog.tracks.isEmpty
                              ? null
                              : () => unawaited(
                                  _play(
                                    context,
                                    ref,
                                    catalog.tracks,
                                    shuffle: true,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                );
                if (constraints.maxWidth < 760) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [copy, const SizedBox(height: 12), search],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: copy),
                    const SizedBox(width: 18),
                    SizedBox(width: 280, child: search),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Eyebrow('PREMADE'),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 860
                ? 4
                : constraints.maxWidth >= 560
                ? 2
                : 1;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: catalog.manifest.playlists.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisExtent: columns >= 4 ? 206 : 236,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemBuilder: (context, index) {
                final playlist = catalog.manifest.playlists[index];
                final tracks = catalog.tracksFor(playlist);
                return PlaylistCard(
                  playlist: playlist,
                  frosted: frosted,
                  onTap: () => ref
                      .read(navProvider.notifier)
                      .openPlaylist(playlist.slug),
                  onPlay: tracks.isEmpty
                      ? null
                      : () => unawaited(
                          _play(context, ref, tracks, label: playlist.name),
                        ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final sideBySide = constraints.maxWidth >= 860;
            final picks = _QuickPicks(catalog: catalog, tracks: featured);
            const yours = _YourPlaylists();
            if (!sideBySide) {
              return Column(
                children: [picks, const SizedBox(height: 14), yours],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: picks),
                const SizedBox(width: 14),
                Expanded(flex: 2, child: yours),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _play(
    BuildContext context,
    WidgetRef ref,
    List<TrackRecord> tracks, {
    bool shuffle = false,
    String? label,
  }) async {
    final ordered = [...tracks];
    if (shuffle) ordered.shuffle();
    final note = await playTracks(
      ref,
      tracks: ordered,
      contextLabel: label ?? 'Library',
    );
    if (shuffle) {
      await ref.read(playerProvider).setShuffle(true);
    }
    if (!context.mounted) return;
    showNote(context, note);
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: 12,
          color: AppColors.ivory,
        ),
      ),
    );
  }
}

class _QuickPicks extends ConsumerWidget {
  const _QuickPicks({required this.catalog, required this.tracks});

  final LibraryIndex catalog;
  final List<TrackRecord> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frosted = ref.watch(settingsProvider).frostedGlass;
    return GlassSurface(
      frosted: frosted,
      radius: 18,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Eyebrow('QUICK PICK'),
                  GlassActionButton(
                    label: 'View all ${formatInt(catalog.tracks.length)} songs',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () =>
                        ref.read(navProvider.notifier).go(ShellSection.songs),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (tracks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('The catalog has no tracks yet.'),
              )
            else
              for (var index = 0; index < tracks.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: TrackRow(
                    track: tracks[index],
                    number: index + 1,
                    onPlay: () =>
                        unawaited(_playFrom(context, ref, tracks, index)),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _playFrom(
    BuildContext context,
    WidgetRef ref,
    List<TrackRecord> tracks,
    int index,
  ) async {
    final note = await playTracks(
      ref,
      tracks: tracks,
      index: index,
      contextLabel: 'Quick pick',
    );
    if (!context.mounted) return;
    showNote(context, note);
  }
}

class _YourPlaylists extends ConsumerWidget {
  const _YourPlaylists();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frosted = ref.watch(settingsProvider).frostedGlass;
    final items =
        ref.watch(userLibraryProvider).valueOrNull?.playlists ?? const [];
    return GlassSurface(
      frosted: frosted,
      radius: 18,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('YOUR PLAYLISTS'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PrimaryActionPill(
                  label: 'New playlist',
                  icon: Icons.add_rounded,
                  onPressed: () => unawaited(createUserPlaylist(context, ref)),
                ),
                GlassActionButton(
                  label: 'Import JSON',
                  icon: Icons.file_download_outlined,
                  onPressed: () => unawaited(importUserLibrary(context, ref)),
                ),
                GlassActionButton(
                  label: 'Export JSON',
                  icon: Icons.file_upload_outlined,
                  onPressed: () => unawaited(exportUserLibrary(context, ref)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No custom playlists yet.'),
              )
            else
              for (var index = 0; index < items.length; index++)
                _UserPlaylistRow(index: index, length: items.length),
          ],
        ),
      ),
    );
  }
}

class _UserPlaylistRow extends ConsumerWidget {
  const _UserPlaylistRow({required this.index, required this.length});

  final int index;
  final int length;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlist = ref
        .watch(userLibraryProvider)
        .valueOrNull
        ?.playlists[index];
    if (playlist == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: ListTile(
          onTap: () => ref
              .read(navProvider.notifier)
              .openPlaylist(playlist.id, custom: true),
          title: Text(playlist.name),
          subtitle: Text(
            '${playlist.trackIds.length} tracks',
            style: AppTheme.tabular.copyWith(fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Move up',
                onPressed: index == 0
                    ? null
                    : () => unawaited(
                        ref
                            .read(userLibraryProvider.notifier)
                            .mutate(
                              (current) =>
                                  current.reorderPlaylists(index, index - 1),
                            ),
                      ),
                icon: const Icon(Icons.arrow_upward, size: 18),
              ),
              IconButton(
                tooltip: 'Move down',
                onPressed: index >= length - 1
                    ? null
                    : () => unawaited(
                        ref
                            .read(userLibraryProvider.notifier)
                            .mutate(
                              (current) =>
                                  current.reorderPlaylists(index, index + 1),
                            ),
                      ),
                icon: const Icon(Icons.arrow_downward, size: 18),
              ),
              PopupMenuButton<String>(
                onSelected: (value) => unawaited(
                  _menu(context, ref, value, playlist.id, playlist.name),
                ),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _menu(
    BuildContext context,
    WidgetRef ref,
    String value,
    String id,
    String name,
  ) async {
    if (value == 'rename') {
      final next = await promptText(
        context,
        title: 'Rename playlist',
        initial: name,
      );
      if (next == null || next.trim().isEmpty) return;
      await ref
          .read(userLibraryProvider.notifier)
          .mutate((current) => current.renamePlaylist(id, next));
      return;
    }
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete playlist'),
        content: Text('Delete “$name”? The audio files stay where they are.'),
        actions: [
          GlassActionButton(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context, false),
          ),
          PrimaryActionPill(
            label: 'Delete',
            icon: Icons.delete_outline_rounded,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(userLibraryProvider.notifier)
        .mutate((current) => current.deletePlaylist(id));
  }
}
