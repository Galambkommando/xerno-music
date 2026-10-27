import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xerno_music/app.dart';
import 'package:xerno_music/src/models/library.dart';
import 'package:xerno_music/src/models/settings.dart';
import 'package:xerno_music/src/models/track.dart';
import 'package:xerno_music/src/player/playback.dart';
import 'package:xerno_music/src/state/providers.dart';

LibraryIndex fixtureCatalog() {
  return LibraryIndex(
    const LibraryManifest(
      owner: 'Xernover',
      playlists: [
        PlaylistSummary(
          id: 'liked',
          slug: 'liked_1_80',
          name: 'Liked Songs (Top 1–80)',
          status: 'complete',
          trackCount: 1,
          trackIds: ['t1'],
        ),
        PlaylistSummary(
          id: 'illit',
          slug: 'illit_osszes',
          name: 'ILLIT összes',
          status: 'pending_browser_extraction',
        ),
      ],
      tracks: [
        TrackRecord(
          id: 't1',
          title: 'Forest Line',
          artist: 'Sample Artist',
          album: 'Night Pine',
          durationSec: 180,
          durationFormatted: '3:00',
          year: 2024,
        ),
      ],
    ),
  );
}

Future<void> pumpApp(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialSettingsProvider.overrideWithValue(
          AppSettings(deviceId: 'test-device'),
        ),
        playerProvider.overrideWithValue(ManualPlayback()),
        librarySeedProvider.overrideWithValue(fixtureCatalog()),
      ],
      child: const XernoApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('desktop home opens a premade playlist', (tester) async {
    await pumpApp(tester, const Size(1440, 900));
    expect(find.text('Xerno'), findsWidgets);
    expect(find.textContaining('Liked Songs'), findsOneWidget);
    await tester.tap(find.textContaining('ILLIT'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing matches this view yet.'), findsOneWidget);
  });

  testWidgets('phone home keeps the masthead', (tester) async {
    await pumpApp(tester, const Size(390, 844));
    expect(find.text('Xerno'), findsOneWidget);
    expect(find.textContaining('Liked Songs'), findsOneWidget);
  });
}
