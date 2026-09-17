import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../rdb/length_and_string.dart';
import '../../rdb/rdb_model.dart';

/// Read-only chip shown instead of an edit field for binary (non-UTF-8)
/// values - phase 1 only supports editing text values in place.
class _BinaryBadge extends StatelessWidget {
  const _BinaryBadge({required this.byteCount});
  final int byteCount;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message:
          'Binärdaten ($byteCount Bytes) - Bearbeitung als Text wird in dieser '
          'Version nicht unterstützt. Über "Als JSON exportieren" bleiben die '
          'Rohdaten (Base64) erhalten.',
      child: Chip(
        avatar: const Icon(Icons.data_object, size: 16),
        label: Text('Binär ($byteCount B)'),
      ),
    );
  }
}

class RdbStringField extends StatefulWidget {
  const RdbStringField({
    super.key,
    required this.value,
    required this.onChanged,
    this.labelText,
    this.maxLines = 1,
  });

  final RdbString value;
  final ValueChanged<RdbString> onChanged;
  final String? labelText;
  final int maxLines;

  @override
  State<RdbStringField> createState() => _RdbStringFieldState();
}

class _RdbStringFieldState extends State<RdbStringField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value.displayText);

  @override
  Widget build(BuildContext context) {
    if (!widget.value.isValidUtf8) {
      return _BinaryBadge(byteCount: widget.value.bytes.length);
    }
    return TextField(
      controller: _controller,
      maxLines: widget.maxLines,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        labelText: widget.labelText,
        border: const OutlineInputBorder(),
      ),
      onChanged: (text) => widget.onChanged(RdbString.fromText(text)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class StringValueEditor extends StatelessWidget {
  const StringValueEditor({super.key, required this.entry, required this.appState});
  final RdbEntry entry;
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: RdbStringField(
        key: ValueKey(entry),
        value: entry.value.stringValue!,
        maxLines: 12,
        labelText: 'Wert',
        onChanged: (s) {
          entry.value.stringValue = s;
          appState.markDirty(entry);
        },
      ),
    );
  }
}

class ListValueEditor extends StatelessWidget {
  const ListValueEditor({super.key, required this.entry, required this.appState});
  final RdbEntry entry;
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final items = entry.value.listValue!;
    return _EditableList(
      itemCount: items.length,
      onAdd: () {
        items.add(RdbString.fromText(''));
        appState.markDirty(entry);
      },
      itemBuilder: (context, i) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Text('$i', style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: RdbStringField(
              key: ValueKey(items[i]),
              value: items[i],
              onChanged: (s) {
                items[i] = s;
                appState.markDirty(entry);
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            tooltip: 'Element entfernen',
            onPressed: () {
              items.removeAt(i);
              appState.markDirty(entry);
            },
          ),
        ],
      ),
    );
  }
}

class SetValueEditor extends StatelessWidget {
  const SetValueEditor({super.key, required this.entry, required this.appState});
  final RdbEntry entry;
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final items = entry.value.setValue!;
    return _EditableList(
      itemCount: items.length,
      onAdd: () {
        items.add(RdbString.fromText(''));
        appState.markDirty(entry);
      },
      itemBuilder: (context, i) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: RdbStringField(
              key: ValueKey(items[i]),
              value: items[i],
              onChanged: (s) {
                items[i] = s;
                appState.markDirty(entry);
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            tooltip: 'Mitglied entfernen',
            onPressed: () {
              items.removeAt(i);
              appState.markDirty(entry);
            },
          ),
        ],
      ),
    );
  }
}

class HashValueEditor extends StatelessWidget {
  const HashValueEditor({super.key, required this.entry, required this.appState});
  final RdbEntry entry;
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final fields = entry.value.hashValue!;
    return _EditableList(
      itemCount: fields.length,
      onAdd: () {
        fields.add(HashField(RdbString.fromText(''), RdbString.fromText('')));
        appState.markDirty(entry);
      },
      addLabel: 'Feld hinzufügen',
      itemBuilder: (context, i) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: RdbStringField(
              key: ValueKey('field-${fields[i]}'),
              value: fields[i].field,
              labelText: 'Feld',
              onChanged: (s) {
                fields[i].field = s;
                appState.markDirty(entry);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: RdbStringField(
              key: ValueKey('value-${fields[i]}'),
              value: fields[i].value,
              labelText: 'Wert',
              onChanged: (s) {
                fields[i].value = s;
                appState.markDirty(entry);
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            tooltip: 'Feld entfernen',
            onPressed: () {
              fields.removeAt(i);
              appState.markDirty(entry);
            },
          ),
        ],
      ),
    );
  }
}

class ZsetValueEditor extends StatelessWidget {
  const ZsetValueEditor({super.key, required this.entry, required this.appState});
  final RdbEntry entry;
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final members = entry.value.zsetValue!;
    return _EditableList(
      itemCount: members.length,
      onAdd: () {
        members.add(ZsetMember(RdbString.fromText(''), 0));
        appState.markDirty(entry);
      },
      addLabel: 'Mitglied hinzufügen',
      itemBuilder: (context, i) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: TextFormField(
              key: ValueKey('score-${members[i]}'),
              initialValue: _formatScore(members[i].score),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Score',
                border: OutlineInputBorder(),
              ),
              onChanged: (text) {
                final parsed = double.tryParse(text);
                if (parsed != null) {
                  members[i].score = parsed;
                  appState.markDirty(entry);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RdbStringField(
              key: ValueKey('member-${members[i]}'),
              value: members[i].member,
              labelText: 'Mitglied',
              onChanged: (s) {
                members[i].member = s;
                appState.markDirty(entry);
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            tooltip: 'Mitglied entfernen',
            onPressed: () {
              members.removeAt(i);
              appState.markDirty(entry);
            },
          ),
        ],
      ),
    );
  }

  String _formatScore(double score) {
    if (score.isInfinite) return score.isNegative ? '-inf' : '+inf';
    if (score == score.roundToDouble() && score.abs() < 1e15) {
      return score.toInt().toString();
    }
    return score.toString();
  }
}

class _EditableList extends StatelessWidget {
  const _EditableList({
    required this.itemCount,
    required this.itemBuilder,
    required this.onAdd,
    this.addLabel = 'Element hinzufügen',
  });

  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final VoidCallback onAdd;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: itemCount == 0
              ? const Center(child: Text('Keine Elemente.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: itemCount,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: itemBuilder,
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(addLabel),
          ),
        ),
      ],
    );
  }
}
