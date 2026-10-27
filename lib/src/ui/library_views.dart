import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/library.dart';
import '../models/track.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import 'playback_actions.dart';
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
            ? _ArtistIndex(catalog: catalog)
            : _artistTracks(ref, nav.artist!),
      ShellSection.albums =>
        nav.albumKey == null
            ? _AlbumIndex(catalog: catalog)
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

class _ArtistIndex extends ConsumerStatefulWidget {
  const _ArtistIndex({required this.catalog});

  final LibraryIndex catalog;

  @override
  ConsumerState<_ArtistIndex> createState() => _ArtistIndexState();
}

class _ArtistIndexState extends ConsumerState<_ArtistIndex> {
  final _query = TextEditingController();
  bool _mainOnly = true;
  bool _alphabetical = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.catalog.listedArtists(
      mainOnly: _mainOnly,
      alphabetical: _alphabetical,
      query: _query.text,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('LIBRARY'),
              const SizedBox(height: 6),
              Text(
                'Artists',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _query,
                decoration: xernoField('Filter artists'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterPill(
                    label: 'Main artists',
                    selected: _mainOnly,
                    onTap: () => setState(() => _mainOnly = true),
                  ),
                  _FilterPill(
                    label: 'All credits (${widget.catalog.creditArtistCount})',
                    selected: !_mainOnly,
                    onTap: () => setState(() => _mainOnly = false),
                  ),
                  _FilterPill(
                    label: 'Most tracks',
                    selected: !_alphabetical,
                    onTap: () => setState(() => _alphabetical = false),
                  ),
                  _FilterPill(
                    label: 'A–Z',
                    selected: _alphabetical,
                    onTap: () => setState(() => _alphabetical = true),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: groups.isEmpty
              ? const Center(child: Text('No artists in this catalog yet.'))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 148),
                  itemCount: groups.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _columns(context),
                    mainAxisExtent: 168,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return _ArtistCard(
                      group: group,
                      onOpen: () =>
                          ref.read(navProvider.notifier).openArtist(group.name),
                      onPlay: () {
                        final tracks = widget.catalog.byArtist(group.name);
                        if (tracks.isEmpty) return;
                        unawaited(
                          playTracks(
                            ref,
                            tracks: tracks,
                            contextLabel: group.name,
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AlbumIndex extends ConsumerStatefulWidget {
  const _AlbumIndex({required this.catalog});

  final LibraryIndex catalog;

  @override
  ConsumerState<_AlbumIndex> createState() => _AlbumIndexState();
}

class _AlbumIndexState extends ConsumerState<_AlbumIndex> {
  final _query = TextEditingController();
  AlbumOrder _order = AlbumOrder.tracks;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.catalog.listedAlbums(
      order: _order,
      query: _query.text,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('LIBRARY'),
              const SizedBox(height: 6),
              Text('Albums', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 10),
              TextField(
                controller: _query,
                decoration: xernoField('Filter albums'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterPill(
                    label: 'Most tracks',
                    selected: _order == AlbumOrder.tracks,
                    onTap: () => setState(() => _order = AlbumOrder.tracks),
                  ),
                  _FilterPill(
                    label: 'Newest',
                    selected: _order == AlbumOrder.newest,
                    onTap: () => setState(() => _order = AlbumOrder.newest),
                  ),
                  _FilterPill(
                    label: 'A–Z',
                    selected: _order == AlbumOrder.name,
                    onTap: () => setState(() => _order = AlbumOrder.name),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: groups.isEmpty
              ? const Center(child: Text('No albums in this catalog yet.'))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 148),
                  itemCount: groups.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _columns(context),
                    mainAxisExtent: 168,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return _AlbumCard(
                      group: group,
                      onOpen: () =>
                          ref.read(navProvider.notifier).openAlbum(group.key),
                      onPlay: () {
                        final tracks = widget.catalog.byAlbum(group.key);
                        if (tracks.isEmpty) return;
                        unawaited(
                          playTracks(
                            ref,
                            tracks: tracks,
                            contextLabel: group.title,
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.55)
              : const Color(0xFF151F1A),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected
                ? AppColors.mint.withValues(alpha: 0.7)
                : const Color(0xFF23332B),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.ivory : AppColors.sage,
          ),
        ),
      ),
    );
  }
}

class _ArtistCard extends StatelessWidget {
  const _ArtistCard({
    required this.group,
    required this.onOpen,
    required this.onPlay,
  });

  final ArtistGroup group;
  final VoidCallback onOpen;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF151F1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF23332B)),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipOval(
                    child: CoverImage(
                      url: group.coverUrl,
                      size: 72,
                      radius: 36,
                    ),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: _RoundPlay(onPressed: onPlay),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                group.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w700,
                  color: AppColors.ivory,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${group.trackCount} tracks · ${group.albumCount} albums',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({
    required this.group,
    required this.onOpen,
    required this.onPlay,
  });

  final AlbumGroup group;
  final VoidCallback onOpen;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final meta = [
      group.artist,
      if (group.year != null) '${group.year}',
      '${group.trackCount} tracks',
    ].join(' · ');
    return Material(
      color: const Color(0xFF151F1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF23332B)),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CoverImage(url: group.coverUrl, size: 84, radius: 12),
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: _RoundPlay(onPressed: onPlay),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w700,
                        color: AppColors.ivory,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      maxLines: 2,
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

class _RoundPlay extends StatelessWidget {
  const _RoundPlay({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accent,
      shape: const CircleBorder(side: BorderSide(color: AppColors.mint)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: const SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            Icons.play_arrow_rounded,
            color: AppColors.ivory,
            size: 18,
          ),
        ),
      ),
    );
  }
}

int _columns(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 1400) return 4;
  if (width >= 1100) return 3;
  if (width >= 720) return 2;
  return 1;
}
