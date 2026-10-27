import '../models/track.dart';

enum TrackSort { position, title, artist, album, year, duration, popularity }

const trackSortLabels = <TrackSort, String>{
  TrackSort.position: 'Position',
  TrackSort.title: 'Title',
  TrackSort.artist: 'Artist',
  TrackSort.album: 'Album',
  TrackSort.year: 'Year',
  TrackSort.duration: 'Duration',
  TrackSort.popularity: 'Popularity',
};

List<TrackRecord> filterTracks(List<TrackRecord> tracks, String query) {
  final terms = query
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((term) => term.isNotEmpty)
      .toList();
  if (terms.isEmpty) return tracks;
  return tracks.where((track) {
    final haystack = [
      track.title,
      track.artist,
      track.artists.join(' '),
      track.album,
      track.albumArtist,
      track.year?.toString() ?? '',
      if (track.explicit) 'explicit',
    ].join(' ').toLowerCase();
    return terms.every(haystack.contains);
  }).toList();
}

List<TrackRecord> sortTracks(
  List<TrackRecord> input,
  TrackSort sort, {
  required bool ascending,
  Map<String, int>? positions,
}) {
  final list = List<TrackRecord>.of(input);
  list.sort((a, b) {
    if (sort == TrackSort.year) {
      return _nullsLast(a.year, b.year, ascending: ascending, tie: _tie(a, b));
    }
    final primary = switch (sort) {
      TrackSort.position => _position(
        a,
        positions,
      ).compareTo(_position(b, positions)),
      TrackSort.title => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      TrackSort.artist => a.artist.toLowerCase().compareTo(
        b.artist.toLowerCase(),
      ),
      TrackSort.album => a.album.toLowerCase().compareTo(b.album.toLowerCase()),
      TrackSort.duration => a.durationSec.compareTo(b.durationSec),
      TrackSort.popularity => a.popularity.compareTo(b.popularity),
      TrackSort.year => 0,
    };
    if (primary != 0) return ascending ? primary : -primary;
    return _tie(a, b);
  });
  return list;
}

int _position(TrackRecord track, Map<String, int>? positions) {
  return positions?[track.id] ?? track.file.position;
}

int _tie(TrackRecord a, TrackRecord b) {
  final title = a.title.toLowerCase().compareTo(b.title.toLowerCase());
  if (title != 0) return title;
  return a.id.compareTo(b.id);
}

int _nullsLast(int? a, int? b, {required bool ascending, required int tie}) {
  if (a == null && b == null) return tie;
  if (a == null) return 1;
  if (b == null) return -1;
  final compared = a.compareTo(b);
  if (compared == 0) return tie;
  return ascending ? compared : -compared;
}
