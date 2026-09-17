// Basic smoke test: the app boots and shows the empty state.
import 'package:flutter_test/flutter_test.dart';

import 'package:rdb_viewer/main.dart';

void main() {
  testWidgets('App shows the empty state on startup', (WidgetTester tester) async {
    await tester.pumpWidget(const RdbViewerApp());

    expect(find.text('Keine RDB-Datei geöffnet'), findsOneWidget);
    expect(find.text('RDB-Datei öffnen'), findsWidgets);
  });
}
