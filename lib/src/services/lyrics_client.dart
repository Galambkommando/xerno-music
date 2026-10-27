import 'dart:convert';

import '../constants.dart';
import '../logic/lrc.dart';
import 'http_get.dart';

class LyricsClient {
  LyricsClient(this._http);

  final HttpGet _http;
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
    final exact = Uri.https(kLrclibHost, '/api/get', {
      'track_name': title,
      'artist_name': artist,
      'album_name': album,
      'duration': '$durationSec',
    });
    final exactResponse = await _http.get(exact, headers: headers);
    if (exactResponse.ok) {
      final lyrics = _decode(exactResponse.body);
      if (lyrics != null && !lyrics.isEmpty) {
        _cache[trackId] = lyrics;
        return lyrics;
      }
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
    final lyrics = closest == null ? Lyrics.empty : Lyrics.fromLrclib(closest);
    _cache[trackId] = lyrics;
    return lyrics;
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
