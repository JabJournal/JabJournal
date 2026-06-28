import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/schedule.dart';
import '../../providers/peptide_provider.dart';
import '../../providers/schedule_provider.dart';
import 'add_edit_schedule_screen.dart';
import 'notification_status_banner.dart';
import 'reschedule_dose_screen.dart';
import '../doses/log_dose_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scheduleProvider = context.read<ScheduleProvider>();
    final peptides = context.read<PeptideProvider>().peptides;
    scheduleProvider.updatePeptideList(peptides);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ScheduleProvider, PeptideProvider>(
      builder: (context, scheduleProvider, peptideProvider, _) {
        scheduleProvider.updatePeptideList(peptideProvider.peptides);
        final eventMap = scheduleProvider.buildEventMap();

        final selectedEvents =
            eventMap[DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day)] ??
                [];

        return Stack(
          children: [
            Column(
              children: [
                const NotificationStatusBanner(),
                TableCalendar<PeptideSchedule>(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                  eventLoader: (day) =>
                      eventMap[DateTime(day.year, day.month, day.day)] ?? [],
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    setState(() => _focusedDay = focusedDay);
                  },
                  calendarStyle: CalendarStyle(
                    markerDecoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    markersMaxCount: 4,
                    todayDecoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      if (events.isEmpty) return const SizedBox();
                      final dayKey = DateTime(day.year, day.month, day.day);
                      return Positioned(
                        bottom: 2,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: events.take(4).map((s) {
                            final color = scheduleProvider.colorForSchedule(s);
                            final isRescheduled =
                                s.isOccurrenceRescheduled(dayKey) ||
                                    s.rescheduleToDate(dayKey) != null;
                            return Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                // Rescheduled days get an outlined ring so
                                // the user can spot moved doses at a glance.
                                // Disabled schedules also render as outlined
                                // dots (paused, not deleted).
                                color: (s.enabled && !isRescheduled)
                                    ? color
                                    : Colors.transparent,
                                border: (!s.enabled || isRescheduled)
                                    ? Border.all(color: color, width: 1)
                                    : null,
                                shape: BoxShape.circle,
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: selectedEvents.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.event_available_outlined,
                                  size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                'No schedules for this day',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                          itemCount: selectedEvents.length,
                          itemBuilder: (context, i) => _ScheduleCard(
                            schedule: selectedEvents[i],
                            scheduleProvider: scheduleProvider,
                            selectedDay: DateTime(
                              _selectedDay.year,
                              _selectedDay.month,
                              _selectedDay.day,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ─── Schedule card ────────────────────────────────────────────────────────────

class _ScheduleCard extends StatelessWidget {
  final PeptideSchedule schedule;
  final ScheduleProvider scheduleProvider;
  final DateTime selectedDay;

  const _ScheduleCard({
    required this.schedule,
    required this.scheduleProvider,
    required this.selectedDay,
  });

  String _formatTime(int secondsFromMidnight) {
    final hour = secondsFromMidnight ~/ 3600;
    final minute = (secondsFromMidnight % 3600) ~/ 60;
    final tod = TimeOfDay(hour: hour, minute: minute);
    final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final m = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  String _formatDays(List<int> days) {
    if (days.isEmpty) return 'Every day';
    const labels = {
      1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu',
      5: 'Fri', 6: 'Sat', 7: 'Sun',
    };
    final sorted = List<int>.from(days)..sort();
    return sorted.map((d) => labels[d]!).join(', ');
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _buildSubtitle() {
    final time = _formatTime(schedule.timeOfDay);
    final tags = <String>[];

    if (schedule.frequency == ScheduleFrequency.once) {
      final d = schedule.specificDate;
      tags.add(d != null ? _formatDate(d) : 'One-time');
    } else {
      tags.add(_formatDays(schedule.daysOfWeek));
      if (schedule.endDate != null) {
        tags.add('until ${_formatDate(schedule.endDate!)}');
      }
    }
    tags.add(time);
    if (schedule.isOccurrenceCompleted(selectedDay)) {
      tags.add('Logged');
    } else if (schedule.isExpired()) {
      tags.add('Expired');
    } else if (!schedule.enabled) {
      tags.add('Paused');
    }
    return tags.join(' · ');
  }

  /// Second subtitle line for the card. Shown only when there's a reschedule
  /// to call out (either the dose was moved away from this day, or moved to
  /// this day). Keeps the main subtitle scannable when there's nothing
  /// reschedule-related to show.
  String? _buildRescheduleSubtitle() {
    final target = schedule.rescheduleTarget(selectedDay);
    if (target != null) {
      // This day is the original — the dose was moved away.
      return 'Rescheduled to ${_formatDateTime(target)}';
    }
    final original = schedule.rescheduleOriginal(selectedDay);
    if (original != null) {
      // This day is the rescheduled target — a dose was moved here.
      return 'Rescheduled from ${_formatDate(original)}';
    }
    return null;
  }

  String _formatDateTime(DateTime dt) {
    final date = _formatDate(dt);
    final tod = TimeOfDay(hour: dt.hour, minute: dt.minute);
    final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final m = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '$date · $h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    final color = scheduleProvider.colorForSchedule(schedule);
    final name = scheduleProvider.peptideNameForSchedule(schedule);
    final theme = Theme.of(context);

    final isOff = !schedule.enabled;
    final isExpired = schedule.isExpired();
    final isLogged = schedule.isOccurrenceCompleted(selectedDay);
    final isRescheduledAway = schedule.isOccurrenceRescheduled(selectedDay);
    final isRescheduledToHere = schedule.rescheduleToDate(selectedDay) != null;
    final dimmed = isOff || isExpired || isLogged;

    IconData leadingIcon;
    if (isLogged) {
      leadingIcon = Icons.check_circle_outline;
    } else if (isExpired) {
      leadingIcon = Icons.event_busy_outlined;
    } else if (isOff) {
      leadingIcon = Icons.notifications_off_outlined;
    } else if (isRescheduledAway) {
      leadingIcon = Icons.compare_arrows;
    } else if (isRescheduledToHere) {
      leadingIcon = Icons.move_to_inbox_outlined;
    } else if (schedule.frequency == ScheduleFrequency.once) {
      leadingIcon = Icons.event_outlined;
    } else {
      leadingIcon = Icons.science;
    }

    final canLogEarly = schedule.enabled && !isExpired && !isLogged;
    final rescheduleLine = _buildRescheduleSubtitle();
    final rescheduledEntry = schedule.rescheduleForOriginalDate(selectedDay);

    return Opacity(
      opacity: dimmed ? 0.55 : 1.0,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(leadingIcon, color: color),
          ),
          title: Text(name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_buildSubtitle()),
              if (rescheduleLine != null) ...[
                const SizedBox(height: 2),
                Text(
                  rescheduleLine,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.tertiary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (isRescheduledAway && rescheduledEntry != null) ...[
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () => _openReschedule(context, schedule, name),
                  icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                  label: const Text('Change new time'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ],
          ),
          isThreeLine: rescheduleLine != null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: schedule.enabled,
                onChanged: (_) => scheduleProvider.toggleEnabled(schedule.id),
              ),
              PopupMenuButton(
                icon: const Icon(Icons.more_vert),
                itemBuilder: (_) => [
                  if (canLogEarly)
                    const PopupMenuItem(
                      value: 'log_early',
                      child: ListTile(
                        leading: Icon(Icons.add_circle_outline),
                        title: Text('Log Dose Early'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  if (canLogEarly)
                    const PopupMenuItem(
                      value: 'reschedule',
                      child: ListTile(
                        leading: Icon(Icons.edit_calendar_outlined),
                        title: Text('Re-schedule dose'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Delete'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'log_early') {
                    final doseId = await Navigator.push<String?>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LogDoseScreen(
                          peptideId: schedule.peptideId,
                          peptideName: name,
                        ),
                      ),
                    );
                    if (doseId != null && context.mounted) {
                      await scheduleProvider.markOccurrenceComplete(
                          schedule.id, selectedDay);
                    }
                  } else if (value == 'reschedule') {
                    await _openReschedule(context, schedule, name);
                  } else if (value == 'edit') {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AddEditScheduleScreen(schedule: schedule),
                      ),
                    );
                    if (context.mounted) {
                      await scheduleProvider.loadAllSchedules();
                    }
                  } else if (value == 'delete') {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete Schedule?'),
                        content: Text(
                            'The "$name" schedule will be permanently deleted.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(
                                foregroundColor:
                                    Theme.of(context).colorScheme.error),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      await scheduleProvider.deleteSchedule(schedule.id);
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openReschedule(
    BuildContext context,
    PeptideSchedule schedule,
    String name,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RescheduleDoseScreen(
          scheduleId: schedule.id,
          peptideId: schedule.peptideId,
          peptideName: name,
          dayOfWeek: selectedDay.weekday,
          originalDate: selectedDay,
        ),
      ),
    );
  }
}
