import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/peptide.dart';
import '../../models/schedule.dart';
import '../../providers/peptide_provider.dart';
import '../../providers/schedule_provider.dart';

class AddEditScheduleScreen extends StatefulWidget {
  final PeptideSchedule? schedule;

  const AddEditScheduleScreen({super.key, this.schedule});

  bool get isEditing => schedule != null;

  @override
  State<AddEditScheduleScreen> createState() => _AddEditScheduleScreenState();
}

class _AddEditScheduleScreenState extends State<AddEditScheduleScreen> {
  Peptide? _selectedPeptide;
  ScheduleFrequency _frequency = ScheduleFrequency.weekly;
  final Set<int> _selectedDays = {};
  TimeOfDay _time = TimeOfDay.now();
  DateTime _onceDate = DateTime.now();
  DateTime? _endDate;
  bool _notificationsEnabled = true;

  static const _dayLabels = {
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
    6: 'Sat',
    7: 'Sun',
  };

  @override
  void initState() {
    super.initState();
    final s = widget.schedule;
    if (s != null) {
      _frequency = s.frequency;
      _selectedDays.addAll(s.daysOfWeek);
      _time = TimeOfDay(
          hour: s.timeOfDay ~/ 3600,
          minute: (s.timeOfDay % 3600) ~/ 60);
      _notificationsEnabled = s.enabled;
      _onceDate = s.specificDate ?? DateTime.now();
      _endDate = s.endDate;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedPeptide == null && widget.schedule != null) {
      _selectedPeptide = context
          .read<PeptideProvider>()
          .getPeptideById(widget.schedule!.peptideId);
    }
  }

  int get _secondsFromMidnight => _time.hour * 3600 + _time.minute * 60;

  Future<void> _pickTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickOnceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _onceDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _onceDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  void _save() {
    if (_selectedPeptide == null) {
      _snack('Please select a peptide');
      return;
    }
    if (_frequency == ScheduleFrequency.weekly && _selectedDays.isEmpty) {
      _snack('Please select at least one day');
      return;
    }
    if (_frequency == ScheduleFrequency.once) {
      // Build the candidate fire moment so we can warn if it's in the past.
      final candidate = DateTime(
        _onceDate.year,
        _onceDate.month,
        _onceDate.day,
        _time.hour,
        _time.minute,
      );
      if (candidate.isBefore(DateTime.now()) && !widget.isEditing) {
        _snack('That date and time is in the past');
        return;
      }
    }

    final provider = context.read<ScheduleProvider>();
    final peptideName = _selectedPeptide!.name;
    final sortedDays = _selectedDays.toList()..sort();

    if (widget.isEditing) {
      provider.updateSchedule(
        widget.schedule!.copyWith(
          peptideId: _selectedPeptide!.id,
          frequency: _frequency,
          daysOfWeek: _frequency == ScheduleFrequency.weekly
              ? sortedDays
              : const [],
          timeOfDay: _secondsFromMidnight,
          enabled: _notificationsEnabled,
          specificDate: _frequency == ScheduleFrequency.once ? _onceDate : null,
          endDate: _frequency == ScheduleFrequency.weekly ? _endDate : null,
          clearSpecificDate: _frequency != ScheduleFrequency.once,
          clearEndDate:
              _frequency != ScheduleFrequency.weekly || _endDate == null,
          syncStatus: 'pending',
        ),
        peptideName: peptideName,
      );
    } else {
      provider.addSchedule(
        PeptideSchedule(
          id: const Uuid().v4(),
          peptideId: _selectedPeptide!.id,
          frequency: _frequency,
          daysOfWeek:
              _frequency == ScheduleFrequency.weekly ? sortedDays : const [],
          timeOfDay: _secondsFromMidnight,
          enabled: _notificationsEnabled,
          specificDate:
              _frequency == ScheduleFrequency.once ? _onceDate : null,
          endDate: _frequency == ScheduleFrequency.weekly ? _endDate : null,
        ),
        peptideName: peptideName,
      );
    }

    Navigator.pop(context);
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
    final peptides = context.watch<PeptideProvider>().peptides;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Schedule' : 'New Schedule'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Peptide selector ───────────────────────────────────────────
            DropdownButtonFormField<Peptide>(
              initialValue: _selectedPeptide,
              decoration: InputDecoration(
                labelText: 'Peptide',
                prefixIcon: const Icon(Icons.science_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              items: peptides
                  .map((p) =>
                      DropdownMenuItem(value: p, child: Text(p.name)))
                  .toList(),
              onChanged: (p) => setState(() => _selectedPeptide = p),
            ),
            const SizedBox(height: 24),

            // ── Frequency picker ────────────────────────────────────────
            Text('Frequency',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            SegmentedButton<ScheduleFrequency>(
              segments: const [
                ButtonSegment(
                  value: ScheduleFrequency.once,
                  icon: Icon(Icons.event_outlined),
                  label: Text('Once'),
                ),
                ButtonSegment(
                  value: ScheduleFrequency.weekly,
                  icon: Icon(Icons.repeat),
                  label: Text('Repeat weekly'),
                ),
              ],
              selected: {_frequency},
              onSelectionChanged: (s) =>
                  setState(() => _frequency = s.first),
            ),
            const SizedBox(height: 24),

            // ── Either a single date or weekly day picker + end date ───
            if (_frequency == ScheduleFrequency.once) ...[
              Text('Date',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              InkWell(
                onTap: _pickOnceDate,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    _formatDate(_onceDate),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
            ] else ...[
              Text('Repeat on',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _dayLabels.entries.map((e) {
                  final selected = _selectedDays.contains(e.key);
                  return _DayToggle(
                    label: e.value,
                    selected: selected,
                    onTap: () => setState(() {
                      if (selected) {
                        _selectedDays.remove(e.key);
                      } else {
                        _selectedDays.add(e.key);
                      }
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.event_busy_outlined),
                  title: const Text('End date'),
                  subtitle: Text(
                    _endDate == null
                        ? 'Repeats indefinitely'
                        : 'Stops after ${_formatDate(_endDate!)}',
                  ),
                  trailing: _endDate == null
                      ? TextButton(
                          onPressed: _pickEndDate,
                          child: const Text('Set'),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: _pickEndDate,
                              child: const Text('Change'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () =>
                                  setState(() => _endDate = null),
                            ),
                          ],
                        ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // ── Time picker ────────────────────────────────────────────────
            Text('Time',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickTime,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.access_time),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  _time.format(context),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Notifications toggle ────────────────────────────────────────
            Card(
              margin: EdgeInsets.zero,
              child: SwitchListTile(
                secondary: const Icon(Icons.notifications_outlined),
                title: const Text('Push Notifications'),
                subtitle: Text(_frequency == ScheduleFrequency.once
                    ? 'Remind me at the scheduled time'
                    : 'Remind me at the scheduled time each week'),
                value: _notificationsEnabled,
                onChanged: (v) =>
                    setState(() => _notificationsEnabled = v),
              ),
            ),
            const SizedBox(height: 32),

            FilledButton(
              onPressed: _save,
              child: Text(widget.isEditing ? 'Save Changes' : 'Add Schedule'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Day toggle button ────────────────────────────────────────────────────────

class _DayToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DayToggle(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
        ),
        alignment: Alignment.center,
        child: Text(
          label.substring(0, 2),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
