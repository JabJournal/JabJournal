import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/schedule.dart';
import '../../providers/schedule_provider.dart';

/// Shown when the user taps the "Re-schedule" action on a scheduled-dose
/// notification. Lets them pick a new date + time for the *current* occurrence
/// only; the underlying [PeptideSchedule] (and any future occurrences) are
/// left untouched.
class RescheduleDoseScreen extends StatefulWidget {
  final String scheduleId;
  final String peptideId;
  final String peptideName;
  final int dayOfWeek;

  /// The calendar date the original dose was due. Used as the key in the
  /// schedule's rescheduledOccurrences list. For the notification flow this
  /// is "today" (the notification just fired).
  final DateTime originalDate;

  const RescheduleDoseScreen({
    super.key,
    required this.scheduleId,
    required this.peptideId,
    required this.peptideName,
    required this.dayOfWeek,
    required this.originalDate,
  });

  @override
  State<RescheduleDoseScreen> createState() => _RescheduleDoseScreenState();
}

class _RescheduleDoseScreenState extends State<RescheduleDoseScreen> {
  late DateTime _date;
  late TimeOfDay _time;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Default to the same time tomorrow — a reasonable "snooze" target.
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _date = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    _time = TimeOfDay(hour: tomorrow.hour, minute: tomorrow.minute);
  }

  DateTime get _dateTime => DateTime(
        _date.year,
        _date.month,
        _date.day,
        _time.hour,
        _time.minute,
      );

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(now) ? now : _date,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) setState(() => _time = picked);
  }

  /// True if [_date] would also be a normal scheduled occurrence for this
  /// schedule (independent of the reschedule). For weekly schedules this
  /// means the day-of-week is in `daysOfWeek`. For once-schedules the new
  /// date can never be a normal occurrence (we're moving off the specific
  /// date), so this is always false.
  bool _isNewDayAlsoNormallyScheduled(PeptideSchedule? schedule) {
    if (schedule == null) return false;
    if (schedule.frequency == ScheduleFrequency.once) return false;
    return schedule.daysOfWeek.contains(_date.weekday);
  }

  Future<void> _save() async {
    final candidate = _dateTime;
    if (!candidate.isAfter(DateTime.now())) {
      _snack('Please pick a date and time in the future');
      return;
    }

    final provider = context.read<ScheduleProvider>();
    final schedule = _findSchedule(provider);
    final conflict = _isNewDayAlsoNormallyScheduled(schedule);

    bool replace = false;
    if (conflict) {
      final choice = await _showConflictDialog();
      if (choice == null) return; // user cancelled
      replace = choice;
    }

    setState(() => _saving = true);
    await provider.rescheduleOccurrence(
      scheduleId: widget.scheduleId,
      originalDate: widget.originalDate,
      newDateTime: candidate,
      replacesExistingOnNewDay: replace,
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  PeptideSchedule? _findSchedule(ScheduleProvider provider) {
    try {
      return provider.schedules
          .firstWhere((s) => s.id == widget.scheduleId);
    } catch (_) {
      return null;
    }
  }

  /// Shows the "what to do on the new day" dialog when the new day conflicts
  /// with a normal scheduled occurrence. Returns true for "replace", false
  /// for "keep both", or null if the user cancelled.
  Future<bool?> _showConflictDialog() {
    return showDialog<bool?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Another dose is already scheduled'),
          content: Text(
            '${_dateTimeLabel()} is already a scheduled day for this peptide. '
            'How should the new time be handled?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep both'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Replace only this dose'),
            ),
          ],
        );
      },
    );
  }

  String _dateTimeLabel() {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[_date.month - 1]} ${_date.day} at ${_time.format(context)}';
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Re-schedule Dose'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.science_outlined,
                        size: 28, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.peptideName,
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            'Only this dose will be moved. '
                            'Future reminders stay on schedule.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('Date'),
                    subtitle: Text(_formatDate(_date)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickDate,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('Time'),
                    subtitle: Text(_time.format(context)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickTime,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('Save new time'),
            ),
          ],
        ),
      ),
    );
  }
}
