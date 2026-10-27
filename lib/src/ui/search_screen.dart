import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/library.dart';
import '../state/providers.dart';
import 'widgets.dart';

class SearchScreen extends ConsumerWidget {
  const SearchScreen({required this.catalog, super.key});

  final LibraryIndex catalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(navProvider).query;
    return TrackBrowser(
      tracks: catalog.tracks,
      title: 'Search',
      eyebrow: 'FIND',
      subtitle: 'Title, artist, album, or year',
      initialQuery: query,
    );
  }
}
