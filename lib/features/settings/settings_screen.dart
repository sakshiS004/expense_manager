import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/formatter.dart';
import '../../data/export/export_import_service.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../sync/sync_queue.dart';
import '../../sync/sync_service.dart';
import '../auth/app_lock_service.dart';
import '../auth/auth_screen.dart';
import '../auth/auth_service.dart';
import '../notifications/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _exportImportService = ExportImportService();

  DateTime? _lastSyncAt;
  bool _isSyncing = false;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadLastSyncAt();
  }

  Future<void> _loadLastSyncAt() async {
    final syncService = context.read<SyncService?>();
    if (syncService == null) return;

    final time = await syncService.getLastSyncAt();
    if (!mounted) return;
    setState(() => _lastSyncAt = time);
  }

  Future<void> _syncNow() async {
    final syncQueue = context.read<SyncQueue?>();
    if (syncQueue == null) return;

    setState(() => _isSyncing = true);
    try {
      await syncQueue.triggerSync();
      await _loadLastSyncAt();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _exportJson() async {
    try {
      final userId = context.read<AuthService>().currentUserId;
      final file = await _exportImportService.exportToJsonFile(userId);
      await Share.shareXFiles([XFile(file.path)], text: 'Expense Manager backup');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _exportCsv() async {
    try {
      final userId = context.read<AuthService>().currentUserId;
      final file = await _exportImportService.exportToCsvFile(userId);
      await Share.shareXFiles([XFile(file.path)], text: 'Transactions CSV');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _importJson() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      final path = result?.files.single.path;
      if (path == null) return; // user cancelled

      final count = await _exportImportService.importFromJsonFile(File(path));
      if (!mounted) return;

      final userId = context.read<AuthService>().currentUserId;
      await context.read<TransactionProvider>().loadTransactions(userId);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported $count records')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  Future<void> _toggleNotifications(bool enabled) async {
    setState(() => _notificationsEnabled = enabled);
    if (enabled) {
      await NotificationService.instance.requestPermissions();
      await NotificationService.instance.scheduleDailyReminders();
      _showMessage('Daily reminders scheduled.');
    } else {
      await NotificationService.instance.cancelAllNotifications();
      _showMessage('Reminders disabled.');
    }
  }

  void _openAuthScreen() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final settingsProvider = context.watch<SettingsProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final appLockService = context.watch<AppLockService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account Info Card
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(
                authService.isGuest
                    ? 'Guest Mode'
                    : (authService.currentUser?.displayName ??
                    authService.currentUser?.email ??
                    'Signed in'),
              ),
              subtitle: Text(
                authService.isGuest
                    ? 'Sign in to sync across devices'
                    : (authService.currentUser?.email ?? 'Signed in'),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Currency Settings
          Card(
            child: ListTile(
              leading: const Icon(Icons.attach_money),
              title: const Text('Currency'),
              trailing: DropdownButton<String>(
                value: settingsProvider.currencyCode,
                underline: const SizedBox.shrink(),
                items: SettingsProvider.supportedCurrencies.entries
                    .map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text('${e.key} (${e.value})'),
                ))
                    .toList(),
                onChanged: (code) {
                  if (code != null) {
                    settingsProvider.setCurrency(
                      SettingsProvider.supportedCurrencies[code]!,
                    );
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Theme Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.brightness_6_outlined),
                      SizedBox(width: 16),
                      Text('Theme'),
                    ],
                  ),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_outlined),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined),
                      ),
                    ],
                    selected: {themeProvider.themeMode},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) =>
                        themeProvider.setThemeMode(selection.first),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Notification Reminders
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text('Daily Reminders'),
              subtitle: const Text('Get notified daily to log your expenses'),
              value: _notificationsEnabled,
              onChanged: _toggleNotifications,
            ),
          ),
          const SizedBox(height: 12),

          // App Lock Security
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: const Text('App Lock'),
              subtitle: const Text('Require biometric or device unlock'),
              value: appLockService.isEnabled,
              onChanged: (value) async {
                final success = await appLockService.setEnabled(value);
                if (!context.mounted) return;
                if (!success && value) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not verify identity. App Lock was not enabled.'),
                    ),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 12),

          // Sync Status & Trigger
          Card(
            child: ListTile(
              leading: const Icon(Icons.sync),
              title: Text(
                _lastSyncAt == null
                    ? 'Last Synced: Never'
                    : 'Last Synced: ${Formatters.date(_lastSyncAt!)} ${Formatters.time(_lastSyncAt!)}',
              ),
              trailing: FilledButton(
                onPressed: _isSyncing ? null : _syncNow,
                child: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Backup & Export Section
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_file_outlined),
                  title: const Text('Export JSON'),
                  subtitle: const Text('Full backup of all your data'),
                  onTap: _exportJson,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('Import JSON'),
                  subtitle: const Text('Restore from a backup file'),
                  onTap: _importJson,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.table_chart_outlined),
                  title: const Text('Export CSV'),
                  subtitle: const Text('Transactions only, for Excel/Sheets'),
                  onTap: _exportCsv,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Auth Sign Out / Sign In
          Card(
            child: ListTile(
              leading: Icon(
                authService.isGuest ? Icons.login : Icons.logout,
                color: authService.isGuest ? null : Colors.redAccent,
              ),
              title: Text(
                authService.isGuest ? 'Sign In' : 'Sign Out',
                style: TextStyle(
                  color: authService.isGuest ? null : Colors.redAccent,
                ),
              ),
              onTap: authService.isGuest ? _openAuthScreen : authService.signOut,
            ),
          ),
        ],
      ),
    );
  }
}
