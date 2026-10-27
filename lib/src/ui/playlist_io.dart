import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_library.dart';
import '../platform_info.dart';
import '../state/providers.dart';
import 'playback_actions.dart';

Future<void> exportUserLibrary(BuildContext context, WidgetRef ref) async {
  final data = ref.read(userLibraryProvider).valueOrNull;
  if (data == null) {
    if (!context.mounted) return;
    showNote(context, 'Playlists are still opening.');
    return;
  }
  final text = const JsonEncoder.withIndent('  ').convert(data.toExport());
  final bytes = Uint8List.fromList(utf8.encode(text));
  try {
    if (isAndroidDevice) {
      final saved = await FilePicker.platform.saveFile(
        dialogTitle: 'Export playlists',
        fileName: 'xerno-playlists.json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: bytes,
      );
      if (!context.mounted) return;
      showNote(context, saved == null ? null : 'Exported playlists.');
      return;
    }
    final selected = await FilePicker.platform.saveFile(
      dialogTitle: 'Export playlists',
      fileName: 'xerno-playlists.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (selected == null) return;
    final path = selected.endsWith('.json') ? selected : '$selected.json';
    await File(path).writeAsString(text);
    if (!context.mounted) return;
    showNote(context, 'Exported playlists.');
  } catch (error) {
    if (!context.mounted) return;
    showNote(context, 'Could not export playlists. $error');
  }
}

Future<void> importUserLibrary(BuildContext context, WidgetRef ref) async {
  try {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import playlists',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    final file = picked?.files.single;
    if (file == null) return;
    final raw = file.bytes != null
        ? utf8.decode(file.bytes!)
        : await File(file.path!).readAsString();
    final incoming = UserLibraryData.fromExport(jsonDecode(raw));
    if (!context.mounted) return;
    final replace = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import playlists'),
        content: const Text(
          'Merge adds the imported favorites and tracks onto this device. Replace writes the imported favorites and playlists over this device\'s copies.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Merge'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    if (replace == null) return;
    await ref
        .read(userLibraryProvider.notifier)
        .mutate(
          (current) => mergeUserLibraries(current, incoming, replace: replace),
        );
    if (!context.mounted) return;
    showNote(context, replace ? 'Replaced playlists.' : 'Merged playlists.');
  } catch (error) {
    if (!context.mounted) return;
    showNote(context, 'Could not import that file. $error');
  }
}

Future<void> importCatalogFile(BuildContext context, WidgetRef ref) async {
  try {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import library.json or playlist.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    final file = picked?.files.single;
    if (file == null) return;
    final raw = file.bytes != null
        ? utf8.decode(file.bytes!)
        : await File(file.path!).readAsString();
    final error = await ref.read(libraryProvider.notifier).importJson(raw);
    if (!context.mounted) return;
    showNote(context, error ?? 'Imported into the open library.');
  } catch (error) {
    if (!context.mounted) return;
    showNote(context, 'Could not import that file. $error');
  }
}
