import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/settings.dart';
import '../models/track.dart';

class ResolvedAudio {
  const ResolvedAudio({
    required this.uri,
    required this.label,
    this.remote,
    this.localFile,
  });

  final Uri uri;
  final String label;
  final Uri? remote;
  final File? localFile;
}

class SourceResolver {
  const SourceResolver();

  ResolvedAudio? resolve({
    required TrackRecord track,
    required AppSettings settings,
    String? pinDirectory,
  }) {
    final pin = _existingFile(pinDirectory, '${track.id}.mp3');
    final local = _existingRelative(
      settings.localLibraryPath,
      track.file.relativePath,
    );
    final remote = remoteUri(track, settings.cloudBaseUrl);
    final remoteLabel = _remoteLabel(track);

    final List<ResolvedAudio> options = switch (settings.sourcePreference) {
      SourcePreference.cloudFirst => [
        if (remote != null)
          ResolvedAudio(
            uri: remote,
            label: remoteLabel,
            remote: remote,
            localFile: local,
          ),
        if (pin != null)
          ResolvedAudio(
            uri: pin.uri,
            label: 'Pinned',
            remote: remote,
            localFile: pin,
          ),
        if (local != null)
          ResolvedAudio(
            uri: local.uri,
            label: 'Local',
            remote: remote,
            localFile: local,
          ),
      ],
      SourcePreference.localFirst || SourcePreference.auto => [
        if (pin != null)
          ResolvedAudio(
            uri: pin.uri,
            label: 'Pinned',
            remote: remote,
            localFile: pin,
          ),
        if (local != null)
          ResolvedAudio(
            uri: local.uri,
            label: 'Local',
            remote: remote,
            localFile: local,
          ),
        if (remote != null)
          ResolvedAudio(
            uri: remote,
            label: remoteLabel,
            remote: remote,
            localFile: local,
          ),
      ],
    };
    if (options.isEmpty) return null;
    return options.first;
  }

  Uri? remoteUri(TrackRecord track, String cloudBaseUrl) {
    final zipline = track.file.ziplineUrl;
    if (zipline != null && zipline.isNotEmpty) {
      return Uri.tryParse(zipline);
    }
    final base = cloudBaseUrl.trim();
    if (base.isEmpty || track.file.relativePath.isEmpty) return null;
    return Uri.tryParse(joinCloudUrl(base, track.file.relativePath));
  }

  File? localFile(String libraryRoot, TrackRecord track) {
    return _existingRelative(libraryRoot, track.file.relativePath);
  }
}

/// Direct RöcsögeCloud URL for a track, or a cloud-base join when only a path exists.
String? serverLinkFor(TrackRecord track, String cloudBaseUrl) {
  final direct = track.file.ziplineUrl?.trim();
  if (direct != null && direct.isNotEmpty) return direct;
  for (final appearance in track.appearances) {
    final url = appearance.ziplineUrl?.trim();
    if (url != null && url.isNotEmpty) return url;
  }
  final base = cloudBaseUrl.trim();
  if (base.isEmpty || track.file.relativePath.isEmpty) return null;
  return joinCloudUrl(base, track.file.relativePath);
}

String joinCloudUrl(String base, String relative) {
  final trimmed = base.endsWith('/')
      ? base.substring(0, base.length - 1)
      : base;
  final encoded = relative
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .map(Uri.encodeComponent)
      .join('/');
  return '$trimmed/$encoded';
}

String _remoteLabel(TrackRecord track) {
  final zipline = track.file.ziplineUrl;
  if (zipline != null && zipline.isNotEmpty) return 'Zipline';
  return 'Cloud';
}

File? _existingFile(String? directory, String name) {
  if (directory == null || directory.trim().isEmpty) return null;
  final file = File(p.join(directory, name));
  if (file.existsSync()) return file;
  return null;
}

File? _existingRelative(String root, String relative) {
  if (root.trim().isEmpty || relative.trim().isEmpty) return null;
  final file = File(p.joinAll([root, ...relative.split('/')]));
  if (file.existsSync()) return file;
  return null;
}
