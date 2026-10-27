import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../constants.dart';
import '../models/library.dart';
import '../models/settings.dart';
import 'http_get.dart';

class LibraryRepository {
  LibraryRepository({
    HttpGet? http,
    Future<String> Function()? assetLoader,
    this.cacheFile,
  }) : _http = http ?? IoHttpGet(),
       _assetLoader =
           assetLoader ?? (() => rootBundle.loadString(kBundledLibraryAsset));

  final HttpGet _http;
  final Future<String> Function() _assetLoader;
  final Future<File?> Function()? cacheFile;

  Future<LibraryIndex> load(AppSettings settings) async {
    final local = settings.localLibraryPath.trim();
    if (local.isNotEmpty) {
      final file = File(p.join(local, 'library.json'));
      if (file.existsSync()) {
        return LibraryIndex(parseManifestString(await file.readAsString()));
      }
    }
    if (settings.manifestUrl.trim().isNotEmpty) {
      final cached = await _readCache();
      if (cached != null) return cached;
    }
    return loadBundled();
  }

  Future<LibraryIndex> loadBundled() async {
    return LibraryIndex(parseManifestString(await _assetLoader()));
  }

  Future<LibraryIndex> loadLocal(String directory) async {
    final file = File(p.join(directory, 'library.json'));
    if (!file.existsSync()) {
      throw const FileSystemException(
        'library.json was not found in that folder.',
      );
    }
    return LibraryIndex(parseManifestString(await file.readAsString()));
  }

  Future<LibraryIndex> download(String url) async {
    final response = await _http.get(Uri.parse(url.trim()));
    if (!response.ok) {
      throw HttpException('Manifest request failed (${response.status}).');
    }
    final manifest = parseManifestString(response.body);
    final cache = await _cache();
    if (cache != null) {
      await cache.parent.create(recursive: true);
      await cache.writeAsString(response.body);
    }
    return LibraryIndex(manifest);
  }

  Future<LibraryIndex?> _readCache() async {
    final cache = await _cache();
    if (cache == null || !cache.existsSync()) return null;
    try {
      return LibraryIndex(parseManifestString(await cache.readAsString()));
    } catch (_) {
      return null;
    }
  }

  Future<File?> _cache() async {
    if (cacheFile != null) return cacheFile!();
    try {
      final dir = await getApplicationSupportDirectory();
      return File(p.join(dir.path, 'library.remote.json'));
    } catch (_) {
      return null;
    }
  }
}
