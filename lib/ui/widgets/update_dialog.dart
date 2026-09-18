import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../update/update_checker.dart';
import '../theme/app_theme.dart';

/// Runs the update check and shows the result - a "you're up to date"
/// snackbar, an "update available" dialog, or a friendly error snackbar.
/// This is the only place in the app that triggers a network call, and it
/// only runs when invoked from here (a user clicking "Nach Updates
/// suchen"), never automatically.
Future<void> checkForUpdateAndShowResult(BuildContext context) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _CheckingDialog(),
  );

  UpdateCheckResult? result;
  Object? error;
  try {
    result = await checkForUpdate();
  } catch (e) {
    error = e;
  }

  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop(); // close the "checking" dialog

  if (error != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error is UpdateCheckException ? error.message : '$error')),
    );
    return;
  }

  if (!result!.updateAvailable) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Du hast bereits die neueste Version (${result.currentVersion}).')),
    );
    return;
  }

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => _UpdateAvailableDialog(result: result!),
  );
}

class _CheckingDialog extends StatelessWidget {
  const _CheckingDialog();

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
          SizedBox(width: 16),
          Text('Suche nach Updates...'),
        ],
      ),
    );
  }
}

class _UpdateAvailableDialog extends StatelessWidget {
  const _UpdateAvailableDialog({required this.result});
  final UpdateCheckResult result;

  @override
  Widget build(BuildContext context) {
    final release = result.release!;
    final asset = release.assetForCurrentPlatform();

    return AlertDialog(
      title: const Text('Update verfügbar'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Installiert: ${result.currentVersion}  →  Verfügbar: ${release.tagName}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            if (release.body.trim().isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: SingleChildScrollView(
                  child: SelectableText(
                    release.body.trim(),
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                ),
              ),
            if (asset == null) ...[
              const SizedBox(height: 12),
              const Text(
                'Keine passende Datei für dieses Betriebssystem im Release gefunden - '
                'öffne die Release-Seite, um manuell herunterzuladen.',
                style: TextStyle(fontSize: 12, color: AppColors.warning),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Später'),
        ),
        FilledButton.icon(
          onPressed: () async {
            final url = Uri.parse(asset?.downloadUrl ?? release.htmlUrl);
            await launchUrl(url, mode: LaunchMode.externalApplication);
            if (context.mounted) Navigator.of(context).pop();
          },
          icon: const Icon(Icons.open_in_new, size: 16),
          label: Text(asset != null ? 'Herunterladen' : 'Release-Seite öffnen'),
        ),
      ],
    );
  }
}
