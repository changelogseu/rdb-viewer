import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

/// Opens a native "open file" dialog filtered to .rdb files and returns the
/// chosen path, or null if the user cancelled.
Future<String?> pickRdbFilePath() async {
  const typeGroup = XTypeGroup(
    label: 'Redis RDB',
    extensions: ['rdb'],
  );
  final file = await openFile(acceptedTypeGroups: [typeGroup]);
  return file?.path;
}

/// Opens a native "save file" dialog and writes [content] as UTF-8 text to
/// the chosen location. Returns the chosen path, or null if cancelled.
Future<String?> saveTextFile({
  required String suggestedName,
  required String content,
  List<String> acceptedExtensions = const ['json'],
}) async {
  final typeGroup = XTypeGroup(label: 'Export', extensions: acceptedExtensions);
  final location = await getSaveLocation(
    suggestedName: suggestedName,
    acceptedTypeGroups: [typeGroup],
  );
  if (location == null) return null;
  final file = File(location.path);
  await file.writeAsString(content);
  return location.path;
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
}
