import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants.dart';
import '../format.dart';
import '../models/json_util.dart';
import '../models/settings.dart';
import '../models/sync.dart';

class SyncPull {
  const SyncPull({this.payload, this.error});

  final SyncPayload? payload;
  final String? error;

  bool get ok => error == null && payload != null;
}

class SyncClient {
  SyncClient([http.Client? client]) : _http = client ?? http.Client();

  final http.Client _http;

  Future<String?> pushRoom(AppSettings settings, SyncPayload payload) async {
    final code = normalizeRoomCode(settings.syncRoomCode);
    if (code.isEmpty) return 'Set a sync room code first.';
    final rest = settings.restSyncBaseUrl.trim();
    if (rest.isNotEmpty) {
      return _putRest('$rest/sync/$code', {
        'code': code,
        'updated_at': nowIso(),
        'payload': payload.toJson(),
      });
    }
    final project = _project(settings);
    if (project == null) {
      return 'Add a Supabase URL and anon key, or a REST sync base URL.';
    }
    return _upsert(project, 'sync_rooms', 'code', {
      'code': code,
      'updated_at': nowIso(),
      'payload': payload.toJson(),
    }, bearer: project.anonKey);
  }

  Future<SyncPull> pullRoom(AppSettings settings) async {
    final code = normalizeRoomCode(settings.syncRoomCode);
    if (code.isEmpty) {
      return const SyncPull(error: 'Set a sync room code first.');
    }
    final rest = settings.restSyncBaseUrl.trim();
    if (rest.isNotEmpty) {
      return _getRest('$rest/sync/$code');
    }
    final project = _project(settings);
    if (project == null) {
      return const SyncPull(
        error: 'Add a Supabase URL and anon key, or a REST sync base URL.',
      );
    }
    final uri = Uri.parse('${project.url}/rest/v1/sync_rooms').replace(
      queryParameters: {
        'code': 'eq.$code',
        'select': 'code,payload,updated_at',
      },
    );
    return _getSupabaseList(uri, project.anonKey);
  }

  Future<String?> pushAccount({
    required AppSettings settings,
    required SyncPayload payload,
    required String userId,
    required String accessToken,
  }) async {
    final project = _project(settings);
    if (project == null) return 'Add a Supabase URL and anon key.';
    return _upsert(project, 'user_libraries', 'user_id', {
      'user_id': userId,
      'updated_at': nowIso(),
      'payload': payload.toJson(),
    }, bearer: accessToken);
  }

  Future<SyncPull> pullAccount({
    required AppSettings settings,
    required String userId,
    required String accessToken,
  }) async {
    final project = _project(settings);
    if (project == null) {
      return const SyncPull(error: 'Add a Supabase URL and anon key.');
    }
    final uri = Uri.parse('${project.url}/rest/v1/user_libraries').replace(
      queryParameters: {
        'user_id': 'eq.$userId',
        'select': 'payload,updated_at',
      },
    );
    return _getSupabaseList(uri, accessToken, apikey: project.anonKey);
  }

  Future<String?> _putRest(String url, Map<String, Object?> body) async {
    try {
      final response = await _http.put(
        Uri.parse(url),
        headers: {'User-Agent': kUserAgent, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return 'Sync server returned ${response.statusCode}.';
      }
      return null;
    } catch (error) {
      return 'Could not reach the sync server. $error';
    }
  }

  Future<SyncPull> _getRest(String url) async {
    try {
      final response = await _http.get(
        Uri.parse(url),
        headers: {'User-Agent': kUserAgent, 'Accept': 'application/json'},
      );
      if (response.statusCode == 404) {
        return const SyncPull(
          error: 'Nothing has been saved for this code yet.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return SyncPull(error: 'Sync server returned ${response.statusCode}.');
      }
      return SyncPull(payload: _payloadFromBody(response.body));
    } catch (error) {
      return SyncPull(error: 'Could not reach the sync server. $error');
    }
  }

  Future<String?> _upsert(
    _Project project,
    String table,
    String conflict,
    Map<String, Object?> body, {
    required String bearer,
  }) async {
    try {
      final uri = Uri.parse('${project.url}/rest/v1/$table')
          .replace(queryParameters: {'on_conflict': conflict});
      final response = await _http.post(
        uri,
        headers: {
          'User-Agent': kUserAgent,
          'apikey': project.anonKey,
          'Authorization': 'Bearer $bearer',
          'Content-Type': 'application/json',
          'Prefer': 'resolution=merge-duplicates,return=minimal',
        },
        body: jsonEncode(body),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return 'Supabase returned ${response.statusCode}. ${response.body}';
      }
      return null;
    } catch (error) {
      return 'Could not reach Supabase. $error';
    }
  }

  Future<SyncPull> _getSupabaseList(
    Uri uri,
    String bearer, {
    String? apikey,
  }) async {
    try {
      final response = await _http.get(
        uri,
        headers: {
          'User-Agent': kUserAgent,
          'apikey': apikey ?? bearer,
          'Authorization': 'Bearer $bearer',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return SyncPull(error: 'Supabase returned ${response.statusCode}.');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty) {
        return const SyncPull(
          error: 'Nothing has been saved for this sync target yet.',
        );
      }
      final row = asMap(decoded.first);
      final payload = row['payload'];
      if (payload == null) {
        return const SyncPull(error: 'The sync row did not include a payload.');
      }
      return SyncPull(payload: SyncPayload.fromJson(payload));
    } catch (error) {
      return SyncPull(error: 'Could not read the sync payload. $error');
    }
  }

  SyncPayload? _payloadFromBody(String body) {
    final decoded = jsonDecode(body);
    final map = asMap(decoded);
    final payload = map['payload'] ?? decoded;
    return SyncPayload.fromJson(payload);
  }

  _Project? _project(AppSettings settings) {
    final url = settings.supabaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final key = settings.supabaseAnonKey.trim();
    if (url.isEmpty || key.isEmpty) return null;
    return _Project(url, key);
  }
}

class _Project {
  const _Project(this.url, this.anonKey);

  final String url;
  final String anonKey;
}
