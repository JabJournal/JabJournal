import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/weight_entry.dart';
import '../../providers/weight_provider.dart';

class LogWeightScreen extends StatefulWidget {
  final WeightEntry? entry;

  const LogWeightScreen({super.key, this.entry});

  bool get isEditing => entry != null;

  @override
  State<LogWeightScreen> createState() => _LogWeightScreenState();
}

class _LogWeightScreenState extends State<LogWeightScreen> {
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    if (e != null) {
      _weightController.text = e.weightLbs.toString();
      _notesController.text = e.notes ?? '';
      _selectedDate = e.recordedAt;
      _selectedTime = TimeOfDay.fromDateTime(e.recordedAt);
    } else {
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
    }
  }

  DateTime get _combinedDateTime => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now(),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (time != null) setState(() => _selectedTime = time);
  }

  Future<void> _save() async {
    final raw = _weightController.text.trim();
    if (raw.isEmpty) {
      _snack('Please enter a weight');
      return;
    }
    final weight = double.tryParse(raw);
    if (weight == null || weight <= 0) {
      _snack('Please enter a valid weight');
      return;
    }
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();

    final provider = context.read<WeightProvider>();
    if (widget.isEditing) {
      await provider.updateWeight(
        id: widget.entry!.id,
        weightLbs: weight,
        recordedAt: _combinedDateTime,
        notes: notes,
      );
    } else {
      await provider.addWeight(
        weightLbs: weight,
        recordedAt: _combinedDateTime,
        notes: notes,
      );
    }
    if (!mounted) return;
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
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.isEditing ? 'Edit Weight' : 'Log Weight'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _weightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Weight (lbs)',
                prefixIcon: const Icon(Icons.monitor_weight_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Text('Date & Time',
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                  ListTile(
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('Date'),
                    trailing: Text(_formatDate(_selectedDate),
                        style:
                            Theme.of(context).textTheme.bodyMedium),
                    onTap: _pickDate,
                  ),
                  const Divider(height: 1, indent: 16),
                  ListTile(
                    leading: const Icon(Icons.access_time_outlined),
                    title: const Text('Time'),
                    trailing: Text(_selectedTime.format(context),
                        style:
                            Theme.of(context).textTheme.bodyMedium),
                    onTap: _pickTime,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: const Icon(Icons.notes_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _save,
              child:
                  Text(widget.isEditing ? 'Save Changes' : 'Log Weight'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
