import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/user_library.dart';

class UserLibraryStore {
  UserLibraryStore(this.directory);

  final Directory directory;

  File get file => File(p.join(directory.path, 'user_library.json'));

  Future<UserLibraryData> load() async {
    if (!file.existsSync()) return UserLibraryData.empty();
    try {
      return UserLibraryData.fromJson(jsonDecode(await file.readAsString()));
    } catch (_) {
      return UserLibraryData.empty();
    }
  }

  Future<void> save(UserLibraryData data) async {
    await directory.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data.toJson()),
    );
  }
}
