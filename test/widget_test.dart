import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glassfiles/core/app_state.dart';
import 'package:glassfiles/features/settings_screen.dart';
import 'package:glassfiles/services/platform_service.dart';
void main() {
  testWidgets('settings displays association entry without bottom navigation', (tester) async {
    final state = AppState(PlatformService());
    await tester.pumpWidget(MaterialApp(home: SettingsScreen(state: state)));
    expect(find.text('File types & associations'), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);
  });
}
