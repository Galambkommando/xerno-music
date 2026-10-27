import 'dart:convert';
import 'dart:io';

import '../constants.dart';
import '../logic/lrc.dart';
import '../models/json_util.dart';
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
      final lyrics = Lyrics.fromLrclib(asMap(jsonDecode(exactResponse.body)));
      _cache[trackId] = lyrics;
      return lyrics;
    }
    if (exactResponse.status != 404) {
      throw HttpException('LRCLIB returned ${exactResponse.status}.');
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
}
