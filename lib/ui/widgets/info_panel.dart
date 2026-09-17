import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../rdb/crc64.dart';
import '../../rdb/rdb_model.dart';
import '../theme/app_theme.dart';
import 'app_card.dart';

/// File-level diagnostics: RDB header/checksum info, AUX metadata, and a
/// per-database key count table - the RDB-file equivalent of `DBSIZE` /
/// `INFO keyspace` against a live server, plus parser-specific diagnostics
/// (unsupported keys, where parsing stopped) that a live server can't tell
/// you at all, since this data only exists in the file.
class InfoPanel extends StatelessWidget {
  const InfoPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final doc = appState.document!;

    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        _StatRow(doc: doc),
        const SizedBox(height: 16),
        if (doc.fatalStopReason != null) ...[
          _FatalStopBanner(doc: doc),
          const SizedBox(height: 16),
        ],
        if (doc.unparsedKeys.isNotEmpty) ...[
          _UnsupportedKeysCard(doc: doc),
          const SizedBox(height: 16),
        ],
        _FileInfoCard(doc: doc),
        const SizedBox(height: 16),
        _KeyspaceCard(doc: doc),
        if (doc.auxFields.isNotEmpty) ...[
          const SizedBox(height: 16),
          _AuxFieldsCard(doc: doc),
        ],
      ],
    );
  }
}

/// Three headline stat tiles across the top - the reference dashboard's
/// "Total Workflows / Executions / Success Rate" pattern, applied to file
/// stats instead.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.doc});
  final RdbDocument doc;

  @override
  Widget build(BuildContext context) {
    String checksumLabel;
    Color checksumColor;
    switch (doc.checksumStatus) {
      case ChecksumStatus.valid:
        checksumLabel = 'Gültig';
        checksumColor = AppColors.success;
        break;
      case ChecksumStatus.mismatch:
        checksumLabel = 'Ungültig';
        checksumColor = AppColors.danger;
        break;
      case ChecksumStatus.disabled:
        checksumLabel = 'Deaktiviert';
        checksumColor = AppColors.textTertiary;
        break;
      case ChecksumStatus.notChecked:
        checksumLabel = 'Unbekannt';
        checksumColor = AppColors.warning;
        break;
    }
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.storage_rounded,
            label: 'Datenbanken',
            value: '${doc.databases.length}',
            color: AppColors.info,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatTile(
            icon: Icons.vpn_key_outlined,
            label: 'Schlüssel gesamt',
            value: '${doc.totalKeyCount}',
            color: const Color(0xFF7C5CFC),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatTile(
            icon: Icons.verified_outlined,
            label: 'CRC64-Prüfsumme',
            value: checksumLabel,
            color: checksumColor,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 24,
              letterSpacing: -0.3,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _FatalStopBanner extends StatelessWidget {
  const _FatalStopBanner({required this.doc});
  final RdbDocument doc;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.dangerous_outlined, color: AppColors.danger, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              doc.fatalStopReason!,
              style: const TextStyle(color: AppColors.danger, fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileInfoCard extends StatelessWidget {
  const _FileInfoCard({required this.doc});
  final RdbDocument doc;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Datei',
      icon: Icons.description_outlined,
      child: Table(
        columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
        children: [
          _row('Pfad', doc.sourcePath),
          _row('Größe', _formatBytes(doc.fileSizeBytes)),
          _row('RDB-Version', doc.rdbVersion.toString()),
          _checksumRow(context),
        ],
      ),
    );
  }

  TableRow _checksumRow(BuildContext context) {
    String value;
    Color? color;
    switch (doc.checksumStatus) {
      case ChecksumStatus.valid:
        value = 'gültig (${Crc64Jones.toHex64(doc.computedChecksum!)})';
        color = AppColors.success;
        break;
      case ChecksumStatus.mismatch:
        value = 'stimmt NICHT überein - gespeichert: '
            '${Crc64Jones.toHex64(doc.storedChecksum!)}, berechnet: '
            '${Crc64Jones.toHex64(doc.computedChecksum!)}';
        color = AppColors.danger;
        break;
      case ChecksumStatus.disabled:
        value = 'deaktiviert (RDB-Version < 5 oder `rdbchecksum no`)';
        break;
      case ChecksumStatus.notChecked:
        value = 'nicht geprüft (Datei endete unerwartet)';
        color = AppColors.warning;
        break;
    }
    return _row('CRC64-Prüfsumme', value, valueColor: color);
  }

  TableRow _row(String label, String value, {Color? valueColor}) {
    return TableRow(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: SelectableText(
          value,
          style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: valueColor ?? AppColors.textPrimary),
        ),
      ),
    ]);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

/// Mirrors `redis-cli INFO keyspace` (`db0:keys=N,expires=M,...`), but
/// computed straight from the file instead of a live server.
class _KeyspaceCard extends StatelessWidget {
  const _KeyspaceCard({required this.doc});
  final RdbDocument doc;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Keyspace (wie INFO keyspace / DBSIZE)',
      icon: Icons.table_rows_outlined,
      child: doc.databases.isEmpty
          ? const Text(
              'Keine Datenbank mit lesbaren Schlüsseln gefunden - siehe oben, '
              'falls dort nicht unterstützte Schlüssel aufgeführt sind.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            )
          : DataTable(
              columnSpacing: 24,
              horizontalMargin: 0,
              columns: const [
                DataColumn(label: Text('DB')),
                DataColumn(label: Text('Keys'), numeric: true),
                DataColumn(label: Text('mit TTL'), numeric: true),
                DataColumn(label: Text('abgelaufen'), numeric: true),
              ],
              rows: [
                for (final db in doc.databases)
                  DataRow(cells: [
                    DataCell(Text('db${db.index}')),
                    DataCell(Text('${db.entries.length}')),
                    DataCell(Text('${db.entries.where((e) => e.hasExpiry).length}')),
                    DataCell(Text('${db.entries.where((e) => e.isExpired).length}')),
                  ]),
              ],
            ),
    );
  }
}

class _AuxFieldsCard extends StatelessWidget {
  const _AuxFieldsCard({required this.doc});
  final RdbDocument doc;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Metadaten (AUX-Felder)',
      icon: Icons.info_outline,
      child: Table(
        columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
        children: [
          for (final e in doc.auxFields.entries)
            TableRow(children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Text(e.key, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: SelectableText(e.value,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              ),
            ]),
        ],
      ),
    );
  }
}

class _UnsupportedKeysCard extends StatelessWidget {
  const _UnsupportedKeysCard({required this.doc});
  final RdbDocument doc;

  @override
  Widget build(BuildContext context) {
    const previewLimit = 50;
    final preview = doc.unparsedKeys.take(previewLimit).toList();
    return _SectionCard(
      title: 'Nicht unterstützte Schlüssel (${doc.unparsedKeys.length})',
      icon: Icons.warning_amber_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RDB hat keinen Mechanismus, um einen unbekannten Werttyp zu '
            'überspringen - beim ersten dieser Schlüssel musste das Lesen der '
            'jeweiligen Datenbank gestoppt werden. Alle davor gelesenen '
            'Schlüssel sind im Tab "Schlüssel" vollständig aufgeführt.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          DataTable(
            columnSpacing: 24,
            horizontalMargin: 0,
            columns: const [
              DataColumn(label: Text('DB')),
              DataColumn(label: Text('Schlüssel')),
              DataColumn(label: Text('Typ')),
              DataColumn(label: Text('Datei-Offset')),
            ],
            rows: [
              for (final u in preview)
                DataRow(cells: [
                  DataCell(Text('db${u.dbIndex}')),
                  DataCell(SelectableText(u.key.displayText,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                  DataCell(Text(u.typeName)),
                  DataCell(Text('${u.fileOffset}')),
                ]),
            ],
          ),
          if (doc.unparsedKeys.length > previewLimit)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('… und ${doc.unparsedKeys.length - previewLimit} weitere',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              final text = doc.unparsedKeys
                  .map((u) => 'db${u.dbIndex}\t${u.key.displayText}\t${u.typeName}\toffset ${u.fileOffset}')
                  .join('\n');
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Liste in die Zwischenablage kopiert.')),
              );
            },
            icon: const Icon(Icons.copy, size: 15),
            label: const Text('Vollständige Liste kopieren'),
          ),
        ],
      ),
    );
  }
}
