import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../core/strings.dart';
import '../models/entry.dart';
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.root, required this.onOpen});
  final String root;
  final Future<void> Function(FileEntry) onOpen;
  @override State<SearchScreen> createState() => _SearchScreenState();
}
class _SearchScreenState extends State<SearchScreen> {
  final query = TextEditingController(), extension = TextEditingController(), minimum = TextEditingController();
  List<FileEntry> results = [];
  bool running = false, hidden = false, caseSensitive = false;
  int token = 0, skipped = 0, visited = 0;
  String? status;
  @override void dispose() { token++; query.dispose(); extension.dispose(); minimum.dispose(); super.dispose(); }
  Future<void> search() async {
    final run = ++token; final needle = caseSensitive ? query.text : query.text.toLowerCase(); final ext = extension.text.trim().toLowerCase().replaceFirst(RegExp(r'^\.'), ''); final minSize = (double.tryParse(minimum.text) ?? 0) * 1024;
    setState(() { results = []; running = true; skipped = 0; visited = 0; status = null; });
    final pending = <Directory>[Directory(widget.root)];
    while (pending.isNotEmpty && run == token && visited < 100000) {
      final dir = pending.removeLast();
      try {
        await for (final entity in dir.list(followLinks: false)) {
          if (run != token) break;
          visited++;
          if (visited >= 100000) break;
          final name = entity.path.split(Platform.pathSeparator).last;
          if (!hidden && name.startsWith('.')) continue;
          if (entity is Link) continue;
          if (entity is Directory) pending.add(entity);
          final candidate = caseSensitive ? name : name.toLowerCase();
          if (!candidate.contains(needle)) continue;
          if (ext.isNotEmpty && !name.toLowerCase().endsWith('.$ext')) continue;
          try {
            final entry = await FileEntry.fromEntity(entity);
            if (minSize > 0 && (entry.directory || entry.size < minSize)) continue;
            results.add(entry);
            if (results.length % 40 == 0 && mounted) setState(() {});
          } catch (_) { skipped++; }
        }
      } catch (_) { skipped++; }
    }
    if (mounted && run == token) setState(() { running = false; status = visited >= 100000 ? 'limit' : 'done'; sortEntries(results); });
  }
  @override Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Scaffold(appBar: AppBar(title: Text(s.t('Search', 'Hledat')), actions: [IconButton(tooltip: running ? s.t('Stop', 'Zastavit') : s.t('Search', 'Hledat'), onPressed: running ? () => setState(() { token++; running = false; status = 'stopped'; }) : search, icon: Icon(running ? Icons.stop : Icons.search))]), body: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Column(children: [TextField(controller: query, decoration: InputDecoration(isDense: true, prefixIcon: const Icon(Icons.search), labelText: s.t('Name contains', 'Název obsahuje')), onSubmitted: (_) => search()), Row(children: [Expanded(child: TextField(controller: extension, decoration: InputDecoration(isDense: true, labelText: s.t('Extension', 'Přípona'), hintText: 'pdf'))), const SizedBox(width: 12), Expanded(child: TextField(controller: minimum, keyboardType: TextInputType.number, decoration: InputDecoration(isDense: true, labelText: s.t('Minimum size (KiB)', 'Minimální velikost (KiB)'))))]), Row(children: [FilterChip(label: Text(s.t('Match case', 'Rozlišovat velikost')), selected: caseSensitive, onSelected: (v) => setState(() => caseSensitive = v)), const SizedBox(width: 8), FilterChip(label: Text(s.t('Hidden', 'Skryté')), selected: hidden, onSelected: (v) => setState(() => hidden = v))]), Align(alignment: Alignment.centerLeft, child: Text(widget.root, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall))])),
      if (running) const LinearProgressIndicator(),
      Padding(padding: const EdgeInsets.all(8), child: Text(s.t('${results.length} results · $visited visited · $skipped inaccessible${status == 'limit' ? ' · scan limit reached' : ''}', 'Výsledků: ${results.length} · prohledáno: $visited · nepřístupných: $skipped${status == 'limit' ? ' · dosažen limit' : ''}'), style: Theme.of(context).textTheme.labelSmall)),
      Expanded(child: ListView.builder(itemCount: results.length, itemBuilder: (context, i) { final e = results[i]; return ListTile(dense: true, leading: Icon(e.directory ? Icons.folder_outlined : Icons.insert_drive_file_outlined), title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text(e.path, maxLines: 1, overflow: TextOverflow.ellipsis), onTap: () { Navigator.pop(context); widget.onOpen(e); }); }))
    ]));
  }
}
