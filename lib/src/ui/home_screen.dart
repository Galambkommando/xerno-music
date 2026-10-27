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

Future<void> playCatalog(
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

class HomeScreen extends ConsumerWidget {
  const HomeScreen({required this.catalog, super.key});

  final LibraryIndex catalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frosted = ref.watch(settingsProvider).frostedGlass;
    final ranked = [...catalog.tracks]
      ..sort((a, b) => b.popularity.compareTo(a.popularity));
    final featured = ranked.take(12).toList();
    final artists = catalog.listedArtists().take(8).toList();
    final phone = MediaQuery.sizeOf(context).width < 900;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 148),
      children: [
        if (phone)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Xerno',
              style: TextStyle(
                fontFamily: 'Newsreader',
                fontSize: 28,
                height: 1,
                color: AppColors.ivory,
              ),
            ),
          ),
        _HomeToolbar(catalog: catalog),
        const SizedBox(height: 18),
        const Eyebrow('YOUR COLLECTIONS'),
        const SizedBox(height: 10),
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
                childAspectRatio: columns == 1 ? 1.15 : 0.78,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
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
                          playCatalog(
                            context,
                            ref,
                            tracks,
                            label: playlist.name,
                          ),
                        ),
                );
              },
            );
          },
        ),
        if (artists.isNotEmpty) ...[
          const SizedBox(height: 22),
          const Eyebrow('TOP ARTISTS'),
          const SizedBox(height: 10),
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: artists.length,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final artist = artists[index];
                return _ArtistChip(
                  name: artist.name,
                  count: artist.trackCount,
                  coverUrl: artist.coverUrl,
                  onTap: () =>
                      ref.read(navProvider.notifier).openArtist(artist.name),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 22),
        _QuickPicks(catalog: catalog, tracks: featured),
        const SizedBox(height: 14),
        const _YourPlaylists(),
      ],
    );
  }
}

class _HomeToolbar extends ConsumerWidget {
  const _HomeToolbar({required this.catalog});

  final LibraryIndex catalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nav = ref.read(navProvider.notifier);
    return LayoutBuilder(
      builder: (context, constraints) {
        final search = TextField(
          decoration: xernoField('Search songs, artists, albums...')
              .copyWith(prefixIcon: const Icon(Icons.search_rounded)),
          onSubmitted: (value) => nav.search(value),
        );
        final filters = Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            GlassActionButton(
              label: 'All songs',
              icon: Icons.library_music_rounded,
              onPressed: () => nav.go(ShellSection.songs),
            ),
            GlassActionButton(
              label: 'Artists',
              icon: Icons.person_rounded,
              onPressed: () => nav.go(ShellSection.artists),
            ),
            GlassActionButton(
              label: 'Albums',
              icon: Icons.album_rounded,
              onPressed: () => nav.go(ShellSection.albums),
            ),
            GlassActionButton(
              label: 'Favorites',
              icon: Icons.favorite_rounded,
              onPressed: () => nav.go(ShellSection.favorites),
            ),
            PrimaryActionPill(
              label: 'Play all',
              icon: Icons.play_arrow_rounded,
              onPressed: catalog.tracks.isEmpty
                  ? null
                  : () => unawaited(playCatalog(context, ref, catalog.tracks)),
            ),
            GlassActionButton(
              label: 'Shuffle',
              icon: Icons.shuffle_rounded,
              onPressed: catalog.tracks.isEmpty
                  ? null
                  : () => unawaited(
                      playCatalog(context, ref, catalog.tracks, shuffle: true),
                    ),
            ),
          ],
        );
        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [search, const SizedBox(height: 10), filters],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: search),
            const SizedBox(width: 12),
            Flexible(flex: 3, child: filters),
          ],
        );
      },
    );
  }
}

class _ArtistChip extends StatelessWidget {
  const _ArtistChip({
    required this.name,
    required this.count,
    required this.onTap,
    this.coverUrl,
  });

  final String name;
  final int count;
  final String? coverUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 84,
        child: Column(
          children: [
            ClipOval(child: CoverImage(url: coverUrl, size: 72, radius: 36)),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: AppColors.ivory,
              ),
            ),
            Text('$count', style: Theme.of(context).textTheme.bodySmall),
          ],
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
                  const Eyebrow('FEATURED TRACKS'),
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
              LayoutBuilder(
                builder: (context, constraints) {
                  Widget row(int index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: TrackRow(
                        track: tracks[index],
                        number: index + 1,
                        onPlay: () =>
                            unawaited(_playFrom(context, ref, tracks, index)),
                      ),
                    );
                  }

                  if (constraints.maxWidth < 760) {
                    return Column(
                      children: [
                        for (var i = 0; i < tracks.length; i++) row(i),
                      ],
                    );
                  }
                  final pairs = <Widget>[];
                  for (var i = 0; i < tracks.length; i += 2) {
                    pairs.add(
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: row(i)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: i + 1 < tracks.length
                                ? row(i + 1)
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    );
                  }
                  return Column(children: pairs);
                },
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
