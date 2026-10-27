import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../logic/source_resolver.dart';
import '../models/settings.dart';
import '../models/track.dart';
import 'http_get.dart';

class DownloadManager extends ChangeNotifier {
  DownloadManager({
    ByteSource? source,
    Future<Directory> Function()? supportDirectory,
    SourceResolver? resolver,
  }) : _source = source ?? IoByteSource(),
       _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _resolver = resolver ?? const SourceResolver();

  final ByteSource _source;
  final Future<Directory> Function() _supportDirectory;
  final SourceResolver _resolver;

  String? directoryPath;
  final Set<String> _pins = {};
  final Map<String, double> progress = {};
  String? activeId;
  String? message;
  int batchDone = 0;
  int batchTotal = 0;
  bool cancelRequested = false;
  bool ready = false;

  bool isPinned(String id) => _pins.contains(id);

  int get pinnedCount => _pins.length;

  List<String> get pinnedIds {
    final ids = _pins.toList()..sort();
    return ids;
  }

  Future<void> ensureLoaded() async {
    if (ready) return;
    try {
      final root = await _offlineDir();
      directoryPath = root.path;
      final found = <String>{};
      if (root.existsSync()) {
        await for (final entity in root.list()) {
          if (entity is! File) continue;
          final name = p.basename(entity.path);
          if (name.endsWith('.mp3')) {
            found.add(p.basenameWithoutExtension(name));
          }
        }
      }
      _pins
        ..clear()
        ..addAll(found);
      ready = true;
      notifyListeners();
    } catch (error) {
      message = 'Offline storage is unavailable.';
      ready = true;
      notifyListeners();
    }
  }

  Future<String?> pinTracks(
    List<TrackRecord> tracks,
    AppSettings settings,
  ) async {
    await ensureLoaded();
    cancelRequested = false;
    batchDone = 0;
    batchTotal = tracks.length;
    notifyListeners();
    String? lastError;
    for (final track in tracks) {
      if (cancelRequested) {
        message = 'Pinning cancelled.';
        notifyListeners();
        return message;
      }
      final error = await pinTrack(track, settings);
      batchDone += 1;
      if (error != null) lastError = error;
      notifyListeners();
    }
    message =
        lastError ??
        'Pinned $batchDone ${batchDone == 1 ? 'track' : 'tracks'}.';
    activeId = null;
    notifyListeners();
    return lastError;
  }

  Future<String?> pinTrack(TrackRecord track, AppSettings settings) async {
    await ensureLoaded();
    if (directoryPath == null) return 'Offline storage is unavailable.';
    if (_pins.contains(track.id)) return null;
    final dest = File(p.join(directoryPath!, '${track.id}.mp3'));
    final part = File('${dest.path}.part');
    activeId = track.id;
    progress[track.id] = 0;
    message = 'Pinning ${track.title}';
    notifyListeners();
    try {
      final remote = _resolver.remoteUri(track, settings.cloudBaseUrl);
      if (remote != null) {
        await _download(remote, part, track);
      } else {
        final local = _resolver.localFile(settings.localLibraryPath, track);
        if (local == null) {
          progress.remove(track.id);
          activeId = null;
          notifyListeners();
          return '${track.title} has no cloud URL or local file to pin.';
        }
        await _copy(local, part);
      }
      if (cancelRequested) {
        if (part.existsSync()) await part.delete();
        progress.remove(track.id);
        return 'Pinning cancelled.';
      }
      if (dest.existsSync()) await dest.delete();
      await part.rename(dest.path);
      _pins.add(track.id);
      progress.remove(track.id);
      activeId = null;
      notifyListeners();
      return null;
    } catch (error) {
      if (part.existsSync()) await part.delete();
      progress.remove(track.id);
      activeId = null;
      message = 'Could not pin ${track.title}.';
      notifyListeners();
      return message;
    }
  }

  Future<void> unpin(String id) async {
    await ensureLoaded();
    if (directoryPath == null) return;
    final file = File(p.join(directoryPath!, '$id.mp3'));
    if (file.existsSync()) await file.delete();
    _pins.remove(id);
    progress.remove(id);
    notifyListeners();
  }

  void requestCancel() {
    cancelRequested = true;
    notifyListeners();
  }

  Future<int> pinnedBytes() async {
    await ensureLoaded();
    if (directoryPath == null) return 0;
    var total = 0;
    for (final id in _pins) {
      final file = File(p.join(directoryPath!, '$id.mp3'));
      if (file.existsSync()) total += await file.length();
    }
    return total;
  }

  Future<void> _download(Uri uri, File part, TrackRecord track) async {
    final fetch = await _source.open(uri);
    if (fetch.status < 200 || fetch.status >= 300) {
      throw HttpException('Download failed (${fetch.status}).');
    }
    final total = fetch.length ?? track.audioQuality.filesizeBytes;
    final sink = part.openWrite();
    var done = 0;
    var lastNotify = 0;
    try {
      await for (final chunk in fetch.bytes) {
        if (cancelRequested) break;
        sink.add(chunk);
        done += chunk.length;
        if (done - lastNotify > 64 * 1024 || (total > 0 && done >= total)) {
          progress[track.id] = total > 0 ? (done / total).clamp(0, 1) : 0;
          lastNotify = done;
          notifyListeners();
        }
      }
    } finally {
      await sink.close();
    }
  }

  Future<void> _copy(File source, File part) async {
    final length = await source.length();
    final sink = part.openWrite();
    var done = 0;
    try {
      await for (final chunk in source.openRead()) {
        if (cancelRequested) break;
        sink.add(chunk);
        done += chunk.length;
        if (activeId != null && length > 0) {
          progress[activeId!] = (done / length).clamp(0, 1);
        }
      }
    } finally {
      await sink.close();
    }
    notifyListeners();
  }

  Future<Directory> _offlineDir() async {
    final support = await _supportDirectory();
    final dir = Directory(p.join(support.path, 'offline'));
    await dir.create(recursive: true);
    return dir;
  }

  @override
  void dispose() {
    final source = _source;
    if (source is IoByteSource) {
      source.close();
    }
    super.dispose();
  }
}
