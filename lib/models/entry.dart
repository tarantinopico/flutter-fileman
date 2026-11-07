import 'dart:io';
class FileEntry {
  FileEntry({required this.path, required this.name, required this.directory, this.size = 0, this.modified, this.mime});
  final String path, name;
  final bool directory;
  final int size;
  final DateTime? modified;
  final String? mime;
  bool get isDocument => path.startsWith('content://');
  String get extension => name.contains('.') ? name.split('.').last.toLowerCase() : '';
  factory FileEntry.fromMap(Map<dynamic, dynamic> m) => FileEntry(path: m['path'] as String, name: m['name'] as String, directory: m['directory'] as bool, size: (m['size'] as num?)?.toInt() ?? 0, modified: DateTime.fromMillisecondsSinceEpoch((m['modified'] as num?)?.toInt() ?? 0), mime: m['mime'] as String?);
  static Future<FileEntry> fromEntity(FileSystemEntity entity) async {
    final stat = await entity.stat();
    return FileEntry(path: entity.path, name: entity.path.split(Platform.pathSeparator).last, directory: stat.type == FileSystemEntityType.directory, size: stat.size, modified: stat.modified);
  }
}
String formatSize(int size) {
  if (size < 1024) return '$size B';
  var value = size.toDouble(); var unit = 0;
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  while (value >= 1024 && unit < units.length - 1) { value /= 1024; unit++; }
  return '${value.toStringAsFixed(value < 10 ? 1 : 0)} ${units[unit]}';
}
void sortEntries(List<FileEntry> entries, {String sort = 'name', bool descending = false, bool foldersFirst = true}) {
  entries.sort((a, b) {
    if (foldersFirst && a.directory != b.directory) return a.directory ? -1 : 1;
    var c = switch (sort) {
      'size' => a.size.compareTo(b.size),
      'date' => (a.modified?.millisecondsSinceEpoch ?? 0).compareTo(b.modified?.millisecondsSinceEpoch ?? 0),
      'extension' => a.extension.compareTo(b.extension),
      _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    };
    if (c == 0) c = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return descending ? -c : c;
  });
}
