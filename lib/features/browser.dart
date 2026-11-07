import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_state.dart';
import '../core/strings.dart';
import '../models/entry.dart';
import '../services/file_service.dart';
import '../widgets/glass.dart';
import 'settings_screen.dart';
import 'text_editor.dart';
import 'search_screen.dart';

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key, required this.state});
  final AppState state;
  @override State<BrowserScreen> createState() => _BrowserScreenState();
}
class _Location { _Location(this.path, this.name); final String path, name; }
class _BrowserScreenState extends State<BrowserScreen> with WidgetsBindingObserver {
  late final FileService files;
  final List<_Location> history = [];
  int historyIndex = -1;
  String root = '', path = '', title = 'Glass Files';
  List<FileEntry> entries = [], clipboard = [];
  final Set<String> selected = {};
  bool moveClipboard = false, loading = true, working = false, access = false;
  String? error;
  int generation = 0;
  AppState get state => widget.state;
  Strings get s => Strings.of(context);
  bool get isSaf => path.startsWith('content://');
  @override void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); files = FileService(state.platform); initialize(); }
  @override void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override void didChangeAppLifecycleState(AppLifecycleState lifecycle) { if (lifecycle == AppLifecycleState.resumed) refreshAccess(reload: true); }
  Future<void> refreshAccess({bool reload = false}) async { try { final value = await state.platform.call<bool>('hasAccess') ?? false; final changed = value != access; if (mounted) { setState(() => access = value); if (reload && changed && path.isNotEmpty && !isSaf) await refresh(); } } catch (_) {} }
  Future<void> initialize() async {
    try { root = await state.platform.call<String>('storageRoot') ?? '/storage/emulated/0'; await refreshAccess(); await navigate(root, 'Internal storage'); } catch (e) { if (mounted) setState(() { loading = false; error = '$e'; }); }
  }
  Future<void> navigate(String location, String name, {bool record = true}) async {
    if (record) { if (historyIndex + 1 < history.length) history.removeRange(historyIndex + 1, history.length); history.add(_Location(location, name)); historyIndex = history.length - 1; }
    setState(() { path = location; title = name; selected.clear(); });
    await refresh();
  }
  Future<void> refresh() async {
    final current = ++generation; setState(() { loading = true; error = null; });
    try { final found = await files.list(path); if (!mounted || current != generation) return; setState(() { entries = found; loading = false; }); }
    catch (e) { if (mounted && current == generation) setState(() { entries = []; error = '$e'; loading = false; }); }
  }
  void historyGo(int delta) { final next = historyIndex + delta; if (next < 0 || next >= history.length) return; historyIndex = next; final loc = history[next]; navigate(loc.path, loc.name, record: false); }
  void message(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }
  Future<void> run(Future<void> Function() task) async {
    if (working) return;
    setState(() => working = true);
    try { await task(); } catch (e) { message('$e'); }
    if (mounted) { setState(() => working = false); await refresh(); }
  }
  Future<void> askPermission() async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text(s.t('Storage access', 'Přístup k úložišti')), content: Text(s.t('To browse and manage shared files, Android can grant all-files access. This is optional: you can instead choose a folder with the system picker. Android still restricts protected folders such as Android/data and Android/obb.', 'Pro procházení a správu sdílených souborů může Android povolit přístup ke všem souborům. Je volitelný: místo toho můžete vybrat složku systémovým dialogem. Android i nadále omezuje chráněné složky jako Android/data a Android/obb.')), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.t('Not now', 'Nyní ne'))), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.t('Open settings', 'Otevřít nastavení')))]));
    if (yes == true) { try { await state.platform.call<void>('requestAccess'); } catch (e) { message('$e'); } }
  }
  Future<void> pickTree() async { try { final uri = await state.platform.call<String>('pickTree'); if (uri != null && mounted) await navigate(uri, s.t('Selected folder', 'Vybraná složka')); } catch (e) { message('$e'); } }
  Future<void> open(FileEntry entry, {bool external = false}) async {
    if (entry.directory) { await navigate(entry.path, entry.name); return; }
    final rule = state.settings.ruleFor(entry.name);
    if (!external && !entry.isDocument && rule?.action == 'text') { if (mounted) await Navigator.push(context, MaterialPageRoute(builder: (_) => TextEditor(entry: entry))); return; }
    if (!external && !entry.isDocument && entry.extension == 'zip') { if (mounted) await Navigator.push(context, MaterialPageRoute(builder: (_) => ArchiveScreen(entry: entry, state: state))); return; }
    if (!external && !entry.isDocument && rule == null && ['txt', 'log', 'json', 'xml', 'yaml', 'yml', 'md', 'csv', 'html', 'css', 'js', 'dart', 'py', 'java', 'kt'].contains(entry.extension)) { if (mounted) await Navigator.push(context, MaterialPageRoute(builder: (_) => TextEditor(entry: entry))); return; }
    try { await state.platform.call<void>('open', {'source': entry.path, 'mime': rule?.mime.isNotEmpty == true ? rule!.mime : entry.mime, 'title': s.t('Open with', 'Otevřít pomocí')}); } catch (e) { message('$e'); }
  }
  List<FileEntry> get selectedEntries => entries.where((e) => selected.contains(e.path)).toList();
  Future<String?> prompt(String label, {String initial = ''}) async {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(context: context, builder: (ctx) => AlertDialog(title: Text(label), content: TextField(controller: controller, autofocus: true, decoration: InputDecoration(labelText: s.t('Name', 'Název')), onSubmitted: (v) => Navigator.pop(ctx, v)), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.t('Cancel', 'Zrušit'))), FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: Text(s.t('OK', 'OK')))]));
  }
  Future<void> create(bool directory) async { final name = await prompt(directory ? s.t('New folder', 'Nová složka') : s.t('New file', 'Nový soubor')); if (name != null) await run(() => files.create(path, name, directory)); }
  Future<void> rename(FileEntry entry) async { final name = await prompt(s.t('Rename', 'Přejmenovat'), initial: entry.name); if (name != null) await run(() => files.rename(entry, name)); }
  Future<void> remove(List<FileEntry> targets) async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text(s.t('Permanently delete?', 'Trvale smazat?')), content: Text(s.t('${targets.length} item(s) will be permanently deleted, including folder contents. This cannot be undone.', 'Položky (${targets.length}) a obsah složek budou trvale smazány. Tuto akci nelze vrátit.')), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.t('Cancel', 'Zrušit'))), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.t('Delete', 'Smazat')))]));
    if (yes == true) await run(() async { for (final e in targets) { await files.delete(e); } selected.clear(); });
  }
  void copySelection(bool move) { setState(() { clipboard = selectedEntries; moveClipboard = move; selected.clear(); }); message(move ? s.t('Ready to move', 'Připraveno k přesunutí') : s.t('Ready to copy', 'Připraveno ke kopírování')); }
  Future<void> paste() async { final paths = clipboard.map((e) => e.path).toList(); await run(() async { await state.platform.call<void>('transfer', {'sources': paths, 'destination': path, 'move': moveClipboard}); clipboard = []; message(s.t('Transfer complete', 'Přenos dokončen')); }); }
  Future<void> share(List<FileEntry> targets) async { try { await state.platform.call<void>('share', {'sources': targets.map((e) => e.path).toList(), 'title': s.t('Share', 'Sdílet')}); } catch (e) { message('$e'); } }
  Future<void> zip(List<FileEntry> targets) async { final name = await prompt(s.t('Archive name', 'Název archivu'), initial: 'Archive.zip'); if (name == null) return; if (!files.validName(name)) { message(s.t('Invalid name', 'Neplatný název')); return; } await run(() async { await state.platform.call<void>('zipCreate', {'sources': targets.map((e) => e.path).toList(), 'output': '$path/$name'}); selected.clear(); message(s.t('Archive created', 'Archiv vytvořen')); }); }
  void bookmark() { state.update((v) { v.bookmarks = [...v.bookmarks]; if (v.bookmarks.contains(path)) { v.bookmarks.remove(path); } else { v.bookmarks.add(path); } }); message(s.t('Bookmarks updated', 'Záložky aktualizovány')); }
  Future<void> entryAction(String action, FileEntry e) async {
    switch (action) {
      case 'open': await open(e, external: true); break;
      case 'rename': await rename(e); break;
      case 'delete': await remove([e]); break;
      case 'share': await share([e]); break;
      case 'copyPath': await Clipboard.setData(ClipboardData(text: e.path)); message(s.t('Path copied', 'Cesta zkopírována')); break;
      case 'properties': if (mounted) await showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: Text(e.name), content: SelectableText('${e.path}\n${e.directory ? s.t('Folder', 'Složka') : formatSize(e.size)}\n${e.modified ?? ''}\n${e.mime ?? ''}'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.t('Close', 'Zavřít')))])); break;
    }
  }
  @override Widget build(BuildContext context) => ListenableBuilder(listenable: state, builder: (context, _) {
    final settings = state.settings;
    final visible = entries.where((e) => settings.showHidden || !e.name.startsWith('.')).toList();
    sortEntries(visible, sort: settings.sort, descending: settings.descending, foldersFirst: settings.foldersFirst);
    return PopScope(canPop: historyIndex <= 0 && selected.isEmpty, onPopInvokedWithResult: (didPop, _) { if (!didPop) { if (selected.isNotEmpty) { setState(selected.clear); } else { historyGo(-1); } } }, child: Scaffold(
      drawer: drawer(),
      appBar: AppBar(titleSpacing: 0, title: selected.isNotEmpty ? Text('${selected.length} ${s.t('selected', 'vybráno')}') : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)), Text(isSaf ? s.t('System folder', 'Systémová složka') : path, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall)]),
        actions: selected.isNotEmpty ? [
          IconButton(tooltip: s.t('Select all', 'Vybrat vše'), onPressed: () => setState(() => selected.addAll(visible.map((e) => e.path))), icon: const Icon(Icons.select_all)),
          if (!isSaf) IconButton(tooltip: s.t('Copy', 'Kopírovat'), onPressed: () => copySelection(false), icon: const Icon(Icons.copy)),
          PopupMenuButton<String>(onSelected: (v) { final items = selectedEntries; if (v == 'move') copySelection(true); if (v == 'delete') remove(items); if (v == 'zip') zip(items); if (v == 'share') share(items); if (v == 'invert') setState(() { final old = {...selected}; selected.clear(); selected.addAll(visible.where((e) => !old.contains(e.path)).map((e) => e.path)); }); }, itemBuilder: (_) => [if (!isSaf) ...[PopupMenuItem(value: 'move', child: Text(s.t('Cut', 'Vyjmout'))), PopupMenuItem(value: 'zip', child: Text(s.t('Create ZIP', 'Vytvořit ZIP'))), PopupMenuItem(value: 'delete', child: Text(s.t('Delete', 'Smazat')))], PopupMenuItem(value: 'share', child: Text(s.t('Share', 'Sdílet'))), PopupMenuItem(value: 'invert', child: Text(s.t('Invert selection', 'Invertovat výběr')))]),
        ] : [
          IconButton(tooltip: s.t('Search', 'Hledat'), onPressed: isSaf ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => SearchScreen(root: path, onOpen: open))), icon: const Icon(Icons.search)),
          IconButton(tooltip: s.t('View mode', 'Zobrazení'), onPressed: () => state.update((v) => v.grid = !v.grid), icon: Icon(settings.grid ? Icons.view_list_outlined : Icons.grid_view)),
          PopupMenuButton<String>(onSelected: (v) { if (['name', 'size', 'date', 'extension'].contains(v)) state.update((x) => x.sort = v); if (v == 'reverse') state.update((x) => x.descending = !x.descending); if (v == 'refresh') refresh(); if (v == 'folder') create(true); if (v == 'file') create(false); if (v == 'paste') paste(); if (v == 'bookmark') bookmark(); }, itemBuilder: (_) => [
            PopupMenuItem(value: 'name', child: Text(s.t('Sort: name', 'Řadit: název'))), PopupMenuItem(value: 'extension', child: Text(s.t('Sort: extension', 'Řadit: přípona'))), PopupMenuItem(value: 'size', child: Text(s.t('Sort: size', 'Řadit: velikost'))), PopupMenuItem(value: 'date', child: Text(s.t('Sort: modified', 'Řadit: změna'))), PopupMenuItem(value: 'reverse', child: Text(s.t('Reverse order', 'Obrátit pořadí'))), const PopupMenuDivider(), PopupMenuItem(value: 'refresh', child: Text(s.t('Refresh', 'Obnovit'))), PopupMenuItem(value: 'bookmark', child: Text(s.t('Toggle bookmark', 'Přepnout záložku'))), if (!isSaf) ...[PopupMenuItem(value: 'folder', child: Text(s.t('New folder', 'Nová složka'))), PopupMenuItem(value: 'file', child: Text(s.t('New file', 'Nový soubor'))), if (clipboard.isNotEmpty) PopupMenuItem(value: 'paste', child: Text(s.t('Paste ${clipboard.length} item(s)', 'Vložit položky (${clipboard.length})')))]])
        ]),
      body: Column(children: [
        Glass(intensity: settings.glass, child: SizedBox(height: 42, child: Row(children: [IconButton(visualDensity: VisualDensity.compact, tooltip: s.t('Back', 'Zpět'), onPressed: historyIndex > 0 ? () => historyGo(-1) : null, icon: const Icon(Icons.arrow_back, size: 19)), IconButton(visualDensity: VisualDensity.compact, tooltip: s.t('Forward', 'Vpřed'), onPressed: historyIndex + 1 < history.length ? () => historyGo(1) : null, icon: const Icon(Icons.arrow_forward, size: 19)), if (!isSaf) IconButton(visualDensity: VisualDensity.compact, tooltip: s.t('Parent folder', 'Nadřazená složka'), onPressed: path != '/' && path.isNotEmpty ? () { final parent = Directory(path).parent.path; navigate(parent, parent.split('/').last.isEmpty ? '/' : parent.split('/').last); } : null, icon: const Icon(Icons.arrow_upward, size: 19)), Expanded(child: breadcrumbs()), if (clipboard.isNotEmpty && !isSaf) IconButton(tooltip: s.t('Paste', 'Vložit'), onPressed: working ? null : paste, icon: const Icon(Icons.content_paste, size: 20))]))),
        if (!access && !isSaf) MaterialBanner(content: Text(s.t('Shared storage access is optional. Grant access or choose a folder.', 'Přístup ke sdílenému úložišti je volitelný. Povolte přístup nebo vyberte složku.')), actions: [TextButton(onPressed: pickTree, child: Text(s.t('Choose folder', 'Vybrat složku'))), TextButton(onPressed: askPermission, child: Text(s.t('Access', 'Přístup')))]),
        if (isSaf) Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: Text(s.t('System folder: browse and open only. Editing and transfers are not yet supported here.', 'Systémová složka: pouze procházení a otevření. Úpravy a přenosy zde zatím nejsou podporovány.'), style: Theme.of(context).textTheme.labelSmall)),
        if (working) const LinearProgressIndicator(),
        Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : error != null ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.folder_off_outlined, size: 40), const SizedBox(height: 12), Text(error!, textAlign: TextAlign.center), TextButton(onPressed: refresh, child: Text(s.t('Retry', 'Opakovat')))]))) : visible.isEmpty ? Center(child: Text(s.t('This folder is empty', 'Tato složka je prázdná'))) : RefreshIndicator(onRefresh: refresh, child: settings.grid ? GridView.builder(padding: const EdgeInsets.all(8), gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 150, mainAxisExtent: 124), itemCount: visible.length, itemBuilder: (_, i) => gridItem(visible[i])) : ListView.builder(itemCount: visible.length, itemBuilder: (_, i) => row(visible[i])))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Row(children: [Text(s.t('${visible.length} items', 'Položek: ${visible.length}'), style: Theme.of(context).textTheme.labelSmall), const Spacer(), if (working) Text(s.t('Working…', 'Pracuji…'), style: Theme.of(context).textTheme.labelSmall)]))
      ])));
  });
  Widget breadcrumbs() {
    if (isSaf) return Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium);
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    var current = '';
    final crumbs = <Widget>[];
    for (final part in parts) {
      current += '/$part';
      final destination = current;
      crumbs.add(InkWell(onTap: () => navigate(destination, part), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6), child: Text(part, style: Theme.of(context).textTheme.labelMedium))));
      if (destination != path) crumbs.add(const Icon(Icons.chevron_right, size: 14));
    }
    return SingleChildScrollView(scrollDirection: Axis.horizontal, reverse: true, child: Row(children: crumbs));
  }
  IconData iconFor(FileEntry e) { if (e.directory) return Icons.folder_rounded; if (['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(e.extension)) return Icons.image_outlined; if (['mp3', 'wav', 'ogg', 'flac'].contains(e.extension)) return Icons.audio_file_outlined; if (['mp4', 'mkv', 'webm'].contains(e.extension)) return Icons.video_file_outlined; if (e.extension == 'zip') return Icons.folder_zip_outlined; if (e.extension == 'pdf') return Icons.picture_as_pdf_outlined; return Icons.insert_drive_file_outlined; }
  Widget row(FileEntry e) => Material(color: selected.contains(e.path) ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .45) : Colors.transparent, child: InkWell(onTap: () { if (selected.isNotEmpty) { setState(() => selected.contains(e.path) ? selected.remove(e.path) : selected.add(e.path)); } else { open(e); } }, onLongPress: () => setState(() => selected.add(e.path)), child: SizedBox(height: state.settings.density, child: Row(children: [const SizedBox(width: 16), Icon(selected.contains(e.path) ? Icons.check_circle : iconFor(e), size: state.settings.iconSize, color: e.directory ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)), Text(e.directory ? s.t('Folder', 'Složka') : '${formatSize(e.size)}  ·  ${e.modified?.toLocal().toString().split('.').first ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall)])), menu(e)]))));
  Widget gridItem(FileEntry e) => InkWell(onTap: () { if (selected.isNotEmpty) { setState(() => selected.contains(e.path) ? selected.remove(e.path) : selected.add(e.path)); } else { open(e); } }, onLongPress: () => setState(() => selected.add(e.path)), child: Container(margin: const EdgeInsets.all(3), decoration: BoxDecoration(color: selected.contains(e.path) ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .45) : Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(selected.contains(e.path) ? Icons.check_circle : iconFor(e), size: 36, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 8), Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(e.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)), SizedBox(height: 26, child: menu(e))])));
  Widget menu(FileEntry e) => PopupMenuButton<String>(padding: EdgeInsets.zero, tooltip: s.t('More', 'Další'), icon: const Icon(Icons.more_vert, size: 19), onSelected: (v) => entryAction(v, e), itemBuilder: (_) => [if (!e.directory) PopupMenuItem(value: 'open', child: Text(s.t('Open with', 'Otevřít pomocí'))), if (!e.directory) PopupMenuItem(value: 'share', child: Text(s.t('Share', 'Sdílet'))), if (!e.isDocument) ...[PopupMenuItem(value: 'rename', child: Text(s.t('Rename', 'Přejmenovat'))), PopupMenuItem(value: 'delete', child: Text(s.t('Delete', 'Smazat')))], PopupMenuItem(value: 'copyPath', child: Text(s.t('Copy path / URI', 'Kopírovat cestu / URI'))), PopupMenuItem(value: 'properties', child: Text(s.t('Properties', 'Vlastnosti')))]);
  Widget drawer() {
    Widget item(IconData icon, String label, VoidCallback action) => ListTile(dense: true, leading: Icon(icon, size: 21), title: Text(label), onTap: () { Navigator.pop(context); action(); });
    final bookmarks = state.settings.bookmarks;
    return Drawer(child: SafeArea(child: ListView(padding: EdgeInsets.zero, children: [Padding(padding: const EdgeInsets.fromLTRB(20, 24, 20, 20), child: Row(children: [Icon(Icons.folder_copy_rounded, color: Theme.of(context).colorScheme.primary, size: 30), const SizedBox(width: 12), const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('GLASS FILES', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.4)), Text('A little more room to focus', style: TextStyle(fontSize: 11))])])),
      item(Icons.phone_android, s.t('Internal storage', 'Interní úložiště'), () => navigate(root, s.t('Internal storage', 'Interní úložiště'))),
      for (final pair in [('Download', Icons.download_outlined, s.t('Downloads', 'Stažené')), ('Documents', Icons.description_outlined, s.t('Documents', 'Dokumenty')), ('Pictures', Icons.image_outlined, s.t('Pictures', 'Obrázky')), ('Movies', Icons.movie_outlined, s.t('Videos', 'Videa')), ('Music', Icons.music_note_outlined, s.t('Music', 'Hudba'))]) item(pair.$2, pair.$3, () => navigate('$root/${pair.$1}', pair.$3)),
      item(Icons.folder_open, s.t('Choose a system folder', 'Vybrat systémovou složku'), pickTree),
      if (bookmarks.isNotEmpty) ...[const Divider(), Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: Text(s.t('BOOKMARKS', 'ZÁLOŽKY'), style: Theme.of(context).textTheme.labelSmall)), for (final b in bookmarks) item(Icons.bookmark_outline, b.startsWith('content://') ? s.t('System folder', 'Systémová složka') : b.split('/').last, () => navigate(b, b.startsWith('content://') ? s.t('System folder', 'Systémová složka') : b.split('/').last))],
      const Divider(), item(Icons.settings_outlined, s.t('Settings', 'Nastavení'), () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(state: state)))), item(Icons.security_outlined, s.t('Storage access', 'Přístup k úložišti'), askPermission),
    ])));
  }
}
class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key, required this.entry, required this.state});
  final FileEntry entry; final AppState state;
  @override State<ArchiveScreen> createState() => _ArchiveScreenState();
}
class _ArchiveScreenState extends State<ArchiveScreen> {
  late Future<List<dynamic>> list;
  bool busy = false;
  @override void initState() { super.initState(); list = widget.state.platform.call<List<dynamic>>('zipList', {'path': widget.entry.path}).then((x) => x ?? []); }
  Future<void> extract() async {
    final s = Strings.of(context);
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text(s.t('Extract archive?', 'Rozbalit archiv?')), content: Text(s.t('Extract into the archive’s current folder. Existing files are never overwritten; extraction stops at the first conflict. Limit: 1 GiB.', 'Rozbalit do aktuální složky archivu. Existující soubory se nepřepisují; při konfliktu se rozbalování zastaví. Limit: 1 GiB.')), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.t('Cancel', 'Zrušit'))), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.t('Extract', 'Rozbalit')))]));
    if (yes != true || !mounted) return; setState(() => busy = true);
    try { await widget.state.platform.call<void>('zipExtract', {'path': widget.entry.path, 'destination': File(widget.entry.path).parent.path}); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('Extraction complete', 'Rozbalení dokončeno')))); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    if (mounted) setState(() => busy = false);
  }
  @override Widget build(BuildContext context) { final s = Strings.of(context); return Scaffold(appBar: AppBar(title: Text(widget.entry.name), actions: [IconButton(tooltip: s.t('Extract all', 'Rozbalit vše'), onPressed: busy ? null : extract, icon: const Icon(Icons.unarchive_outlined))]), body: Column(children: [if (busy) const LinearProgressIndicator(), Expanded(child: FutureBuilder<List<dynamic>>(future: list, builder: (context, snapshot) { if (snapshot.hasError) return Center(child: Text('${snapshot.error}')); if (!snapshot.hasData) return const Center(child: CircularProgressIndicator()); final entries = snapshot.data!; return ListView.builder(itemCount: entries.length, itemBuilder: (_, i) => ListTile(dense: true, leading: const Icon(Icons.insert_drive_file_outlined), title: Text('${entries[i]}'))); }))])); }
}
