import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rdb_viewer/app_state.dart';
import 'package:rdb_viewer/ui/home_screen.dart';
import 'package:rdb_viewer/ui/theme/app_theme.dart';

void _writeLength(BytesBuilder b, int value) {
  if (value < 64) {
    b.addByte(value);
  } else {
    b.addByte(0x80);
    b.addByte((value >> 24) & 0xFF);
    b.addByte((value >> 16) & 0xFF);
    b.addByte((value >> 8) & 0xFF);
    b.addByte(value & 0xFF);
  }
}

void _writeRawString(BytesBuilder b, String s) {
  final bytes = utf8.encode(s);
  _writeLength(b, bytes.length);
  b.add(bytes);
}

Uint8List _buildFixture() {
  final b = BytesBuilder();
  b.add(ascii.encode('REDIS0001')); // version 1 -> no checksum, simplest.
  b.addByte(0xFE); // SELECTDB
  _writeLength(b, 0);

  b.addByte(0); // STRING
  _writeRawString(b, 'greeting');
  _writeRawString(b, 'hello');

  b.addByte(2); // SET
  _writeRawString(b, 'colors');
  _writeLength(b, 2);
  _writeRawString(b, 'red');
  _writeRawString(b, 'blue');

  b.addByte(0xFF); // EOF
  return b.toBytes();
}

void main() {
  testWidgets('open a fixture, edit a string value, export reflects the edit',
      (WidgetTester tester) async {
    // Real file I/O (Directory.createTemp, File.writeAsBytes/readAsBytes,
    // via AppState.loadFromPath) does not resolve inside flutter_test's
    // FakeAsync zone unless explicitly run through tester.runAsync().
    late Directory dir;
    late File file;
    final appState = AppState();

    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('rdb_viewer_test');
      file = File('${dir.path}/fixture.rdb');
      await file.writeAsBytes(_buildFixture());
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: appState,
        child: MaterialApp(theme: buildAppTheme(Brightness.light), home: const HomeScreen()),
      ),
    );

    await tester.runAsync(() => appState.loadFromPath(file.path));
    await tester.pumpAndSettle();

    // Both keys are listed.
    expect(find.text('greeting'), findsOneWidget);
    expect(find.text('colors'), findsOneWidget);

    // Select the string key and confirm its value is shown editable.
    await tester.tap(find.text('greeting'));
    await tester.pumpAndSettle();
    expect(find.text('hello'), findsOneWidget);

    // Edit the value.
    await tester.enterText(find.text('hello'), 'hello world');
    await tester.pumpAndSettle();

    final entry = appState.selectedEntry!;
    expect(entry.value.stringValue!.displayText, 'hello world');
    expect(entry.dirty, isTrue);

    await tester.runAsync(() => dir.delete(recursive: true));
  });
}
