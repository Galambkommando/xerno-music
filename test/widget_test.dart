import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xerno_music/app.dart';
import 'package:xerno_music/src/constants.dart';
import 'package:xerno_music/src/logic/lrc.dart';
import 'package:xerno_music/src/models/library.dart';
import 'package:xerno_music/src/models/settings.dart';
import 'package:xerno_music/src/models/track.dart';
import 'package:xerno_music/src/player/playback.dart';
import 'package:xerno_music/src/state/providers.dart';
import 'package:xerno_music/src/ui/now_playing.dart';
import 'package:xerno_music/src/ui/shell.dart';
import 'package:xerno_music/src/ui/widgets.dart';

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
          artists: ['Sample Artist', 'Guest One'],
          albumArtist: 'Sample Artist',
          album: 'Night Pine',
          durationSec: 180,
          durationFormatted: '3:00',
          year: 2024,
          file: TrackFile(
            ziplineUrl: 'https://cloud.mucsarocsoge.online/u/forest.mp3',
          ),
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
    expect(find.textContaining('Liked Songs'), findsWidgets);
    expect(find.text('Ready to play'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(PlaylistCard),
        matching: find.textContaining('ILLIT'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nothing matches this view yet.'), findsOneWidget);
  });

  testWidgets('a missing playback engine stays on screen', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialSettingsProvider.overrideWithValue(
            AppSettings(deviceId: 'test-device'),
          ),
          playerProvider.overrideWithValue(
            ManualPlayback(failure: kMissingLibmpvMessage),
          ),
          librarySeedProvider.overrideWithValue(fixtureCatalog()),
        ],
        child: const XernoApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Xerno'), findsWidgets);
    expect(find.text(kMissingLibmpvMessage), findsOneWidget);
    expect(find.textContaining('Liked Songs'), findsWidgets);
    expect(find.text('Ready to play'), findsOneWidget);
  });

  testWidgets('phone home keeps the masthead', (tester) async {
    await pumpApp(tester, const Size(390, 844));
    expect(find.text('Xerno'), findsOneWidget);
    expect(find.textContaining('Liked Songs'), findsOneWidget);
    expect(find.text('Ready to play'), findsOneWidget);
  });

  testWidgets('expand leaves mini player mode', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialSettingsProvider.overrideWithValue(
            AppSettings(deviceId: 'test-device', miniPlayer: true),
          ),
          playerProvider.overrideWithValue(ManualPlayback()),
          librarySeedProvider.overrideWithValue(fixtureCatalog()),
        ],
        child: const XernoApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Expand to full window'), findsOneWidget);
    expect(find.text('Expand'), findsOneWidget);
    expect(find.text('Ready to play'), findsNothing);
    await tester.tap(find.byTooltip('Expand to full window'));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(XernoShell));
    expect(
      ProviderScope.containerOf(context).read(settingsProvider).miniPlayer,
      isFalse,
    );
    expect(find.textContaining('Liked Songs'), findsWidgets);
    expect(find.text('Ready to play'), findsOneWidget);
  });

  testWidgets('track menu copies the server link', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final track = fixtureCatalog().tracks.single;
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final arguments = call.arguments;
          if (arguments is Map) copied = arguments['text'] as String?;
          return null;
        }
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': copied};
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialSettingsProvider.overrideWithValue(
            AppSettings(deviceId: 'test-device'),
          ),
          playerProvider.overrideWithValue(ManualPlayback()),
          librarySeedProvider.overrideWithValue(fixtureCatalog()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TrackRow(track: track, number: 1, onPlay: () {}),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Track actions'));
    await tester.pump();
    expect(find.text('Server link (RöcsögeCloud)'), findsOneWidget);
    await tester.tap(find.text('Server link (RöcsögeCloud)').hitTestable());
    await tester.pump();
    expect(copied, 'https://cloud.mucsarocsoge.online/u/forest.mp3');
    expect(find.textContaining('Copied server link:'), findsOneWidget);
  });

  testWidgets('spicy lyrics seeks the tapped line', (tester) async {
    final playback = ManualPlayback();
    final playable = Playable(
      id: 't1',
      title: 'Forest Line',
      artist: 'Sample Artist',
      album: 'Night Pine',
      duration: const Duration(seconds: 180),
      uri: Uri.parse('https://cloud.mucsarocsoge.online/u/forest.mp3'),
      sourceLabel: 'Cloud',
    );
    await playback.playAll(
      [playable],
      autoplay: false,
      position: const Duration(seconds: 2),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialSettingsProvider.overrideWithValue(
            AppSettings(deviceId: 'test-device'),
          ),
          playerProvider.overrideWithValue(playback),
          librarySeedProvider.overrideWithValue(fixtureCatalog()),
          lyricsProvider.overrideWith(
            (ref, id) async => const Lyrics(
              synced: [
                LyricLine(Duration(seconds: 1), 'Open the pine'),
                LyricLine(Duration(seconds: 12), 'Second line stays dim'),
              ],
            ),
          ),
        ],
        child: const MaterialApp(home: NowPlayingScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Split View'), findsOneWidget);
    expect(find.text('Focus Lyrics'), findsOneWidget);
    expect(find.text('Cover Stage'), findsOneWidget);
    expect(find.text('Open the pine'), findsOneWidget);
    expect(find.text('Synced Lyrics · LRCLIB'), findsOneWidget);
    await tester.tap(find.text('Second line stays dim'));
    await tester.pump();
    expect(playback.snapshot.position, const Duration(seconds: 12));
    await tester.tap(find.text('Focus Lyrics'));
    await tester.pump();
    expect(find.text('Open the pine'), findsOneWidget);
  });
}
