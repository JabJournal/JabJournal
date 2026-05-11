import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/notification_status_provider.dart';
import '../home/home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationStatusProvider>().refresh();
    });
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Consumer<NotificationStatusProvider>(
          builder: (context, nsp, _) {
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              children: [
                // ── Header ─────────────────────────────────────────────────
                Icon(Icons.vaccines_outlined, size: 64, color: cs.primary),
                const SizedBox(height: 16),
                Text('Welcome to JabJournal',
                    style: tt.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  'Before you start, grant the permissions below so dose '
                  'reminders fire reliably. You can change these later in '
                  'Settings.',
                  style: tt.bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 32),

                // ── Permissions ─────────────────────────────────────────────
                Text('Permissions', style: tt.titleMedium),
                const SizedBox(height: 12),

                _PermissionTile(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  description: 'Show dose reminders and alerts.',
                  granted: nsp.notificationsEnabled,
                  onGrant: () async {
                    await nsp.requestNotificationPermission();
                  },
                  // Visible on all platforms.
                  visible: true,
                ),

                if (!kIsWeb && Platform.isAndroid) ...[
                  const SizedBox(height: 8),
                  _PermissionTile(
                    icon: Icons.alarm_outlined,
                    title: 'Exact Alarms',
                    description:
                        'Fire reminders at the precise scheduled time, '
                        'not just "around" it.',
                    granted: nsp.exactAlarmsAllowed,
                    onGrant: () async {
                      await nsp.requestExactAlarmPermission();
                      // User goes to Settings and returns — refresh on resume.
                    },
                    grantLabel: 'Open Settings',
                    visible: true,
                  ),
                  const SizedBox(height: 8),
                  _PermissionTile(
                    icon: Icons.battery_saver_outlined,
                    title: 'Battery Optimization',
                    description:
                        'Prevent Android from delaying or killing '
                        'reminders when the app is in the background.',
                    granted: nsp.batteryOptimizationDisabled,
                    onGrant: () async {
                      await nsp.requestDisableBatteryOptimization();
                    },
                    grantLabel: 'Disable for this app',
                    visible: true,
                  ),
                ],

                const SizedBox(height: 40),

                // ── Continue button ─────────────────────────────────────────
                FilledButton(
                  onPressed: _finish,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Get Started'),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'You can update permissions anytime in Settings.',
                    style: tt.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Permission tile ──────────────────────────────────────────────────────────

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool granted;
  final bool visible;
  final VoidCallback onGrant;
  final String grantLabel;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.granted,
    required this.onGrant,
    required this.visible,
    this.grantLabel = 'Enable',
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: granted
                    ? cs.primaryContainer
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: granted ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Status / button
            if (granted)
              Icon(Icons.check_circle_outline, color: cs.primary)
            else
              TextButton(
                onPressed: onGrant,
                child: Text(grantLabel),
              ),
          ],
        ),
      ),
    );
  }
}
