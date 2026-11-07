import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/app_state.dart';
import 'features/browser.dart';
import 'services/platform_service.dart';

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(GlassFilesApp(state: AppState(PlatformService())..load())); }
class GlassFilesApp extends StatelessWidget {
  const GlassFilesApp({super.key, required this.state});
  final AppState state;
  @override Widget build(BuildContext context) => ListenableBuilder(listenable: state, builder: (context, _) {
    final s = state.settings;
    final seed = Color(s.accent);
    ThemeData theme(Brightness brightness) => ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: brightness), visualDensity: VisualDensity.compact, scaffoldBackgroundColor: brightness == Brightness.dark ? const Color(0xff10141e) : const Color(0xfff5f8fa), fontFamily: 'Roboto');
    return MaterialApp(title: 'Glass Files', debugShowCheckedModeBanner: false, theme: theme(Brightness.light), darkTheme: theme(Brightness.dark), themeMode: s.theme == 'system' ? ThemeMode.system : s.theme == 'light' ? ThemeMode.light : ThemeMode.dark, locale: s.language == 'system' ? null : Locale(s.language), supportedLocales: const [Locale('en'), Locale('cs')], localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], home: BrowserScreen(state: state));
  });
}
