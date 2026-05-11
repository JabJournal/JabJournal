import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/schedule.dart';
import '../../providers/peptide_provider.dart';
import '../../providers/schedule_provider.dart';
import 'add_edit_schedule_screen.dart';
import 'notification_status_banner.dart';

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
                      return Positioned(
                        bottom: 2,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: events.take(4).map((s) {
                            final color = scheduleProvider.colorForSchedule(s);
                            return Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                // Disabled schedules render as outlined dots
                                // so the user sees they still exist but are
                                // paused.
                                color: s.enabled ? color : Colors.transparent,
                                border: s.enabled
                                    ? null
                                    : Border.all(color: color, width: 1),
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

  const _ScheduleCard(
      {required this.schedule, required this.scheduleProvider});

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
    if (schedule.isExpired()) {
      tags.add('Expired');
    } else if (!schedule.enabled) {
      tags.add('Paused');
    }
    return tags.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final color = scheduleProvider.colorForSchedule(schedule);
    final name = scheduleProvider.peptideNameForSchedule(schedule);

    final isOff = !schedule.enabled;
    final isExpired = schedule.isExpired();
    final dimmed = isOff || isExpired;
    return Opacity(
      opacity: dimmed ? 0.55 : 1.0,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(
            isExpired
                ? Icons.event_busy_outlined
                : (isOff
                    ? Icons.notifications_off_outlined
                    : (schedule.frequency == ScheduleFrequency.once
                        ? Icons.event_outlined
                        : Icons.science)),
            color: color,
          ),
        ),
        title: Text(name),
        subtitle: Text(_buildSubtitle()),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: schedule.enabled,
              onChanged: (_) => scheduleProvider.toggleEnabled(schedule.id),
            ),
            PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Delete'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
              onSelected: (value) async {
                if (value == 'edit') {
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
}
