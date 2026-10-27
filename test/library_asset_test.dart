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
    expect(index.tracks, hasLength(585));
    expect(index.playlistById('liked_1_80')!.trackCount, 80);
    expect(index.playlistById('illit_osszes')!.trackIds, isEmpty);
    expect(index.playlistById('illit_osszes')!.name, 'ILLIT összes');
    expect(index.playlistById('kanye_west_bangers')!.name, contains('KANYE'));
    expect(index.playlistById('ocsem_random')!.trackCount, 74);
    for (final playlist in index.manifest.playlists) {
      for (final id in playlist.trackIds) {
        expect(index.byId.containsKey(id), isTrue, reason: id);
      }
    }
  });
}
