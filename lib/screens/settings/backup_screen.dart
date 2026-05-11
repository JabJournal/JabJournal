import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/backup_provider.dart';
import '../../providers/calculator_provider.dart';
import '../../providers/dose_history_provider.dart';
import '../../providers/peptide_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/weight_provider.dart';
import '../../services/backup_service.dart';
import '../../services/saf_channel.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _passwordController = TextEditingController();
  bool _showPassword = false;

  // Directory picker works on desktop and Android (SAF). iOS has no equivalent.
  static final _supportsDirectoryPicker = !kIsWeb && !Platform.isIOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bp = context.read<BackupProvider>();
      _passwordController.text = bp.backupPassword;
      bp.loadBackups();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  // ── Reload all providers after import ────────────────────────────────────────

  Future<void> _reloadAll() async {
    await Future.wait([
      context.read<PeptideProvider>().loadPeptides(),
      context.read<DoseHistoryProvider>().loadAllDoses(),
      context.read<CalculatorProvider>().loadCalculations(),
      context.read<ScheduleProvider>().loadAllSchedules(),
      context.read<WeightProvider>().loadAll(),
    ]);
  }

  // ── Password dialog ───────────────────────────────────────────────────────────

  Future<String?> _promptPassword(String title, String hint) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => _PasswordDialog(
        title: title,
        hint: hint,
        controller: controller,
      ),
    );
  }

  // ── Directory picker ─────────────────────────────────────────────────────────

  Future<void> _pickBackupDirectory() async {
    final bp = context.read<BackupProvider>();

    // On Android we use our own method channel so the picker always returns
    // a raw content:// URI (file_picker converts it to a file path internally,
    // which then fails on Android 10+ scoped storage).
    final String? path;
    if (!kIsWeb && Platform.isAndroid) {
      path = await SafChannel.pickDirectory();
    } else {
      path = await FilePicker.getDirectoryPath(
        dialogTitle: 'Choose Backup Folder',
      );
    }
    if (path == null || !mounted) return;
    final displayName = _dirDisplayName(path);
    await bp.setBackupDirectory(path, displayName: displayName);
  }

  /// Extracts a human-readable folder name from a file-system path or SAF URI.
  String _dirDisplayName(String path) {
    if (path.startsWith('content://')) {
      // SAF URI: last path segment is URL-encoded, e.g. "primary%3ABackups"
      try {
        final segment = Uri.parse(path).pathSegments.last;
        final decoded = Uri.decodeComponent(segment);
        // Format is typically "primary:FolderName" or "primary:Parent/Folder"
        return decoded.split(':').last.split('/').last;
      } catch (_) {
        return 'Custom folder';
      }
    }
    return path.split(Platform.pathSeparator).where((s) => s.isNotEmpty).last;
  }

  // ── Import flow ───────────────────────────────────────────────────────────────

  Future<void> _importFlow() async {
    final service = context.read<BackupProvider>().service;

    String? content;
    try {
      content = await service.pickAndReadFile();
    } on FilePickerNotReadyException {
      _showSnack(
        'File picker is not ready. Please fully restart the app and try again.',
        isError: true,
      );
      return;
    }
    if (content == null) return;

    Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      _showSnack('Invalid file format.', isError: true);
      return;
    }
    if (envelope['app'] != 'jab_journal') {
      _showSnack('Not a valid JabJournal backup.', isError: true);
      return;
    }

    String? password;
    if (envelope['encrypted'] == true) {
      password = await _promptPassword(
        'Encrypted Backup',
        'Enter the backup password',
      );
      if (password == null) return;
    }

    await _runImport(content, password: password);
  }

  Future<void> _restoreFlow(BackupFileInfo backup) async {
    final service = context.read<BackupProvider>().service;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restore Backup?'),
        content: const Text(
            'Existing data with matching IDs will be overwritten. New records will be merged in.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restore')),
        ],
      ),
    );
    if (confirmed != true) return;
    final content = await service.readBackupFile(backup.path);

    String? password;
    if (service.isEncrypted(content)) {
      password = await _promptPassword(
        'Encrypted Backup',
        'Enter the backup password',
      );
      if (password == null) return;
    }

    await _runImport(content, password: password);
  }

  Future<void> _runImport(String content, {String? password}) async {
    final service = context.read<BackupProvider>().service;
    try {
      final result = await service.importData(content, password: password);
      await _reloadAll();
      if (mounted) {
        _showSnack('Imported: $result');
      }
    } on BackupWrongPasswordException {
      _showSnack('Wrong password.', isError: true);
    } on BackupPasswordRequiredException {
      _showSnack('A password is required for this backup.', isError: true);
    } catch (e) {
      _showSnack('Import failed: $e', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Export')),
      body: Consumer<BackupProvider>(
        builder: (context, bp, _) {
          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildBackupCard(bp),
                  const SizedBox(height: 16),
                  _buildEncryptionCard(bp),
                  const SizedBox(height: 16),
                  _buildAutoBackupCard(bp),
                  const SizedBox(height: 16),
                  _buildSavedBackupsCard(bp),
                  const SizedBox(height: 24),
                ],
              ),
              if (bp.isBusy)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x55000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ── Section: Backup ───────────────────────────────────────────────────────────

  Widget _buildBackupCard(BackupProvider bp) {
    final dir = bp.backupDirectory;
    final dirLabel = bp.backupDirectoryDisplayName ??
        (dir != null
            ? dir.split(Platform.pathSeparator).where((s) => s.isNotEmpty).last
            : 'App Documents');

    final lastBackupText = bp.lastBackupAt == null
        ? null
        : _relativeTime(bp.lastBackupAt!);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Location row
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Backup Location'),
            subtitle: Text(dirLabel, overflow: TextOverflow.ellipsis),
            trailing: _supportsDirectoryPicker
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: _pickBackupDirectory,
                        child: const Text('Change'),
                      ),
                      if (dir != null)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Reset to App Documents',
                          onPressed: () => bp.setBackupDirectory(null),
                        ),
                    ],
                  )
                : null,
          ),
          const Divider(height: 1, indent: 16),
          // Back up now button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: FilledButton.icon(
              onPressed: bp.isBusy
                  ? null
                  : () async {
                      final ok = await bp.saveLocalBackup();
                      if (!mounted) return;
                      if (ok) {
                        _showSnack('Backup saved.');
                      } else if (bp.error != null) {
                        _showSnack(bp.error!, isError: true);
                      }
                    },
              icon: const Icon(Icons.backup_outlined),
              label: const Text('Back up now'),
            ),
          ),
          if (lastBackupText != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
              child: Text(
                'Last backup: $lastBackupText',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 16),
          const Divider(height: 1, indent: 16),
          // Import section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Import / Restore',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: bp.isBusy ? null : _importFlow,
                  icon: const Icon(Icons.file_open_outlined),
                  label: const Text('Import from File'),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Importing merges records by ID — existing data is not deleted.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section: Encryption ───────────────────────────────────────────────────────

  Widget _buildEncryptionCard(BackupProvider bp) {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline),
            title: const Text('Encrypt Backups'),
            subtitle: const Text('Protect backup files with a password'),
            value: bp.encryptionEnabled,
            onChanged: (v) => bp.setEncryptionEnabled(v),
          ),
          if (bp.encryptionEnabled) ...[
            const Divider(height: 1, indent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: TextField(
                controller: _passwordController,
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  labelText: 'Backup Password',
                  prefixIcon: const Icon(Icons.key_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  suffixIcon: IconButton(
                    icon: Icon(_showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                ),
                onChanged: (v) => bp.setBackupPassword(v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Password is stored on this device. You will need it to restore an encrypted backup.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Section: Auto backup ──────────────────────────────────────────────────────

  Widget _buildAutoBackupCard(BackupProvider bp) {
    final lastBackupText = bp.lastBackupAt == null
        ? 'Never'
        : _relativeTime(bp.lastBackupAt!);

    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.schedule_outlined),
            title: const Text('Auto Backup'),
            subtitle: Text(
              'Backs up automatically when you log a dose, add or remove a peptide, or make other changes. Last backup: $lastBackupText',
            ),
            value: bp.autoBackupEnabled,
            onChanged: (v) => bp.setAutoBackupEnabled(v),
          ),
          if (bp.autoBackupEnabled) ...[
            const Divider(height: 1, indent: 16),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Keep last'),
              subtitle: const Text('Older backups are deleted automatically'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: bp.maxBackups > 1
                        ? () => bp.setMaxBackups(bp.maxBackups - 1)
                        : null,
                  ),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${bp.maxBackups}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: bp.maxBackups < 50
                        ? () => bp.setMaxBackups(bp.maxBackups + 1)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Section: Saved backups list ───────────────────────────────────────────────

  Widget _buildSavedBackupsCard(BackupProvider bp) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Saved Backups',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                if (bp.backups.isNotEmpty)
                  Text(
                      '${bp.backups.length} file${bp.backups.length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 12),
            if (bp.backups.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No backups yet',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              ...bp.backups.map((b) => _BackupTile(
                    backup: b,
                    onRestore: () => _restoreFlow(b),
                    onDelete: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete Backup?'),
                          content: Text(
                              '"${b.filename}" will be permanently deleted.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel')),
                            TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(
                                    foregroundColor:
                                        Theme.of(context).colorScheme.error),
                                child: const Text('Delete')),
                          ],
                        ),
                      );
                      if (ok == true && mounted) await bp.deleteBackup(b.path);
                    },
                  )),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    return '${diff.inDays} days ago';
  }
}

// ─── Password dialog ──────────────────────────────────────────────────────────

class _PasswordDialog extends StatefulWidget {
  final String title;
  final String hint;
  final TextEditingController controller;

  const _PasswordDialog({
    required this.title,
    required this.hint,
    required this.controller,
  });

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: widget.controller,
        autofocus: true,
        obscureText: !_show,
        decoration: InputDecoration(
          hintText: widget.hint,
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: Icon(_show
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined),
            onPressed: () => setState(() => _show = !_show),
          ),
        ),
        onSubmitted: (_) => Navigator.pop(context, widget.controller.text),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(context, widget.controller.text),
            child: const Text('OK')),
      ],
    );
  }
}

// ─── Backup list tile ─────────────────────────────────────────────────────────

class _BackupTile extends StatelessWidget {
  final BackupFileInfo backup;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _BackupTile({
    required this.backup,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(
            color:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: const Icon(Icons.backup_outlined),
        title: Text(
          _formatDate(backup.modified),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        subtitle: Text(backup.formattedSize),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: onRestore,
              child: const Text('Restore'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: Theme.of(context).colorScheme.error,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'AM' : 'PM';
    return '${months[local.month - 1]} ${local.day}, ${local.year}  $h:$m $period';
  }
}
