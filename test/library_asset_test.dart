import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xerno_music/src/models/library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses the bundled Xernover catalog', () async {
    final raw = await rootBundle.loadString('assets/library.json');
    final index = LibraryIndex(parseManifestString(raw));
    expect(index.manifest.schemaVersion, '1.0.0');
    expect(index.manifest.owner, 'Xernover');
    expect(index.manifest.playlists.map((playlist) => playlist.slug).toList(), [
      'liked_1_80',
      'illit_osszes',
      'ocsem_random',
      'kanye_west_bangers',
    ]);
    expect(index.tracks, hasLength(623));
    expect(index.byId, hasLength(623));
    expect(index.playlistById('liked_1_80')!.trackCount, 80);
    expect(index.playlistById('illit_osszes')!.trackCount, 38);
    expect(index.playlistById('illit_osszes')!.trackIds, hasLength(38));
    expect(index.playlistById('illit_osszes')!.status, 'complete');
    expect(index.playlistById('illit_osszes')!.name, 'ILLIT összes');
    expect(index.playlistById('kanye_west_bangers')!.name, contains('KANYE'));
    expect(index.playlistById('kanye_west_bangers')!.trackCount, 448);
    expect(index.playlistById('ocsem_random')!.trackCount, 74);
    final artists = index.listedArtists();
    expect(artists.first.name, 'Kanye West');
    expect(artists.first.trackCount, 393);
    expect(
      artists.take(7).map((group) => group.name),
      containsAll(['Ye', 'ILLIT', 'JAŸ-Z', 'Ado', 'Joost']),
    );
    expect(
      artists.take(12).map((group) => group.name),
      isNot(contains('88-Keys')),
    );
    expect(index.creditArtistCount, 285);
    expect(
      index.listedArtists(mainOnly: false).map((group) => group.name),
      contains('88-Keys'),
    );
    for (final playlist in index.manifest.playlists) {
      expect(playlist.status, 'complete');
      for (final id in playlist.trackIds) {
        expect(index.byId.containsKey(id), isTrue, reason: id);
      }
    }
    for (final track in index.tracks) {
      final url = track.file.ziplineUrl;
      expect(url, isNotNull, reason: track.id);
      expect(
        url,
        startsWith('https://cloud.mucsarocsoge.online/'),
        reason: track.id,
      );
    }
  });
}
