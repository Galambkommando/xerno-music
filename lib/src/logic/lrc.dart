enum LyricsSource { none, apple, lrclib }

enum LyricsSync { none, line, syllable }

class LyricWord {
  const LyricWord(this.text, this.start, this.end, {this.pieces = const []});

  final String text;
  final Duration start;
  final Duration end;

  /// Syllables that were joined because `part` was true. Empty when the word
  /// is already a single sung unit.
  final List<LyricWord> pieces;

  int get startMs => start.inMilliseconds;
  int get endMs => end.inMilliseconds;
}

class LyricLine {
  const LyricLine(
    this.time,
    this.text, {
    this.end,
    this.words = const [],
    this.romanization,
    this.translation,
    this.background = const [],
    this.oppositeTurn = false,
    this.key,
  });

  final Duration time;
  final String text;
  final Duration? end;
  final List<LyricWord> words;
  final String? romanization;
  final String? translation;
  final List<LyricWord> background;
  final bool oppositeTurn;
  final String? key;
}

class Lyrics {
  const Lyrics({
    this.plain,
    this.synced = const [],
    this.instrumental = false,
    this.source = LyricsSource.none,
    this.sync = LyricsSync.none,
    this.songwriters = const [],
  });

  final String? plain;
  final List<LyricLine> synced;
  final bool instrumental;
  final LyricsSource source;
  final LyricsSync sync;
  final List<String> songwriters;

  static const empty = Lyrics();

  bool get hasSynced => synced.isNotEmpty;

  bool get isEmpty =>
      !instrumental &&
      (plain == null || plain!.trim().isEmpty) &&
      synced.isEmpty;

  bool get hasRomanization => synced.any((line) {
    if (distinctLyricNote(line.romanization, line.text) != null) return true;
    return romanizeHangul(line.text) != line.text;
  });

  bool get hasTranslation => synced.any(
    (line) => distinctLyricNote(line.translation, line.text) != null,
  );

  String get sourceLabel {
    if (!hasSynced) {
      if (plain != null && plain!.trim().isNotEmpty) return 'Static Lyrics';
      return 'Lyrics';
    }
    final kind = sync == LyricsSync.syllable
        ? 'Syllable Synced'
        : 'Line Synced';
    final from = source == LyricsSource.apple
        ? 'Apple Music / Spicy'
        : 'LRCLIB';
    return '$kind · $from';
  }

  factory Lyrics.fromLrclib(Map<String, Object?> json) {
    final syncedRaw = json['syncedLyrics'];
    final plainRaw = json['plainLyrics'];
    final synced = syncedRaw is String
        ? parseLrc(syncedRaw)
        : const <LyricLine>[];
    return Lyrics(
      plain: plainRaw is String && plainRaw.trim().isNotEmpty
          ? plainRaw.trim()
          : null,
      synced: synced,
      instrumental: json['instrumental'] == true,
      source: LyricsSource.lrclib,
      sync: synced.isEmpty ? LyricsSync.none : LyricsSync.line,
    );
  }
}

final RegExp _stamp = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');
final RegExp _wordStamp = RegExp(
  r'<(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?>([^<]*)',
);

List<LyricLine> parseLrc(String input) {
  final lines = <LyricLine>[];
  for (final raw in input.split(RegExp(r'\r?\n'))) {
    final stamps = _stamp.allMatches(raw).toList();
    if (stamps.isEmpty) continue;
    final rest = raw.replaceAll(_stamp, '');
    final wordMatches = _wordStamp.allMatches(rest).toList();
    late final String text;
    var words = const <LyricWord>[];
    if (wordMatches.isNotEmpty) {
      final built = <LyricWord>[];
      final buffer = StringBuffer();
      for (var i = 0; i < wordMatches.length; i++) {
        final match = wordMatches[i];
        final start = _durationOf(
          match.group(1)!,
          match.group(2)!,
          match.group(3),
        );
        final piece = (match.group(4) ?? '').trim();
        if (piece.isEmpty) continue;
        final end = i + 1 < wordMatches.length
            ? _durationOf(
                wordMatches[i + 1].group(1)!,
                wordMatches[i + 1].group(2)!,
                wordMatches[i + 1].group(3),
              )
            : start + const Duration(milliseconds: 450);
        built.add(LyricWord(piece, start, end));
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(piece);
      }
      text = buffer.toString().trim();
      words = built;
    } else {
      text = rest.trim();
    }
    if (text.isEmpty) continue;
    for (final stamp in stamps) {
      lines.add(
        LyricLine(
          _durationOf(stamp.group(1)!, stamp.group(2)!, stamp.group(3)),
          text,
          words: words,
        ),
      );
    }
  }
  lines.sort((a, b) => a.time.compareTo(b.time));
  return [
    for (var i = 0; i < lines.length; i++)
      if (lines[i].words.isNotEmpty)
        lines[i]
      else
        LyricLine(
          lines[i].time,
          lines[i].text,
          end: lineWindowEnd(lines[i].time, _nextStart(lines, i)),
          words: synthesizeWords(
            lines[i].text,
            lines[i].time,
            lineWindowEnd(lines[i].time, _nextStart(lines, i)),
          ),
        ),
  ];
}

Duration? _nextStart(List<LyricLine> lines, int index) {
  if (index + 1 >= lines.length) return null;
  return lines[index + 1].time;
}

Duration lineWindowEnd(Duration start, Duration? next) {
  final cap = start + const Duration(seconds: 6);
  if (next == null || next <= start) return cap;
  return next < cap ? next : cap;
}

List<LyricWord> synthesizeWords(String text, Duration start, Duration end) {
  final parts = text
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return const [];
  final span = end - start;
  if (span <= Duration.zero) {
    return [LyricWord(parts.join(' '), start, end)];
  }
  final weights = [for (final part in parts) part.length.clamp(1, 100000)];
  final total = weights.fold<int>(0, (sum, weight) => sum + weight);
  var cursor = start;
  var used = 0;
  final words = <LyricWord>[];
  for (var i = 0; i < parts.length; i++) {
    used += weights[i];
    final next = i == parts.length - 1
        ? end
        : start +
              Duration(
                microseconds: (span.inMicroseconds * used / total).round(),
              );
    words.add(LyricWord(parts[i], cursor, next));
    cursor = next;
  }
  return words;
}

List<LyricWord> joinSyllables(List<Object?> syllables) {
  final words = <LyricWord>[];
  final buffer = StringBuffer();
  final pieces = <LyricWord>[];
  Duration? start;
  var end = Duration.zero;
  void flush() {
    final text = buffer.toString();
    final wordStart = start;
    if (text.isNotEmpty && wordStart != null) {
      words.add(
        LyricWord(
          text,
          wordStart,
          end,
          pieces: pieces.length > 1 ? List<LyricWord>.of(pieces) : const [],
        ),
      );
    }
    buffer.clear();
    pieces.clear();
    start = null;
  }

  for (final raw in syllables) {
    if (raw is! Map) continue;
    final text = '${raw['text'] ?? ''}';
    if (text.isEmpty) continue;
    final syllableStart = _millis(raw['timestamp']);
    final syllableEnd = _millis(raw['endtime'], fallback: syllableStart);
    start ??= syllableStart;
    buffer.write(text);
    end = syllableEnd;
    pieces.add(LyricWord(text, syllableStart, syllableEnd));
    if (raw['part'] != true) flush();
  }
  flush();
  return words;
}

/// A subtitle that adds something the lyric line does not already say.
String? distinctLyricNote(String? note, String line) {
  if (note == null) return null;
  final cleaned = note.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (cleaned.isEmpty) return null;
  final base = line.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (cleaned.toLowerCase() == base.toLowerCase()) return null;
  return cleaned;
}

/// Revised Romanization of Hangul syllable blocks. Other characters pass through.
String romanizeHangul(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (rune < 0xAC00 || rune > 0xD7A3) {
      buffer.writeCharCode(rune);
      continue;
    }
    final syllable = rune - 0xAC00;
    final initial = syllable ~/ 588;
    final medial = (syllable % 588) ~/ 28;
    final finalIndex = syllable % 28;
    buffer
      ..write(_choseong[initial])
      ..write(_jungseong[medial])
      ..write(_jongseong[finalIndex]);
  }
  return buffer.toString();
}

const List<String> _choseong = [
  'g',
  'kk',
  'n',
  'd',
  'tt',
  'r',
  'm',
  'b',
  'pp',
  's',
  'ss',
  '',
  'j',
  'jj',
  'ch',
  'k',
  't',
  'p',
  'h',
];

const List<String> _jungseong = [
  'a',
  'ae',
  'ya',
  'yae',
  'eo',
  'e',
  'yeo',
  'ye',
  'o',
  'wa',
  'wae',
  'oe',
  'yo',
  'u',
  'wo',
  'we',
  'wi',
  'yu',
  'eu',
  'ui',
  'i',
];

const List<String> _jongseong = [
  '',
  'k',
  'k',
  'k',
  'n',
  'n',
  'n',
  't',
  'l',
  'k',
  'm',
  'l',
  'l',
  'l',
  'p',
  'l',
  'm',
  'p',
  'p',
  't',
  't',
  'ng',
  't',
  't',
  'k',
  't',
  'p',
  't',
];

Duration _durationOf(String minutes, String seconds, String? fraction) {
  var millis = 0;
  if (fraction != null) {
    if (fraction.length == 1) {
      millis = int.parse(fraction) * 100;
    } else if (fraction.length == 2) {
      millis = int.parse(fraction) * 10;
    } else {
      millis = int.parse(fraction.substring(0, 3));
    }
  }
  return Duration(
    minutes: int.parse(minutes),
    seconds: int.parse(seconds),
    milliseconds: millis,
  );
}

Duration _millis(Object? value, {Duration fallback = Duration.zero}) {
  if (value is num) return Duration(milliseconds: value.round());
  return fallback;
}

/// How far through [index] the playhead is, from 0 at the line start to 1 at the next.
double lyricLineProgress(List<LyricLine> lines, int index, Duration position) {
  if (index < 0 || index >= lines.length) return 0;
  final start = lines[index].time;
  if (position <= start) return 0;
  final end =
      lines[index].end ??
      (index + 1 < lines.length
          ? lines[index + 1].time
          : start + const Duration(seconds: 5));
  final span = end - start;
  if (span <= Duration.zero) return 1;
  final value = (position - start).inMicroseconds / span.inMicroseconds;
  if (value <= 0) return 0;
  if (value >= 1) return 1;
  return value;
}

int activeLyricIndex(List<LyricLine> lines, Duration position) {
  var index = -1;
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].time <= position) {
      index = i;
    } else {
      break;
    }
  }
  return index;
}

Map<String, Object?>? closestLrclibRow(List<Object?> rows, int durationSec) {
  Map<String, Object?>? best;
  var bestDelta = 1 << 30;
  for (final row in rows) {
    if (row is! Map) continue;
    final map = row.map((key, value) => MapEntry(key.toString(), value));
    final duration = map['duration'];
    final seconds = duration is num ? duration.toInt() : null;
    final delta = seconds == null ? 1 << 20 : (seconds - durationSec).abs();
    if (delta < bestDelta) {
      bestDelta = delta;
      best = map;
    }
  }
  return best;
}

int? pickAppleTrackId(
  Object? decoded, {
  required String title,
  required String artist,
  required int durationSec,
}) {
  if (decoded is! Map) return null;
  final results = decoded['results'];
  if (results is! List) return null;
  final wantTitle = _norm(title);
  final wantArtist = _norm(artist);
  var bestScore = 0;
  int? bestId;
  for (final row in results) {
    if (row is! Map) continue;
    final name = _norm('${row['trackName'] ?? ''}');
    final by = _norm('${row['artistName'] ?? ''}');
    final millis = row['trackTimeMillis'];
    final seconds = millis is num ? (millis / 1000).round() : null;
    var score = 0;
    if (name.isNotEmpty && name == wantTitle) {
      score += 6;
    } else if (name.isNotEmpty &&
        (name.contains(wantTitle) || wantTitle.contains(name))) {
      score += 3;
    }
    if (wantArtist.isNotEmpty &&
        (by.contains(wantArtist) || wantArtist.contains(by))) {
      score += 4;
    }
    if (seconds != null) {
      final delta = (seconds - durationSec).abs();
      if (delta <= 2) {
        score += 3;
      } else if (delta <= 8) {
        score += 1;
      }
    }
    final id = row['trackId'];
    if (id is! num) continue;
    if (score > bestScore) {
      bestScore = score;
      bestId = id.toInt();
    }
  }
  if (bestScore < 6 || bestId == null) return null;
  return bestId;
}

String _norm(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'\([^)]*\)'), ' ')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}

Lyrics? lyricsFromAppleMusic(Object? decoded) {
  if (decoded is! Map) return null;
  final content = decoded['content'];
  if (content is! List || content.isEmpty) return null;
  final meta = decoded['metadata'] is Map
      ? decoded['metadata'] as Map
      : const {};
  final roman = _textByKey(meta['transliterations']);
  final translation = _textByKey(meta['translations'], preferEnglish: true);
  final writers = <String>[
    for (final name
        in (meta['songwriters'] is List
            ? meta['songwriters'] as List
            : const []))
      if ('$name'.trim().isNotEmpty) '$name'.trim(),
  ];
  final lines = <LyricLine>[];
  for (var i = 0; i < content.length; i++) {
    final raw = content[i];
    if (raw is! Map) continue;
    final syllables = raw['text'];
    final words = syllables is List
        ? joinSyllables(syllables)
        : synthesizeWords(
            '${raw['text'] ?? ''}',
            _millis(raw['timestamp']),
            _millis(raw['endtime']),
          );
    if (words.isEmpty) continue;
    final text = words.map((word) => word.text).join(' ').trim();
    if (text.isEmpty) continue;
    final key = raw['key']?.toString();
    final background = raw['backgroundText'] is List
        ? joinSyllables(raw['backgroundText'] as List)
        : const <LyricWord>[];
    lines.add(
      LyricLine(
        _millis(raw['timestamp']),
        text,
        end: _millis(raw['endtime']),
        words: words,
        romanization: key == null ? null : roman[key],
        translation: key == null ? null : translation[key],
        background: background,
        oppositeTurn: raw['oppositeTurn'] == true,
        key: key,
      ),
    );
  }
  if (lines.isEmpty) return null;
  final type = decoded['type'];
  return Lyrics(
    plain: lines.map((line) => line.text).join('\n'),
    synced: lines,
    source: LyricsSource.apple,
    sync: type == 'Syllable' ? LyricsSync.syllable : LyricsSync.line,
    songwriters: writers,
  );
}

Map<String, String> _textByKey(Object? groups, {bool preferEnglish = false}) {
  if (groups is! List || groups.isEmpty) return const {};
  Map? chosen;
  if (preferEnglish) {
    for (final group in groups) {
      if (group is! Map) continue;
      final lang = '${group['lang'] ?? ''}'.toLowerCase();
      if (lang == 'en-us' || lang == 'en' || lang.startsWith('en-')) {
        chosen = group;
        break;
      }
    }
  }
  chosen ??= groups.cast<Object?>().whereType<Map>().firstOrNull;
  if (chosen == null) return const {};
  final lines = chosen['lines'];
  if (lines is! List) return const {};
  final map = <String, String>{};
  for (final line in lines) {
    if (line is! Map) continue;
    final key = line['key']?.toString();
    final text = line['text']?.toString();
    if (key == null || text == null || text.trim().isEmpty) continue;
    map[key] = text.trim();
  }
  return map;
}
