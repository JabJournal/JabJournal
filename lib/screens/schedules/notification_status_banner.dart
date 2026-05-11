import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/notification_status_provider.dart';

/// A warning banner shown above the schedules list when the OS-level
/// prerequisites for reliable scheduled notifications aren't met. Lets the
/// user fix each issue inline. Hidden entirely when everything is in order.
class NotificationStatusBanner extends StatefulWidget {
  const NotificationStatusBanner({super.key});

  @override
  State<NotificationStatusBanner> createState() =>
      _NotificationStatusBannerState();
}

class _NotificationStatusBannerState extends State<NotificationStatusBanner>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationStatusProvider>().refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user might have flipped a permission in system settings — refresh
    // when the app comes back to the foreground.
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<NotificationStatusProvider>().refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationStatusProvider>(
      builder: (context, status, _) {
        if (!status.hasChecked || !status.hasIssues) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 20,
                        color: Theme.of(context)
                            .colorScheme
                            .onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Reminders may not fire',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (!status.notificationsEnabled)
                    _StatusRow(
                      icon: Icons.notifications_off_outlined,
                      text: 'Notifications are turned off',
                      actionLabel: 'Enable',
                      onAction: () async {
                        final granted =
                            await status.requestNotificationPermission();
                        if (!granted && context.mounted) {
                          await status.openNotificationSettings();
                        }
                      },
                    ),
                  if (Platform.isAndroid && !status.exactAlarmsAllowed)
                    _StatusRow(
                      icon: Icons.alarm_off_outlined,
                      text: 'Exact alarms are blocked',
                      actionLabel: 'Allow',
                      onAction: status.requestExactAlarmPermission,
                    ),
                  if (Platform.isAndroid &&
                      !status.batteryOptimizationDisabled)
                    _StatusRow(
                      icon: Icons.battery_saver_outlined,
                      text: 'Battery optimization is delaying reminders',
                      actionLabel: 'Disable',
                      onAction: () async {
                        final granted = await status
                            .requestDisableBatteryOptimization();
                        if (!granted && context.mounted) {
                          await status.openBatterySettings();
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final String actionLabel;
  final FutureOr<void> Function() onAction;

  const _StatusRow({
    required this.icon,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
            ),
          ),
          TextButton(
            onPressed: () async => await onAction(),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
