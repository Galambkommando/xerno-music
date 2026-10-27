import 'dart:math';

String nowIso() => DateTime.now().toUtc().toIso8601String();

String epochIso() =>
    DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toIso8601String();

String newDeviceId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

String newRoomCode() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random.secure();
  final chars = List.generate(
    8,
    (_) => alphabet[random.nextInt(alphabet.length)],
  );
  return '${chars.take(4).join()}-${chars.skip(4).join()}';
}

String newPlaylistId() =>
    'pl_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

String formatClock(Duration duration) {
  final clamped = duration < Duration.zero ? Duration.zero : duration;
  final total = clamped.inSeconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  final mm = minutes.toString().padLeft(hours > 0 ? 2 : 1, '0');
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) return '$hours:$mm:$ss';
  return '$minutes:$ss';
}

String formatInt(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return negative ? '-$buffer' : buffer.toString();
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} ${units[unit]}';
}

String normalizeRoomCode(String raw) =>
    raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
