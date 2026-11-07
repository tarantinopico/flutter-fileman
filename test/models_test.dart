import 'package:flutter_test/flutter_test.dart';
import 'package:glassfiles/models/entry.dart';
import 'package:glassfiles/models/settings.dart';
void main() {
  group('file type rules', () {
    test('matches extensions without case sensitivity', () { final r = FileRule(name: 'Code', extensions: '.dart, abc'); expect(r.matches('main.DART'), isTrue); expect(r.matches('x.abc'), isTrue); expect(r.matches('notdart'), isFalse); });
    test('highest priority matching rule wins', () { final a = FileRule(name: 'low', extensions: 'abc', priority: 1); final b = FileRule(name: 'high', extensions: 'abc', priority: 9); expect(AppSettings(rules: [a, b]).ruleFor('x.abc')?.name, 'high'); });
  });
  test('settings round trip preserves rules and preferences', () { final s = AppSettings(glass: .7, showHidden: true, bookmarks: ['/storage/test'], rules: [FileRule(name: 'A', extensions: 'abc', mime: 'text/plain', action: 'text')]); final restored = AppSettings.decode(s.encode()); expect(restored.glass, .7); expect(restored.showHidden, isTrue); expect(restored.bookmarks, ['/storage/test']); expect(restored.ruleFor('test.abc')?.mime, 'text/plain'); });
  test('rejects unsupported settings schema', () { expect(() => AppSettings.decode('{"version": 2}'), throwsFormatException); });
  test('rejects invalid imported settings', () { expect(() => AppSettings.decode('{"version":1,"theme":"invalid"}'), throwsFormatException); });
  test('sort keeps folders first when descending', () { final list = [FileEntry(path: 'a', name: 'a', directory: false), FileEntry(path: 'b', name: 'b', directory: true), FileEntry(path: 'c', name: 'c', directory: false)]; sortEntries(list, descending: true); expect(list.map((e) => e.name).toList(), ['b', 'c', 'a']); });
  test('size formatter', () { expect(formatSize(1024), '1.0 KB'); });
}
