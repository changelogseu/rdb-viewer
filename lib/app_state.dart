import 'dart:io';

import 'package:flutter/foundation.dart';

import 'rdb/byte_reader.dart';
import 'rdb/rdb_model.dart';
import 'rdb/rdb_parser.dart';

enum LoadStatus { idle, loading, loaded, error }

/// Central application state: the currently loaded RDB document plus the
/// UI's view over it (selected database, search/filter, selected key).
///
/// Phase 1 scope: values can be edited in memory (edits are tracked via
/// [RdbEntry.dirty]) but are not written back into a .rdb file - see the
/// export/ directory for JSON and redis-command export instead.
class AppState extends ChangeNotifier {
  RdbDocument? document;
  LoadStatus status = LoadStatus.idle;
  String? loadErrorMessage;
  String? loadWarningMessage;

  int selectedDbIndex = 0;
  RdbEntry? selectedEntry;
  String searchQuery = '';
  RdbValueKind? typeFilter;

  bool get hasDocument => document != null;

  int get editedKeyCount {
    final doc = document;
    if (doc == null) return 0;
    var count = 0;
    for (final db in doc.databases) {
      count += db.entries.where((e) => e.dirty).length;
    }
    return count;
  }

  Future<void> loadFromPath(String path) async {
    status = LoadStatus.loading;
    loadErrorMessage = null;
    loadWarningMessage = null;
    notifyListeners();
    try {
      final bytes = await File(path).readAsBytes();
      await _loadFromBytes(bytes, path);
    } catch (e) {
      status = LoadStatus.error;
      loadErrorMessage = _describeError(e);
      notifyListeners();
    }
  }

  Future<void> _loadFromBytes(Uint8List bytes, String path) async {
    final doc = parseRdbFile(bytes, sourcePath: path);
    document = doc;
    status = LoadStatus.loaded;
    selectedDbIndex = doc.databases.isNotEmpty ? doc.databases.first.index : 0;
    selectedEntry = null;
    searchQuery = '';
    typeFilter = null;

    final warnings = <String>[];
    if (doc.fatalStopReason != null) {
      warnings.add(doc.fatalStopReason!);
    }
    if (doc.unparsedKeys.isNotEmpty) {
      warnings.add(
        '${doc.unparsedKeys.length} Schlüssel mit nicht unterstütztem Typ '
        'gefunden (z.B. Streams, Module, Hash-Feld-TTL) - das Lesen wurde an '
        'dieser Stelle gestoppt. Details im Tab "Info".',
      );
    }
    if (doc.checksumStatus == ChecksumStatus.mismatch) {
      warnings.add(
        'CRC64-Prüfsumme stimmt nicht überein - die Datei könnte beschädigt '
        'oder unvollständig sein.',
      );
    }
    loadWarningMessage = warnings.isEmpty ? null : warnings.join('\n');
    notifyListeners();
  }

  String _describeError(Object e) {
    if (e is RdbFormatException || e is RdbTruncatedException || e is RdbUnsupportedTypeException) {
      return e.toString();
    }
    return 'Unerwarteter Fehler beim Lesen der Datei: $e';
  }

  RdbDatabase? get selectedDb {
    final doc = document;
    if (doc == null) return null;
    for (final db in doc.databases) {
      if (db.index == selectedDbIndex) return db;
    }
    return doc.databases.isNotEmpty ? doc.databases.first : null;
  }

  List<RdbEntry> get filteredEntries {
    final db = selectedDb;
    if (db == null) return const [];
    Iterable<RdbEntry> result = db.entries;
    if (typeFilter != null) {
      result = result.where((e) => e.value.kind == typeFilter);
    }
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      result = result.where((e) => e.key.displayText.toLowerCase().contains(q));
    }
    return result.toList();
  }

  void selectDb(int index) {
    selectedDbIndex = index;
    selectedEntry = null;
    notifyListeners();
  }

  void selectEntry(RdbEntry entry) {
    selectedEntry = entry;
    notifyListeners();
  }

  void setSearchQuery(String q) {
    searchQuery = q;
    notifyListeners();
  }

  void setTypeFilter(RdbValueKind? kind) {
    typeFilter = kind;
    notifyListeners();
  }

  /// Call after any in-place mutation of an entry's value/expiry so the UI
  /// refreshes and the entry is flagged as changed.
  void markDirty(RdbEntry entry) {
    entry.dirty = true;
    notifyListeners();
  }

  /// True if [dbIndex] already has a key with exactly this text - used by
  /// the "add key" dialog to refuse silently-overwriting duplicates.
  bool keyExistsInDb(int dbIndex, String keyText) {
    final doc = document;
    if (doc == null) return false;
    for (final db in doc.databases) {
      if (db.index != dbIndex) continue;
      return db.entries.any((e) => e.key.displayText == keyText);
    }
    return false;
  }

  /// Adds a freshly created entry (see `AddKeyDialog`) to [dbIndex],
  /// creating that database section if it doesn't exist yet (e.g. an empty
  /// source file, or a database index not present in it), then selects it.
  void addEntry({required int dbIndex, required RdbEntry entry}) {
    final doc = document;
    if (doc == null) return;
    RdbDatabase? db;
    for (final candidate in doc.databases) {
      if (candidate.index == dbIndex) {
        db = candidate;
        break;
      }
    }
    if (db == null) {
      db = RdbDatabase(dbIndex);
      doc.databases.add(db);
      doc.databases.sort((a, b) => a.index.compareTo(b.index));
    }
    db.entries.add(entry);
    selectedDbIndex = dbIndex;
    searchQuery = '';
    typeFilter = null;
    selectedEntry = entry;
    notifyListeners();
  }

  /// Removes [entry] from whichever database currently holds it.
  void deleteEntry(RdbEntry entry) {
    final doc = document;
    if (doc == null) return;
    for (final db in doc.databases) {
      if (db.entries.remove(entry)) break;
    }
    if (identical(selectedEntry, entry)) {
      selectedEntry = null;
    }
    notifyListeners();
  }

  void reset() {
    document = null;
    status = LoadStatus.idle;
    loadErrorMessage = null;
    loadWarningMessage = null;
    selectedEntry = null;
    searchQuery = '';
    typeFilter = null;
    notifyListeners();
  }
}
