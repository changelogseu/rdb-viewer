import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../rdb/rdb_model.dart';
import '../theme/app_theme.dart';
import 'add_key_dialog.dart';
import 'type_badge.dart';

class KeyListPanel extends StatelessWidget {
  const KeyListPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final doc = appState.document!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: _DbDropdown(
                  value: appState.selectedDb?.index ?? appState.selectedDbIndex,
                  databases: doc.databases,
                  onChanged: (v) {
                    if (v != null) appState.selectDb(v);
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                tooltip: 'Neuer Schlüssel',
                onPressed: () => showAddKeyDialog(context, appState),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search, size: 17),
            ),
            onChanged: appState.setSearchQuery,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _FilterChip(label: 'Alle', kind: null),
              for (final kind in RdbValueKind.values)
                _FilterChip(label: kind.name, kind: kind),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        Expanded(
          child: appState.filteredEntries.isEmpty
              ? Center(
                  child: Text('Keine Treffer.',
                      style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: appState.filteredEntries.length,
                  itemBuilder: (context, i) {
                    final entry = appState.filteredEntries[i];
                    final selected = appState.selectedEntry == entry;
                    return _KeyRow(
                      entry: entry,
                      selected: selected,
                      onTap: () => appState.selectEntry(entry),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _DbDropdown extends StatelessWidget {
  const _DbDropdown({required this.value, required this.databases, required this.onChanged});
  final int value;
  final List<RdbDatabase> databases;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.pageBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Theme.of(context).dividerTheme.color ?? AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          isDense: true,
          icon: const Icon(Icons.expand_more, size: 18),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
          value: value,
          items: [
            for (final db in databases)
              DropdownMenuItem(
                value: db.index,
                child: Text('DB ${db.index} · ${db.entries.length} Schlüssel'),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.entry, required this.selected, required this.onTap});
  final RdbEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: selected ? AppColors.pageBackground : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                TypeBadge(kind: entry.value.kind, size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.key.displayText,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitleFor(entry),
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                if (entry.isNew)
                  const _StatusDot(color: AppColors.success, tooltip: 'Neu erstellt')
                else if (entry.dirty)
                  const _StatusDot(color: AppColors.warning, tooltip: 'Geändert'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitleFor(RdbEntry entry) {
    final parts = <String>['${entry.value.elementCount} Elem.'];
    if (entry.hasExpiry) {
      parts.add(entry.isExpired ? 'abgelaufen' : 'TTL gesetzt');
    }
    return parts.join(' · ');
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color, required this.tooltip});
  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 7,
        height: 7,
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.kind});
  final String label;
  final RdbValueKind? kind;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final selected = appState.typeFilter == kind;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
          fontSize: 12.5,
          color: selected ? Colors.white : AppColors.textPrimary,
        ),
      ),
      visualDensity: VisualDensity.compact,
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => appState.setTypeFilter(kind),
    );
  }
}
