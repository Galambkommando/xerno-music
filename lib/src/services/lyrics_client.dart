import 'dart:async';
import 'dart:convert';

import '../constants.dart';
import '../logic/lrc.dart';
import 'http_get.dart';

class LyricsClient {
  LyricsClient(this._http, {this.fallback});

  final HttpGet _http;
  final HttpGet? fallback;
  final Map<String, Lyrics> _cache = {};

  Future<Lyrics> fetch({
    required String trackId,
    required String title,
    required String artist,
    required String album,
    required int durationSec,
  }) async {
    final cached = _cache[trackId];
    if (cached != null) return cached;
    final headers = {'User-Agent': kUserAgent, 'Accept': 'application/json'};
    final apple = await _apple(
      title: title,
      artist: artist,
      durationSec: durationSec,
      headers: headers,
    );
    if (apple != null && !apple.isEmpty) {
      _cache[trackId] = apple;
      return apple;
    }
    final lyrics = await _lrclib(
      title: title,
      artist: artist,
      album: album,
      durationSec: durationSec,
      headers: headers,
    );
    _cache[trackId] = lyrics;
    return lyrics;
  }

  Future<Lyrics?> _apple({
    required String title,
    required String artist,
    required int durationSec,
    required Map<String, String> headers,
  }) async {
    try {
      final search = Uri.https('itunes.apple.com', '/search', {
        'term': '$artist $title',
        'entity': 'song',
        'limit': '5',
      });
      final found = await _load(search, headers, const Duration(seconds: 6));
      if (found == null) return null;
      final id = pickAppleTrackId(
        _decodeJson(found.body),
        title: title,
        artist: artist,
        durationSec: durationSec,
      );
      if (id == null) return null;
      final lyrics = Uri.https('lyrics.paxsenix.org', '/apple-music/lyrics', {
        'id': '$id',
      });
      final response = await _load(
        lyrics,
        headers,
        const Duration(seconds: 10),
      );
      if (response == null) return null;
      return lyricsFromAppleMusic(_decodeJson(response.body));
    } catch (_) {
      return null;
    }
  }

  Future<HttpText?> _load(
    Uri uri,
    Map<String, String> headers,
    Duration budget,
  ) async {
    try {
      final response = await _http.get(uri, headers: headers).timeout(budget);
      if (response.ok && response.body.trim().isNotEmpty) return response;
    } catch (_) {}
    final alternate = fallback;
    if (alternate == null) return null;
    try {
      final response = await alternate
          .get(uri, headers: headers)
          .timeout(budget);
      if (response.ok && response.body.trim().isNotEmpty) return response;
    } catch (_) {}
    return null;
  }

  Object? _decodeJson(String body) {
    final trimmed = body.trim();
    final start = trimmed.indexOf(RegExp(r'[\[{]'));
    if (start < 0) return null;
    return jsonDecode(start == 0 ? trimmed : trimmed.substring(start));
  }

  Future<Lyrics> _lrclib({
    required String title,
    required String artist,
    required String album,
    required int durationSec,
    required Map<String, String> headers,
  }) async {
    try {
      final exact = Uri.https(kLrclibHost, '/api/get', {
        'track_name': title,
        'artist_name': artist,
        'album_name': album,
        'duration': '$durationSec',
      });
      final exactResponse = await _http.get(exact, headers: headers);
      if (exactResponse.ok) {
        final lyrics = _decode(exactResponse.body);
        if (lyrics != null && !lyrics.isEmpty) return lyrics;
      }
      final search = Uri.https(kLrclibHost, '/api/search', {
        'track_name': title,
        'artist_name': artist,
      });
      final searchResponse = await _http.get(search, headers: headers);
      if (!searchResponse.ok) return Lyrics.empty;
      final decoded = jsonDecode(searchResponse.body);
      if (decoded is! List || decoded.isEmpty) return Lyrics.empty;
      final closest = closestLrclibRow(decoded, durationSec);
      if (closest == null) return Lyrics.empty;
      return Lyrics.fromLrclib(closest);
    } catch (_) {
      return Lyrics.empty;
    }
  }

  Lyrics? _decode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      return Lyrics.fromLrclib(decoded.cast<String, Object?>());
    } catch (_) {
      return null;
    }
  }
}
