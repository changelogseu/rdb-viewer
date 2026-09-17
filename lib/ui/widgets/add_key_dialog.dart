import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../rdb/length_and_string.dart';
import '../../rdb/rdb_model.dart';
import '../theme/app_theme.dart';
import 'type_badge.dart';

/// Dialog for creating a brand-new key (not present in the loaded file) in
/// the currently selected - or an explicitly chosen - database. The new
/// entry starts with an empty value of the chosen type; its contents are
/// then filled in via the normal value editors after selection.
Future<void> showAddKeyDialog(BuildContext context, AppState appState) async {
  await showDialog<void>(
    context: context,
    builder: (context) => _AddKeyDialog(appState: appState),
  );
}

class _AddKeyDialog extends StatefulWidget {
  const _AddKeyDialog({required this.appState});
  final AppState appState;

  @override
  State<_AddKeyDialog> createState() => _AddKeyDialogState();
}

class _AddKeyDialogState extends State<_AddKeyDialog> {
  late final TextEditingController _nameController = TextEditingController();
  late final TextEditingController _dbController = TextEditingController(
    text: (widget.appState.selectedDb?.index ?? widget.appState.selectedDbIndex).toString(),
  );
  RdbValueKind _kind = RdbValueKind.string;
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neuer Schlüssel'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Schlüsselname',
                errorText: _errorText,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _dbController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Datenbank (DB-Index)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Typ', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kind in RdbValueKind.values)
                  ChoiceChip(
                    label: Text(
                      kind.name,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        fontSize: 12.5,
                        color: _kind == kind ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    avatar: TypeBadge(kind: kind, size: 20),
                    selected: _kind == kind,
                    onSelected: (_) => setState(() => _kind = kind),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Erstellen'),
        ),
      ],
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Bitte einen Schlüsselnamen angeben.');
      return;
    }
    final dbIndex = int.tryParse(_dbController.text.trim());
    if (dbIndex == null || dbIndex < 0) {
      setState(() => _errorText = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ungültiger DB-Index.')),
      );
      return;
    }
    if (widget.appState.keyExistsInDb(dbIndex, name)) {
      setState(() => _errorText = 'Schlüssel existiert bereits in db$dbIndex.');
      return;
    }

    final entry = RdbEntry(
      key: RdbString.fromText(name),
      value: _emptyValueFor(_kind),
    )..isNew = true;

    widget.appState.addEntry(dbIndex: dbIndex, entry: entry);
    Navigator.of(context).pop();
  }

  RdbValue _emptyValueFor(RdbValueKind kind) {
    switch (kind) {
      case RdbValueKind.string:
        return RdbValue.string(RdbString.fromText(''));
      case RdbValueKind.list:
        return RdbValue.list([]);
      case RdbValueKind.hash:
        return RdbValue.hash([]);
      case RdbValueKind.set:
        return RdbValue.set([]);
      case RdbValueKind.zset:
        return RdbValue.zset([]);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dbController.dispose();
    super.dispose();
  }
}
