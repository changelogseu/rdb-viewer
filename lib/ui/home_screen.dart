import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../export/command_export.dart';
import '../export/json_export.dart';
import 'file_io.dart';
import 'theme/app_theme.dart';
import 'widgets/app_card.dart';
import 'widgets/info_panel.dart';
import 'widgets/key_list_panel.dart';
import 'widgets/top_nav_bar.dart';
import 'widgets/value_detail_panel.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final loaded = appState.status == LoadStatus.loaded;

    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) {
          final tabController = loaded ? DefaultTabController.of(context) : null;
          return Scaffold(
            appBar: TopNavBar(
              fileName: appState.hasDocument
                  ? appState.document!.sourcePath.split(RegExp(r'[\\/]')).last
                  : null,
              tabController: tabController,
              tabs: loaded
                  ? const [
                      Tab(child: _TabLabel(icon: Icons.vpn_key_outlined, label: 'Schlüssel')),
                      Tab(child: _TabLabel(icon: Icons.query_stats, label: 'Info')),
                    ]
                  : null,
              actions: [
                if (appState.hasDocument)
                  PopupMenuButton<_DocAction>(
                    tooltip: 'Gesamte Datei exportieren',
                    icon: const Icon(Icons.ios_share, size: 18),
                    onSelected: (a) => _handleDocAction(context, appState, a),
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _DocAction.saveJson,
                        child: Text('Alles als JSON speichern...'),
                      ),
                      PopupMenuItem(
                        value: _DocAction.saveCommands,
                        child: Text('Aktuelle DB als Redis-Befehle speichern...'),
                      ),
                    ],
                  ),
                NavPrimaryButton(
                  icon: Icons.folder_open,
                  label: 'Datei öffnen',
                  onPressed: () => _openFile(context),
                ),
              ],
            ),
            body: _buildBody(context, appState),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppState appState) {
    switch (appState.status) {
      case LoadStatus.idle:
        return _EmptyState(onOpen: () => _openFile(context));
      case LoadStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case LoadStatus.error:
        return _ErrorState(
          message: appState.loadErrorMessage ?? 'Unbekannter Fehler.',
          onRetry: () => _openFile(context),
        );
      case LoadStatus.loaded:
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (appState.loadWarningMessage != null) ...[
                _WarningBanner(message: appState.loadWarningMessage!),
                const SizedBox(height: 16),
              ],
              Expanded(
                child: TabBarView(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 340,
                          child: AppCard(child: const KeyListPanel()),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: AppCard(child: const ValueDetailPanel())),
                      ],
                    ),
                    const InfoPanel(),
                  ],
                ),
              ),
            ],
          ),
        );
    }
  }

  Future<void> _openFile(BuildContext context) async {
    final path = await pickRdbFilePath();
    if (path == null || !context.mounted) return;
    await context.read<AppState>().loadFromPath(path);
  }

  Future<void> _handleDocAction(
      BuildContext context, AppState appState, _DocAction action) async {
    final doc = appState.document!;
    switch (action) {
      case _DocAction.saveJson:
        final path = await saveTextFile(
          suggestedName: 'rdb_export.json',
          content: exportDocumentToJson(doc),
        );
        if (context.mounted && path != null) {
          showSnack(context, 'Gespeichert unter $path');
        }
        break;
      case _DocAction.saveCommands:
        final db = appState.selectedDb;
        if (db == null) return;
        final path = await saveTextFile(
          suggestedName: 'db${db.index}_commands.txt',
          content: commandsForDatabase(db),
          acceptedExtensions: ['txt'],
        );
        if (context.mounted && path != null) {
          showSnack(context, 'Gespeichert unter $path');
        }
        break;
    }
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

enum _DocAction { saveJson, saveCommands }

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AppCard(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.storage_rounded, size: 28, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text('Keine RDB-Datei geöffnet', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Öffne ein Redis-Backup (.rdb), um Schlüssel anzusehen und zu bearbeiten.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.folder_open, size: 16),
                label: const Text('RDB-Datei öffnen'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: AppCard(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.error_outline, size: 26, color: AppColors.danger),
              ),
              const SizedBox(height: 16),
              Text('Datei konnte nicht gelesen werden', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              SelectableText(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.folder_open, size: 16),
                label: const Text('Andere Datei öffnen'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              message,
              style: const TextStyle(fontSize: 12.5, color: AppColors.warning, height: 1.4),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 15),
            tooltip: 'Meldung kopieren',
            onPressed: () => Clipboard.setData(ClipboardData(text: message)),
          ),
        ],
      ),
    );
  }
}
