import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../format.dart';
import '../models/library.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import 'playlist_io.dart';
import 'widgets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({required this.catalog, super.key});

  final LibraryIndex catalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userLibraryProvider).valueOrNull;
    final playlists = user?.playlists ?? const [];
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1200
        ? 4
        : width >= 800
        ? 2
        : 1;
    final stats = catalog.manifest.stats;
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 36),
      children: [
        const Eyebrow('ON THE GO'),
        const SizedBox(height: 10),
        Text('Xerno', style: Theme.of(context).textTheme.displayLarge),
        const SizedBox(height: 10),
        Text(
          '${catalog.manifest.owner.isEmpty ? 'Library' : catalog.manifest.owner}  ·  ${formatInt(stats.uniqueTracks)} tracks  ·  ${formatInt(stats.totalPlaylists)} playlists',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.sage),
        ),
        const SizedBox(height: 22),
        TextField(
          decoration: xernoField(
            'Search the library',
            hint: 'Title, artist, album, year',
          ),
          onSubmitted: (value) => ref.read(navProvider.notifier).search(value),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Link(
              label: 'All songs',
              onTap: () =>
                  ref.read(navProvider.notifier).go(ShellSection.songs),
            ),
            _Link(
              label: 'Artists',
              onTap: () =>
                  ref.read(navProvider.notifier).go(ShellSection.artists),
            ),
            _Link(
              label: 'Albums',
              onTap: () =>
                  ref.read(navProvider.notifier).go(ShellSection.albums),
            ),
            _Link(
              label:
                  'Favorites ${user == null ? '' : formatInt(user.favorites.length)}',
              onTap: () =>
                  ref.read(navProvider.notifier).go(ShellSection.favorites),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const Eyebrow('PREMADE'),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: catalog.manifest.playlists.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 280,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemBuilder: (context, index) {
            final playlist = catalog.manifest.playlists[index];
            return PlaylistCard(
              playlist: playlist,
              onTap: () =>
                  ref.read(navProvider.notifier).openPlaylist(playlist.slug),
            );
          },
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            const Expanded(child: Eyebrow('YOUR PLAYLISTS')),
            TextButton(
              onPressed: () => unawaited(_create(context, ref)),
              child: const Text('New'),
            ),
            TextButton(
              onPressed: () => unawaited(importUserLibrary(context, ref)),
              child: const Text('Import'),
            ),
            TextButton(
              onPressed: () => unawaited(exportUserLibrary(context, ref)),
              child: const Text('Export'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (playlists.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No custom playlists yet.'),
          )
        else
          for (var index = 0; index < playlists.length; index++)
            _UserPlaylistRow(index: index, length: playlists.length),
      ],
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await promptText(
      context,
      title: 'New playlist',
      confirm: 'Create',
    );
    if (!context.mounted || name == null || name.trim().isEmpty) return;
    await ref
        .read(userLibraryProvider.notifier)
        .mutate((current) => current.addPlaylist(name));
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ivory,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
      ),
      child: Text(label),
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
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
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
