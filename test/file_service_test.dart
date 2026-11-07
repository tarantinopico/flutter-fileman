import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:glassfiles/services/file_service.dart';
import 'package:glassfiles/services/platform_service.dart';
void main() {
  late Directory temp;
  late FileService service;
  setUp(() async { temp = await Directory.systemTemp.createTemp('glassfiles_test'); service = FileService(PlatformService()); });
  tearDown(() async { await temp.delete(recursive: true); });
  test('create, list and rename files', () async { await service.create(temp.path, 'a.txt', false); final entries = await service.list(temp.path); expect(entries.single.name, 'a.txt'); await service.rename(entries.single, 'b.txt'); expect(await File('${temp.path}/b.txt').exists(), true); });
  test('refuses invalid names and existing targets', () async { await expectLater(service.create(temp.path, '../escape', false), throwsFormatException); await service.create(temp.path, 'same', false); await expectLater(service.create(temp.path, 'same', false), throwsA(isA<FileSystemException>())); });
}
