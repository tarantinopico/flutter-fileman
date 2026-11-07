import 'package:flutter/widgets.dart';
class Strings {
  Strings(this.cs);
  final bool cs;
  static Strings of(BuildContext context) => Strings(Localizations.localeOf(context).languageCode == 'cs');
  String t(String en, String cz) => cs ? cz : en;
}
