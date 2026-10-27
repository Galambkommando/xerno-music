class LyricLine {
  const LyricLine(this.time, this.text);

  final Duration time;
  final String text;
}

class Lyrics {
  const Lyrics({this.plain, this.synced = const [], this.instrumental = false});

  final String? plain;
  final List<LyricLine> synced;
  final bool instrumental;

  static const empty = Lyrics();

  bool get hasSynced => synced.isNotEmpty;

  bool get isEmpty =>
      !instrumental &&
      (plain == null || plain!.trim().isEmpty) &&
      synced.isEmpty;

  factory Lyrics.fromLrclib(Map<String, Object?> json) {
    final syncedRaw = json['syncedLyrics'];
    final plainRaw = json['plainLyrics'];
    return Lyrics(
      plain: plainRaw is String && plainRaw.trim().isNotEmpty
          ? plainRaw.trim()
          : null,
      synced: syncedRaw is String ? parseLrc(syncedRaw) : const [],
      instrumental: json['instrumental'] == true,
    );
  }
}

final RegExp _stamp = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');

List<LyricLine> parseLrc(String input) {
  final lines = <LyricLine>[];
  for (final raw in input.split(RegExp(r'\r?\n'))) {
    final matches = _stamp.allMatches(raw).toList();
    if (matches.isEmpty) continue;
    final text = raw.replaceAll(_stamp, '').trim();
    if (text.isEmpty) continue;
    for (final match in matches) {
      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final fraction = match.group(3);
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
      lines.add(
        LyricLine(
          Duration(minutes: minutes, seconds: seconds, milliseconds: millis),
          text,
        ),
      );
    }
  }
  lines.sort((a, b) => a.time.compareTo(b.time));
  return lines;
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
