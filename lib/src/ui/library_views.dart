import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/library.dart';
import '../models/track.dart';
import '../state/providers.dart';
import 'widgets.dart';

class LibraryViews extends ConsumerWidget {
  const LibraryViews({required this.catalog, super.key});

  final LibraryIndex catalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nav = ref.watch(navProvider);
    return switch (nav.section) {
      ShellSection.songs => TrackBrowser(
        tracks: catalog.tracks,
        title: 'All songs',
        eyebrow: 'LIBRARY',
        subtitle: '${catalog.tracks.length} tracks in the open catalog',
      ),
      ShellSection.favorites => _favorites(ref),
      ShellSection.playlist => _playlist(ref, nav),
      ShellSection.artists =>
        nav.artist == null
            ? _ArtistIndex(groups: catalog.artists)
            : _artistTracks(ref, nav.artist!),
      ShellSection.albums =>
        nav.albumKey == null
            ? _AlbumIndex(groups: catalog.albums)
            : _albumTracks(ref, nav.albumKey!),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _favorites(WidgetRef ref) {
    final ids =
        ref.watch(userLibraryProvider).valueOrNull?.favorites ??
        const <String>[];
    final tracks = _resolve(ids);
    return TrackBrowser(
      tracks: tracks,
      title: 'Favorites',
      eyebrow: 'HEART',
      subtitle: 'Tracks you marked on this device',
      onPinAll: () => _pin(ref, tracks),
    );
  }

  Widget _playlist(WidgetRef ref, NavState nav) {
    if (nav.customPlaylist) {
      final data = ref.watch(userLibraryProvider).valueOrNull;
      final playlist = data?.playlists
          .where((item) => item.id == nav.playlistId)
          .firstOrNull;
      if (playlist == null) {
        return const Center(child: Text('That playlist is no longer here.'));
      }
      final tracks = _resolve(playlist.trackIds);
      return TrackBrowser(
        tracks: tracks,
        title: playlist.name,
        eyebrow: 'PLAYLIST',
        customPlaylistId: playlist.id,
        onPinAll: () => _pin(ref, tracks),
      );
    }
    final playlist = nav.playlistId == null
        ? null
        : catalog.playlistById(nav.playlistId!);
    if (playlist == null) {
      return const Center(
        child: Text('That playlist is not in the open catalog.'),
      );
    }
    final tracks = catalog.tracksFor(playlist);
    return TrackBrowser(
      tracks: tracks,
      title: playlist.name,
      eyebrow: playlist.statusLabel.toUpperCase(),
      subtitle: playlist.description.isEmpty
          ? '${playlist.authorName}  ·  ${playlist.trackCount} tracks'
          : playlist.description,
      coverUrl: playlist.coverUrl,
      positions: catalog.positionsFor(playlist),
      contextLabel: playlist.name,
      onPinAll: () => _pin(ref, tracks),
    );
  }

  Widget _artistTracks(WidgetRef ref, String name) {
    final tracks = catalog.byArtist(name);
    return TrackBrowser(
      tracks: tracks,
      title: name,
      eyebrow: 'ARTIST',
      coverUrl: tracks.isEmpty ? null : tracks.first.coverUrl,
      onPinAll: () => _pin(ref, tracks),
      trailing: GlassActionButton(
        label: 'All artists',
        icon: Icons.arrow_back_rounded,
        onPressed: () =>
            ref.read(navProvider.notifier).go(ShellSection.artists),
      ),
    );
  }

  Widget _albumTracks(WidgetRef ref, String key) {
    final tracks = catalog.byAlbum(key);
    final title = tracks.isEmpty ? 'Album' : tracks.first.album;
    final artist = tracks.isEmpty ? '' : tracks.first.albumArtist;
    return TrackBrowser(
      tracks: tracks,
      title: title.isEmpty ? 'Album' : title,
      eyebrow: 'ALBUM',
      subtitle: artist,
      coverUrl: tracks.isEmpty ? null : tracks.first.coverUrl,
      onPinAll: () => _pin(ref, tracks),
      trailing: GlassActionButton(
        label: 'All albums',
        icon: Icons.arrow_back_rounded,
        onPressed: () => ref.read(navProvider.notifier).go(ShellSection.albums),
      ),
    );
  }

  List<TrackRecord> _resolve(List<String> ids) {
    final tracks = <TrackRecord>[];
    for (final id in ids) {
      final track = catalog.byId[id];
      if (track != null) tracks.add(track);
    }
    return tracks;
  }

  void _pin(WidgetRef ref, List<TrackRecord> tracks) {
    final settings = ref.read(settingsProvider);
    unawaited(ref.read(downloadManagerProvider).pinTracks(tracks, settings));
    ref.read(navProvider.notifier).go(ShellSection.downloads);
  }
}

class _ArtistIndex extends ConsumerWidget {
  const _ArtistIndex({required this.groups});

  final List<ArtistGroup> groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('LIBRARY'),
              const SizedBox(height: 8),
              Text(
                'Artists',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
        Expanded(
          child: groups.isEmpty
              ? const Center(child: Text('No artists in this catalog yet.'))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 148),
                  itemCount: groups.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _columns(context),
                    mainAxisExtent: 92,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return _IndexCard(
                      title: group.name,
                      subtitle: '${group.trackCount} tracks',
                      coverUrl: group.coverUrl,
                      onTap: () =>
                          ref.read(navProvider.notifier).openArtist(group.name),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AlbumIndex extends ConsumerWidget {
  const _AlbumIndex({required this.groups});

  final List<AlbumGroup> groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('LIBRARY'),
              const SizedBox(height: 8),
              Text('Albums', style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
        ),
        Expanded(
          child: groups.isEmpty
              ? const Center(child: Text('No albums in this catalog yet.'))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 148),
                  itemCount: groups.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _columns(context),
                    mainAxisExtent: 92,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return _IndexCard(
                      title: group.title,
                      subtitle:
                          '${group.artist}${group.year == null ? '' : '  ·  ${group.year}'}',
                      coverUrl: group.coverUrl,
                      onTap: () =>
                          ref.read(navProvider.notifier).openAlbum(group.key),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _IndexCard extends ConsumerWidget {
  const _IndexCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.coverUrl,
  });

  final String title;
  final String subtitle;
  final String? coverUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frosted = ref.watch(settingsProvider).frostedGlass;
    return GlassSurface(
      frosted: frosted,
      radius: 14,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              CoverImage(url: coverUrl, size: 64, radius: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

int _columns(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 1400) return 3;
  if (width >= 900) return 2;
  return 1;
}
