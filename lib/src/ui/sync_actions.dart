import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sync.dart';
import '../models/user_library.dart';
import '../services/supabase_gate.dart';
import '../state/providers.dart';
import 'playback_actions.dart';

Future<String?> pushCurrent(WidgetRef ref) async {
  final settings = ref.read(settingsProvider);
  final data = ref.read(userLibraryProvider).valueOrNull;
  if (data == null) return 'Playlists are still opening.';
  final payload = SyncPayload.fromLibrary(data, settings.deviceId);
  final userId = SupabaseGate.currentUserId();
  final token = SupabaseGate.accessToken();
  final client = ref.read(syncClientProvider);
  if (settings.syncRoomCode.trim().isNotEmpty ||
      userId == null ||
      token == null) {
    return client.pushRoom(settings, payload);
  }
  return client.pushAccount(
    settings: settings,
    payload: payload,
    userId: userId,
    accessToken: token,
  );
}

Future<String?> pullRoomNow(WidgetRef ref, {required bool force}) async {
  final result = await ref
      .read(syncClientProvider)
      .pullRoom(ref.read(settingsProvider));
  final payload = result.payload;
  if (payload == null) {
    return result.error ?? 'Nothing is stored for that room yet.';
  }
  return applyPulled(ref, payload, force: force);
}

Future<String?> pullAccountNow(WidgetRef ref, {required bool force}) async {
  final settings = ref.read(settingsProvider);
  final userId = SupabaseGate.currentUserId();
  final token = SupabaseGate.accessToken();
  if (userId == null || token == null) {
    return 'Sign in before pulling an account library.';
  }
  final result = await ref
      .read(syncClientProvider)
      .pullAccount(settings: settings, userId: userId, accessToken: token);
  final payload = result.payload;
  if (payload == null) {
    return result.error ?? 'Nothing is stored for this account yet.';
  }
  return applyPulled(ref, payload, force: force);
}

Future<String?> pushAccountNow(WidgetRef ref) async {
  final settings = ref.read(settingsProvider);
  final data = ref.read(userLibraryProvider).valueOrNull;
  final userId = SupabaseGate.currentUserId();
  final token = SupabaseGate.accessToken();
  if (data == null) return 'Playlists are still opening.';
  if (userId == null || token == null) {
    return 'Sign in before pushing an account library.';
  }
  return ref
      .read(syncClientProvider)
      .pushAccount(
        settings: settings,
        payload: SyncPayload.fromLibrary(data, settings.deviceId),
        userId: userId,
        accessToken: token,
      );
}

Future<String?> applyPulled(
  WidgetRef ref,
  SyncPayload payload, {
  required bool force,
}) async {
  final current =
      ref.read(userLibraryProvider).valueOrNull ?? UserLibraryData.empty();
  final playbackNewer = isNewerStamp(
    payload.playbackUpdatedAt,
    current.playbackUpdatedAt,
  );
  final playing = ref.read(playerProvider).snapshot.playing;
  await ref
      .read(userLibraryProvider.notifier)
      .applyRemote(payload, force: force);
  final bookmark = payload.bookmark;
  final shouldRestore =
      bookmark != null &&
      !bookmark.isEmpty &&
      (force || (!playing && playbackNewer));
  if (shouldRestore) {
    await restoreBookmark(ref, bookmark, autoplay: false);
  }
  return null;
}
