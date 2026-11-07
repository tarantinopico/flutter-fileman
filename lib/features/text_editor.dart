import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../core/strings.dart';
import '../models/entry.dart';
class TextEditor extends StatefulWidget {
  const TextEditor({super.key, required this.entry});
  final FileEntry entry;
  @override State<TextEditor> createState() => _TextEditorState();
}
class _TextEditorState extends State<TextEditor> {
  final controller = TextEditingController();
  bool loading = true, dirty = false, saving = false;
  String? error;
  FileStat? original;
  @override void initState() { super.initState(); load(); }
  Future<void> load() async {
    try {
      final file = File(widget.entry.path); original = await file.stat();
      if (original!.size > 2 * 1024 * 1024) throw const FormatException('Text viewer limit: 2 MiB');
      controller.text = utf8.decode(await file.readAsBytes());
      controller.addListener(() { if (!dirty && mounted) setState(() => dirty = true); });
    } catch (e) { error = '$e'; }
    if (mounted) setState(() => loading = false);
  }
  Future<void> save() async {
    setState(() => saving = true);
    final file = File(widget.entry.path);
    File? temporary;
    try {
      final current = await file.stat();
      if (current.type == FileSystemEntityType.notFound || current.modified != original!.modified || current.size != original!.size) throw const FileSystemException('File changed externally; save cancelled');
      temporary = File('${file.path}.glassfiles-${DateTime.now().microsecondsSinceEpoch}.tmp');
      await temporary.writeAsString(controller.text, flush: true);
      // Recheck after writing, before replacing the original.
      final check = await file.stat();
      if (check.modified != original!.modified || check.size != original!.size) throw const FileSystemException('File changed externally; save cancelled');
      await temporary.rename(file.path); original = await file.stat();
      if (mounted) setState(() => dirty = false);
    } catch (e) { if (temporary != null && await temporary.exists()) await temporary.delete(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    if (mounted) setState(() => saving = false);
  }
  Future<bool> confirmLeave() async {
    if (!dirty) return true;
    final s = Strings.of(context);
    return await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text(s.t('Discard changes?', 'Zahodit změny?')), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.t('Cancel', 'Zrušit'))), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.t('Discard', 'Zahodit')))])) ?? false;
  }
  @override void dispose() { controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final s = Strings.of(context);
    return PopScope(canPop: !dirty, onPopInvokedWithResult: (didPop, _) async { if (!didPop && await confirmLeave() && context.mounted) Navigator.pop(context); }, child: Scaffold(appBar: AppBar(title: Text('${widget.entry.name}${dirty ? ' •' : ''}'), actions: [IconButton(tooltip: s.t('Save', 'Uložit'), onPressed: dirty && !saving ? save : null, icon: const Icon(Icons.save_outlined))]), body: loading ? const Center(child: CircularProgressIndicator()) : error != null ? Center(child: Text(error!)) : TextField(controller: controller, expands: true, maxLines: null, keyboardType: TextInputType.multiline, style: const TextStyle(fontFamily: 'monospace', fontSize: 14), decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(16)))));
  }
}
