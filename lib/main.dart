import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'ui/home_screen.dart';
import 'ui/theme/app_theme.dart';

void main(List<String> args) {
  // Support launching with a file path argument (e.g. Windows "Open with",
  // or a shortcut/command line) so a .rdb file opens immediately instead of
  // requiring the file picker.
  final openPath = args.isNotEmpty ? args.first : null;
  runApp(RdbViewerApp(initialFilePath: openPath));
}

class RdbViewerApp extends StatelessWidget {
  const RdbViewerApp({super.key, this.initialFilePath});

  final String? initialFilePath;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final state = AppState();
        if (initialFilePath != null) {
          // Fire and forget - the UI shows the normal loading/error states.
          state.loadFromPath(initialFilePath!);
        }
        return state;
      },
      child: MaterialApp(
        title: 'RDB Viewer',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(Brightness.light),
        darkTheme: buildAppTheme(Brightness.dark),
        home: const HomeScreen(),
      ),
    );
  }
}
