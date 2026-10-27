import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/json_util.dart';
import '../models/sync.dart';
import 'supabase_gate.dart';

typedef SyncListener = void Function(SyncPayload payload);

class SyncRealtime {
  RealtimeChannel? _channel;

  Future<String?> listenRoom(String code, SyncListener onPayload) async {
    final client = SupabaseGate.client;
    if (client == null) return 'Supabase is not initialized.';
    await stop();
    final channel = client.channel('xerno-room-$code');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'sync_rooms',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'code',
        value: code,
      ),
      callback: (payload) {
        final parsed = _payloadOf(payload.newRecord);
        if (parsed != null) onPayload(parsed);
      },
    );
    channel.subscribe();
    _channel = channel;
    return null;
  }

  Future<String?> listenAccount(String userId, SyncListener onPayload) async {
    final client = SupabaseGate.client;
    if (client == null) return 'Supabase is not initialized.';
    await stop();
    final channel = client.channel('xerno-user-$userId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'user_libraries',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) {
        final parsed = _payloadOf(payload.newRecord);
        if (parsed != null) onPayload(parsed);
      },
    );
    channel.subscribe();
    _channel = channel;
    return null;
  }

  Future<void> stop() async {
    final channel = _channel;
    _channel = null;
    if (channel == null) return;
    final client = SupabaseGate.client;
    if (client == null) return;
    await client.removeChannel(channel);
  }
}

SyncPayload? _payloadOf(Map<String, dynamic> record) {
  final payload = record['payload'];
  if (payload == null) return null;
  try {
    return SyncPayload.fromJson(asMap(payload));
  } catch (_) {
    return null;
  }
}
