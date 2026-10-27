import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../format.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import 'playback_actions.dart';
import 'widgets.dart';

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  Future<int>? _bytes;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_prepare);
  }

  Future<void> _prepare() async {
    final manager = ref.read(downloadManagerProvider);
    await manager.ensureLoaded();
    if (!mounted) return;
    setState(() => _bytes = manager.pinnedBytes());
  }

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(downloadManagerProvider);
    final catalog = ref.watch(libraryProvider).valueOrNull;
    final ids = manager.pinnedIds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('OFFLINE'),
              const SizedBox(height: 8),
              Text('Pinned', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                manager.message ?? '320 kbps copies stored with the app.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              FutureBuilder<int>(
                future: _bytes,
                builder: (context, snapshot) {
                  final bytes = snapshot.data;
                  final size = bytes == null
                      ? ''
                      : '  ·  ${formatBytes(bytes)}';
                  return Text(
                    '${formatInt(ids.length)} pinned$size',
                    style: AppTheme.tabular,
                  );
                },
              ),
              if (manager.batchTotal > 0 && manager.activeId != null) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: manager.batchTotal == 0
                      ? null
                      : manager.batchDone / manager.batchTotal,
                  color: AppColors.mint,
                  backgroundColor: AppColors.border,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: manager.requestCancel,
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ids.isEmpty
              ? const Center(
                  child: Text(
                    'Nothing is pinned yet. Pin a track or a whole playlist.',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: ids.length,
                  itemBuilder: (context, index) {
                    final id = ids[index];
                    final track = catalog?.byId[id];
                    final progress = manager.progress[id];
                    return ListTile(
                      leading: CoverImage(
                        url: track?.coverUrl,
                        size: 42,
                        radius: 8,
                      ),
                      title: Text(
                        track?.title ?? id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: progress == null
                          ? Text(
                              track?.displayArtist ?? 'Pinned',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : LinearProgressIndicator(
                              value: progress == 0 ? null : progress,
                              color: AppColors.mint,
                              backgroundColor: AppColors.border,
                            ),
                      trailing: IconButton(
                        tooltip: 'Remove pin',
                        onPressed: () async {
                          await manager.unpin(id);
                          if (!mounted) return;
                          setState(() => _bytes = manager.pinnedBytes());
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                      ),
                      onTap: track == null
                          ? null
                          : () async {
                              final note = await playTracks(
                                ref,
                                tracks: [
                                  for (final pinned in ids)
                                    if (catalog?.byId[pinned] != null)
                                      catalog!.byId[pinned]!,
                                ],
                                index: index,
                                contextLabel: 'Pinned',
                              );
                              if (!context.mounted) return;
                              showNote(context, note);
                            },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
