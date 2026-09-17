import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rdb_viewer/app_state.dart';
import 'package:rdb_viewer/rdb/rdb_model.dart';
import 'package:rdb_viewer/ui/home_screen.dart';
import 'package:rdb_viewer/ui/theme/app_theme.dart';

void _writeLength(BytesBuilder b, int value) {
  b.addByte(value); // small fixture, values always < 64
}

void _writeRawString(BytesBuilder b, String s) {
  final bytes = utf8.encode(s);
  _writeLength(b, bytes.length);
  b.add(bytes);
}

Uint8List _buildFixture() {
  final b = BytesBuilder();
  b.add(ascii.encode('REDIS0001'));
  b.addByte(0xFE); // SELECTDB
  _writeLength(b, 0);
  b.addByte(0); // STRING
  _writeRawString(b, 'existing');
  _writeRawString(b, 'value');
  b.addByte(0xFF); // EOF
  return b.toBytes();
}

void main() {
  testWidgets('add a new key via the dialog, then delete it',
      (WidgetTester tester) async {
    late Directory dir;
    late File file;
    final appState = AppState();

    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('rdb_viewer_add_test');
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

    expect(find.text('existing'), findsOneWidget);

    // Open the "add key" dialog.
    await tester.tap(find.byTooltip('Neuer Schlüssel'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Schlüsselname'), 'brand-new');
    // Pick "hash" as the type.
    await tester.tap(find.widgetWithText(ChoiceChip, 'hash'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Erstellen'));
    await tester.pumpAndSettle();

    // The new key is now listed and selected (it shows up twice: once in
    // the key list, once as the current value in the header's key-name
    // field).
    expect(find.text('brand-new'), findsWidgets);
    final newEntry = appState.selectedEntry!;
    expect(newEntry.key.displayText, 'brand-new');
    expect(newEntry.value.kind, RdbValueKind.hash);
    expect(newEntry.value.hashValue, isEmpty);
    expect(newEntry.isNew, isTrue);

    // Adding the same name again in the same DB is refused.
    await tester.tap(find.byTooltip('Neuer Schlüssel'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Schlüsselname'), 'brand-new');
    await tester.tap(find.text('Erstellen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('existiert bereits'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    // Delete the new key again.
    await tester.tap(find.byTooltip('Schlüssel löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();

    expect(find.text('brand-new'), findsNothing);
    expect(appState.selectedEntry, isNull);

    await tester.runAsync(() => dir.delete(recursive: true));
  });
}
