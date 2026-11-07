import 'dart:io';
import '../models/entry.dart';
import 'platform_service.dart';
class FileService {
  FileService(this.platform);
  final PlatformService platform;
  Future<List<FileEntry>> list(String path) async {
    if (path.startsWith('content://')) {
      final result = await platform.call<List<dynamic>>('listTree', {'uri': path}) ?? [];
      return result.map((e) => FileEntry.fromMap(e as Map)).toList();
    }
    final entries = <FileEntry>[];
    await for (final entity in Directory(path).list(followLinks: false)) {
      if (entity is Link) continue;
      try { entries.add(await FileEntry.fromEntity(entity)); } on FileSystemException { /* A disappearing entry is skipped. */ }
    }
    return entries;
  }
  bool validName(String name) => name.isNotEmpty && name != '.' && name != '..' && !name.contains('/') && !name.contains('\u0000');
  Future<void> create(String parent, String name, bool directory) async {
    if (!validName(name)) throw const FormatException('Invalid name');
    final path = '$parent/$name';
    if (await FileSystemEntity.type(path, followLinks: false) != FileSystemEntityType.notFound) throw FileSystemException('Already exists', path);
    if (directory) { await Directory(path).create(); } else { await File(path).create(); }
  }
  Future<void> rename(FileEntry entry, String name) async {
    if (!validName(name)) throw const FormatException('Invalid name');
    final parent = File(entry.path).parent.path;
    final target = '$parent/$name';
    if (target == entry.path) return;
    if (await FileSystemEntity.type(target, followLinks: false) != FileSystemEntityType.notFound) throw FileSystemException('Already exists', target);
    if (entry.directory) { await Directory(entry.path).rename(target); } else { await File(entry.path).rename(target); }
  }
  Future<void> delete(FileEntry entry) async {
    if (entry.directory) { await Directory(entry.path).delete(recursive: true); } else { await File(entry.path).delete(); }
  }
}
