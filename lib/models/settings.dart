import 'dart:convert';

class FileRule {
  FileRule({required this.name, required this.extensions, this.mime = '', this.action = 'ask', this.priority = 0});
  final String name, extensions, mime, action;
  final int priority;
  bool matches(String filename) {
    final lower = filename.toLowerCase();
    return extensions.split(',').map((e) => e.trim().toLowerCase().replaceFirst(RegExp(r'^\.'), '')).where((e) => e.isNotEmpty).any((e) => lower.endsWith('.$e'));
  }
  Map<String, dynamic> toJson() => {'name': name, 'extensions': extensions, 'mime': mime, 'action': action, 'priority': priority};
  factory FileRule.fromJson(Map<String, dynamic> j) => FileRule(name: j['name'] as String? ?? '', extensions: j['extensions'] as String? ?? '', mime: j['mime'] as String? ?? '', action: j['action'] as String? ?? 'ask', priority: (j['priority'] as num?)?.toInt() ?? 0);
}

class AppSettings {
  AppSettings({this.theme = 'dark', this.language = 'system', this.accent = 0xff80ccdb, this.glass = .35, this.density = 52, this.iconSize = 24, this.showHidden = false, this.grid = false, this.sort = 'name', this.descending = false, this.foldersFirst = true, this.bookmarks = const [], this.rules = const []});
  String theme, language, sort;
  int accent;
  double glass, density, iconSize;
  bool showHidden, grid, descending, foldersFirst;
  List<String> bookmarks;
  List<FileRule> rules;
  FileRule? ruleFor(String filename) {
    final matching = rules.where((r) => r.matches(filename)).toList()..sort((a, b) => b.priority.compareTo(a.priority));
    return matching.isEmpty ? null : matching.first;
  }
  Map<String, dynamic> toJson() => {'version': 1, 'theme': theme, 'language': language, 'accent': accent, 'glass': glass, 'density': density, 'iconSize': iconSize, 'showHidden': showHidden, 'grid': grid, 'sort': sort, 'descending': descending, 'foldersFirst': foldersFirst, 'bookmarks': bookmarks, 'rules': rules.map((r) => r.toJson()).toList()};
  String encode() => jsonEncode(toJson());
  factory AppSettings.decode(String data) {
    if (data.length > 1024 * 1024) throw const FormatException('Settings are too large');
    final decoded = jsonDecode(data);
    if (decoded is! Map<String, dynamic>) throw const FormatException('Invalid settings');
    final j = decoded;
    if (j['version'] != 1) throw const FormatException('Unsupported settings version');
    if (!['dark', 'light', 'system'].contains(j['theme'] ?? 'dark') ||
        !['system', 'en', 'cs'].contains(j['language'] ?? 'system') ||
        !['name', 'size', 'date', 'extension'].contains(j['sort'] ?? 'name')) {
      throw const FormatException('Invalid settings option');
    }
    if (j['rules'] is List) {
      for (final rule in j['rules'] as List) {
        if (rule is! Map || !['ask', 'text'].contains(rule['action'] ?? 'ask') || rule['name'] is! String || rule['extensions'] is! String) {
          throw const FormatException('Invalid file type rule');
        }
      }
    }
    return AppSettings(theme: j['theme'] as String? ?? 'dark', language: j['language'] as String? ?? 'system', accent: (j['accent'] as num?)?.toInt() ?? 0xff80ccdb, glass: ((j['glass'] as num?)?.toDouble() ?? .35).clamp(0, 1), density: ((j['density'] as num?)?.toDouble() ?? 52).clamp(44, 80), iconSize: ((j['iconSize'] as num?)?.toDouble() ?? 24).clamp(18, 40), showHidden: j['showHidden'] as bool? ?? false, grid: j['grid'] as bool? ?? false, sort: j['sort'] as String? ?? 'name', descending: j['descending'] as bool? ?? false, foldersFirst: j['foldersFirst'] as bool? ?? true, bookmarks: (j['bookmarks'] as List? ?? []).whereType<String>().toList(), rules: (j['rules'] as List? ?? []).whereType<Map>().map((e) => FileRule.fromJson(Map<String, dynamic>.from(e))).toList());
  }
}
