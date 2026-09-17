import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../export/command_export.dart';
import '../../export/json_export.dart';
import '../../rdb/rdb_model.dart';
import '../file_io.dart';
import '../theme/app_theme.dart';
import 'type_badge.dart';
import 'value_editors.dart';

class ValueDetailPanel extends StatelessWidget {
  const ValueDetailPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final entry = appState.selectedEntry;
    if (entry == null) {
      return Center(
        child: Text(
          'Wähle links einen Schlüssel aus.',
          style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(entry: entry, appState: appState),
        const Divider(height: 1),
        Expanded(child: _buildEditor(entry, appState)),
      ],
    );
  }

  Widget _buildEditor(RdbEntry entry, AppState appState) {
    switch (entry.value.kind) {
      case RdbValueKind.string:
        return StringValueEditor(key: ValueKey(entry), entry: entry, appState: appState);
      case RdbValueKind.list:
        return ListValueEditor(key: ValueKey(entry), entry: entry, appState: appState);
      case RdbValueKind.hash:
        return HashValueEditor(key: ValueKey(entry), entry: entry, appState: appState);
      case RdbValueKind.set:
        return SetValueEditor(key: ValueKey(entry), entry: entry, appState: appState);
      case RdbValueKind.zset:
        return ZsetValueEditor(key: ValueKey(entry), entry: entry, appState: appState);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.entry, required this.appState});
  final RdbEntry entry;
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TypeBadge(kind: entry.value.kind),
              const SizedBox(width: 12),
              Expanded(
                child: RdbStringField(
                  key: ValueKey('key-${entry.hashCode}'),
                  value: entry.key,
                  labelText: 'Schlüssel',
                  onChanged: (s) {
                    entry.key = s;
                    appState.markDirty(entry);
                  },
                ),
              ),
              const SizedBox(width: 12),
              PopupMenuButton<_ExportAction>(
                tooltip: 'Exportieren',
                icon: const Icon(Icons.ios_share),
                onSelected: (action) => _handleExport(context, action),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _ExportAction.copyJson,
                    child: Text('Als JSON kopieren'),
                  ),
                  PopupMenuItem(
                    value: _ExportAction.copyCommands,
                    child: Text('Als Redis-Befehle kopieren'),
                  ),
                  PopupMenuItem(
                    value: _ExportAction.saveJson,
                    child: Text('Als JSON-Datei speichern...'),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Schlüssel löschen',
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(entry.originalEncodingLabel ?? entry.value.kind.name),
              ),
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text('${entry.value.elementCount} Elemente'),
              ),
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text('≈ ${_formatBytes(entry.value.approxByteSize)}'),
              ),
              if (entry.isNew)
                const _StatusChip(label: 'neu', color: AppColors.success, bg: AppColors.successBg)
              else if (entry.dirty)
                const _StatusChip(
                    label: 'geändert', color: AppColors.warning, bg: AppColors.warningBg),
              _TtlEditor(entry: entry, appState: appState),
            ],
          ),
        ],
      ),
    );
  }

  void _handleExport(BuildContext context, _ExportAction action) async {
    switch (action) {
      case _ExportAction.copyJson:
        await Clipboard.setData(ClipboardData(text: exportEntryToJson(entry)));
        if (context.mounted) showSnack(context, 'JSON in die Zwischenablage kopiert.');
        break;
      case _ExportAction.copyCommands:
        final commands = commandsForEntry(entry).join('\n');
        await Clipboard.setData(ClipboardData(text: commands));
        if (context.mounted) showSnack(context, 'Redis-Befehle in die Zwischenablage kopiert.');
        break;
      case _ExportAction.saveJson:
        final path = await saveTextFile(
          suggestedName: '${entry.key.isValidUtf8 ? entry.key.text : 'key'}.json',
          content: exportEntryToJson(entry),
        );
        if (context.mounted && path != null) {
          showSnack(context, 'Gespeichert unter $path');
        }
        break;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Schlüssel löschen?'),
        content: Text(
          '"${entry.key.displayText}" wird aus der Ansicht entfernt. Das '
          'betrifft nur diese Sitzung, nicht die Original-Datei - über '
          '"Exportieren" ist der Stand vor dem Löschen weiterhin sicherbar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      appState.deleteEntry(entry);
    }
  }
}

enum _ExportAction { copyJson, copyCommands, saveJson }

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color, required this.bg});
  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _TtlEditor extends StatelessWidget {
  const _TtlEditor({required this.entry, required this.appState});
  final RdbEntry entry;
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    if (!entry.hasExpiry) {
      return ActionChip(
        visualDensity: VisualDensity.compact,
        avatar: const Icon(Icons.timer_outlined, size: 16),
        label: const Text('Kein Ablauf · setzen'),
        onPressed: () => _pickExpiry(context),
      );
    }
    final dt = DateTime.fromMillisecondsSinceEpoch(entry.expireAtMs!);
    final label = '${dt.toLocal()}'.split('.').first;
    return InputChip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(
        Icons.timer,
        size: 16,
        color: entry.isExpired ? AppColors.danger : null,
      ),
      label: Text(entry.isExpired ? '$label (abgelaufen)' : label),
      onPressed: () => _pickExpiry(context),
      onDeleted: () {
        entry.expireAtMs = null;
        appState.markDirty(entry);
      },
      deleteIcon: const Icon(Icons.close, size: 16),
    );
  }

  Future<void> _pickExpiry(BuildContext context) async {
    final now = DateTime.now();
    final initial = entry.hasExpiry
        ? DateTime.fromMillisecondsSinceEpoch(entry.expireAtMs!)
        : now.add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 20),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    entry.expireAtMs = combined.millisecondsSinceEpoch;
    appState.markDirty(entry);
  }
}
