import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_state.dart';
import '../core/strings.dart';
import '../models/settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.state});
  final AppState state;
  @override Widget build(BuildContext context) => ListenableBuilder(listenable: state, builder: (context, _) {
    final s = Strings.of(context); final v = state.settings;
    return Scaffold(appBar: AppBar(title: Text(s.t('Settings', 'Nastavení'))), body: ListView(children: [
      _heading(context, s.t('Appearance & layout', 'Vzhled a rozložení')),
      ListTile(title: Text(s.t('Theme', 'Motiv')), trailing: DropdownButton<String>(value: v.theme, items: ['dark', 'light', 'system'].map((x) => DropdownMenuItem(value: x, child: Text(x == 'dark' ? s.t('Dark', 'Tmavý') : x == 'light' ? s.t('Light', 'Světlý') : s.t('System', 'Systémový')))).toList(), onChanged: (x) => state.update((v) => v.theme = x!))),
      ListTile(title: Text(s.t('Accent', 'Barva')), trailing: Wrap(spacing: 4, children: [0xff80ccdb, 0xffa9b8ff, 0xffb8dba4, 0xffffb5a7].map((c) => IconButton(tooltip: s.t('Accent color', 'Barva motivu'), onPressed: () => state.update((v) => v.accent = c), icon: Icon(v.accent == c ? Icons.check_circle : Icons.circle, color: Color(c)))).toList())),
      ListTile(title: Text(s.t('Glass intensity', 'Intenzita skla')), subtitle: Slider(value: v.glass, onChanged: (x) => state.update((v) => v.glass = x))),
      ListTile(title: Text(s.t('Row height', 'Výška řádku')), subtitle: Slider(value: v.density, min: 44, max: 80, divisions: 9, label: v.density.round().toString(), onChanged: (x) => state.update((v) => v.density = x))),
      ListTile(title: Text(s.t('Icon size', 'Velikost ikon')), subtitle: Slider(value: v.iconSize, min: 18, max: 40, divisions: 11, label: v.iconSize.round().toString(), onChanged: (x) => state.update((v) => v.iconSize = x))),
      SwitchListTile(title: Text(s.t('Show hidden files', 'Zobrazit skryté soubory')), value: v.showHidden, onChanged: (x) => state.update((v) => v.showHidden = x)),
      SwitchListTile(title: Text(s.t('Folders first', 'Složky nejdříve')), value: v.foldersFirst, onChanged: (x) => state.update((v) => v.foldersFirst = x)),
      _heading(context, s.t('General', 'Obecné')),
      ListTile(title: Text(s.t('Language', 'Jazyk')), trailing: DropdownButton<String>(value: v.language, items: [DropdownMenuItem(value: 'system', child: Text(s.t('System', 'Systémový'))), const DropdownMenuItem(value: 'en', child: Text('English')), const DropdownMenuItem(value: 'cs', child: Text('Čeština'))], onChanged: (x) => state.update((v) => v.language = x!))),
      ListTile(leading: const Icon(Icons.rule_folder_outlined), title: Text(s.t('File types & associations', 'Typy souborů a přiřazení')), subtitle: Text(s.t('Extensions, MIME types and opening rules', 'Přípony, MIME typy a pravidla otevření')), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RulesScreen(state: state)))),
      ListTile(leading: const Icon(Icons.security_outlined), title: Text(s.t('Storage access', 'Přístup k úložišti')), subtitle: Text(s.t('Open Android access settings', 'Otevřít systémové nastavení přístupu')), onTap: () async { final allowed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text(s.t('Storage access', 'Přístup k úložišti')), content: Text(s.t('All-files access allows this app to manage shared files. It is optional, and Android still restricts protected folders. You can instead choose a folder in the drawer.', 'Přístup ke všem souborům umožní aplikaci spravovat sdílené soubory. Je volitelný a Android stále omezuje chráněné složky. Místo toho můžete vybrat složku v nabídce.')), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.t('Cancel', 'Zrušit'))), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.t('Open settings', 'Otevřít nastavení')))])); if (allowed == true) { try { await state.platform.call<void>('requestAccess'); } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); } } }),
      ListTile(leading: const Icon(Icons.copy_all_outlined), title: Text(s.t('Export settings to clipboard', 'Exportovat nastavení do schránky')), onTap: () async { await Clipboard.setData(ClipboardData(text: v.encode())); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('Settings copied', 'Nastavení zkopírováno')))); }),
      ListTile(leading: const Icon(Icons.restore), title: Text(s.t('Import settings from clipboard', 'Importovat nastavení ze schránky')), onTap: () async { try { final text = (await Clipboard.getData('text/plain'))?.text; if (text == null) throw const FormatException('Clipboard is empty'); final imported = AppSettings.decode(text); state.settings = imported; state.update((_) {}); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('Settings imported', 'Nastavení importováno')))); } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); } }),
      ListTile(leading: const Icon(Icons.info_outline), title: Text(s.t('About', 'O aplikaci')), subtitle: Text(s.t('Glass Files · Local-first · No analytics', 'Glass Files · Lokální data · Bez analytiky'))),
    ]));
  });
  Widget _heading(BuildContext context, String text) => Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 4), child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)));
}
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key, required this.state});
  final AppState state;
  @override Widget build(BuildContext context) => ListenableBuilder(listenable: state, builder: (context, _) {
    final s = Strings.of(context); final rules = state.settings.rules;
    return Scaffold(appBar: AppBar(title: Text(s.t('File types', 'Typy souborů'))), floatingActionButton: FloatingActionButton(onPressed: () => editRule(context, state), child: const Icon(Icons.add)), body: rules.isEmpty ? Center(child: Text(s.t('Add a rule for an extension', 'Přidejte pravidlo pro příponu'))) : ListView.builder(itemCount: rules.length, itemBuilder: (context, i) { final rule = rules[i]; return ListTile(leading: const Icon(Icons.extension_outlined), title: Text(rule.name), subtitle: Text('${rule.extensions}  ·  ${rule.mime.isEmpty ? '*/*' : rule.mime}  ·  ${rule.action}  ·  ${rule.priority}'), onTap: () => editRule(context, state, index: i), trailing: IconButton(tooltip: s.t('Delete', 'Smazat'), icon: const Icon(Icons.delete_outline), onPressed: () => state.update((v) => v.rules = [...v.rules]..removeAt(i)))); }));
  });
}
Future<void> editRule(BuildContext context, AppState state, {int? index}) async {
  final s = Strings.of(context); final old = index == null ? null : state.settings.rules[index];
  final name = TextEditingController(text: old?.name ?? ''); final extensions = TextEditingController(text: old?.extensions ?? ''); final mime = TextEditingController(text: old?.mime ?? ''); final priority = TextEditingController(text: '${old?.priority ?? 0}'); var action = old?.action ?? 'ask';
  await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(title: Text(s.t('File type', 'Typ souboru')), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
    TextField(controller: name, decoration: InputDecoration(labelText: s.t('Name', 'Název'))),
    TextField(controller: extensions, decoration: InputDecoration(labelText: s.t('Extensions, comma separated', 'Přípony oddělené čárkou'), hintText: 'abc, xyz')),
    TextField(controller: mime, decoration: const InputDecoration(labelText: 'MIME', hintText: 'text/plain')),
    TextField(controller: priority, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: s.t('Priority (higher wins)', 'Priorita (vyšší vyhrává)'))),
    DropdownButtonFormField<String>(value: action, decoration: InputDecoration(labelText: s.t('Open action', 'Akce při otevření')), items: [DropdownMenuItem(value: 'ask', child: Text(s.t('Android chooser', 'Výběr aplikace Android'))), DropdownMenuItem(value: 'text', child: Text(s.t('Built-in text editor (local files)', 'Vestavěný textový editor (lokální soubory)')))], onChanged: (x) => set(() => action = x!)),
  ])), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.t('Cancel', 'Zrušit'))), FilledButton(onPressed: () { if (name.text.trim().isEmpty || extensions.text.trim().isEmpty) return; final rule = FileRule(name: name.text.trim(), extensions: extensions.text.trim(), mime: mime.text.trim(), action: action, priority: int.tryParse(priority.text) ?? 0); state.update((v) { v.rules = [...v.rules]; if (index == null) { v.rules.add(rule); } else { v.rules[index] = rule; } }); Navigator.pop(ctx); }, child: Text(s.t('Save', 'Uložit')))])));
}
