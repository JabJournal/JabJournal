import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/dose_history.dart';
import '../../models/weight_entry.dart';
import '../../providers/dose_history_provider.dart';
import '../../providers/weight_provider.dart';

const _injectionSites = <String>[
  'Abdomen',
  'Left Thigh',
  'Right Thigh',
  'Left Arm',
  'Right Arm',
  'Left Glute',
  'Right Glute',
];

const _commonSideEffects = <String>[
  'Nausea',
  'Fatigue',
  'Headache',
  'Insomnia',
  'Hunger Suppression',
  'GI Issues',
  'Dizziness',
  'Mood Changes',
];

class LogDoseScreen extends StatefulWidget {
  final String peptideId;
  final String peptideName;
  final DoseHistory? dose;

  const LogDoseScreen({
    super.key,
    required this.peptideId,
    required this.peptideName,
    this.dose,
  });

  bool get isEditing => dose != null;

  @override
  State<LogDoseScreen> createState() => _LogDoseScreenState();
}

class _LogDoseScreenState extends State<LogDoseScreen> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _isrController = TextEditingController();
  final _weightController = TextEditingController();
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  String? _injectionSite;
  final Set<String> _selectedEffects = {};
  IsrSeverity? _isrSeverity;

  WeightEntry? _existingWeightEntry;

  @override
  void initState() {
    super.initState();
    final dose = widget.dose;
    if (dose != null) {
      _amountController.text = dose.amountMcg.toString();
      _notesController.text = dose.notes ?? '';
      _selectedDate = dose.takenAt;
      _selectedTime = TimeOfDay.fromDateTime(dose.takenAt);
      _injectionSite = dose.injectionSite;
      _selectedEffects.addAll(dose.sideEffects);
      _isrSeverity = dose.isrSeverity;
      _isrController.text = dose.injectionSiteReaction ?? '';

      // If a weight is paired with this dose, prefill the weight field.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final wp = context.read<WeightProvider>();
        if (wp.entries.isEmpty) {
          await wp.loadAll();
        }
        final paired = wp.entries.firstWhere(
          (w) => w.doseId == dose.id,
          orElse: () => WeightEntry(
            id: '',
            weightLbs: 0,
            recordedAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        );
        if (paired.id.isNotEmpty && mounted) {
          setState(() {
            _existingWeightEntry = paired;
            _weightController.text = paired.weightLbs.toString();
          });
        }
      });
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
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
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
    if (_amountController.text.isEmpty) {
      _snack('Please enter the dose amount');
      return;
    }
    final amount = double.tryParse(_amountController.text);
    if (amount == null) {
      _snack('Please enter a valid dose amount');
      return;
    }

    double? weight;
    if (_weightController.text.trim().isNotEmpty) {
      weight = double.tryParse(_weightController.text.trim());
      if (weight == null) {
        _snack('Please enter a valid weight or leave it blank');
        return;
      }
    }

    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();
    final isr = _isrController.text.trim().isEmpty
        ? null
        : _isrController.text.trim();

    final doseProvider = context.read<DoseHistoryProvider>();
    final weightProvider = context.read<WeightProvider>();

    String? doseId;
    if (widget.isEditing) {
      await doseProvider.updateDose(
        id: widget.dose!.id,
        amountMcg: amount,
        takenAt: _combinedDateTime,
        notes: notes,
        injectionSite: _injectionSite,
        sideEffects: _selectedEffects.toList(),
        injectionSiteReaction: isr,
        isrSeverity: _isrSeverity,
      );
      doseId = widget.dose!.id;
    } else {
      doseId = await doseProvider.addDose(
        peptideId: widget.peptideId,
        amountMcg: amount,
        takenAt: _combinedDateTime,
        notes: notes,
        injectionSite: _injectionSite,
        sideEffects: _selectedEffects.toList(),
        injectionSiteReaction: isr,
        isrSeverity: _isrSeverity,
      );
    }

    // Sync paired weight entry.
    if (weight != null) {
      final existing = _existingWeightEntry;
      if (existing != null) {
        await weightProvider.updateWeight(
          id: existing.id,
          weightLbs: weight,
          recordedAt: _combinedDateTime,
          notes: existing.notes,
        );
      } else if (doseId != null) {
        await weightProvider.addWeight(
          weightLbs: weight,
          recordedAt: _combinedDateTime,
          doseId: doseId,
        );
      }
    } else if (_existingWeightEntry != null) {
      // User cleared the weight — remove the paired entry.
      await weightProvider.deleteWeight(_existingWeightEntry!.id);
    }

    if (!mounted) return;
    Navigator.pop(context, doseId);
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
        title: Text(widget.isEditing
            ? 'Edit Dose - ${widget.peptideName}'
            : 'Log Dose - ${widget.peptideName}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Dose amount ─────────────────────────────────────────────
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Dose Amount (mcg)',
                prefixIcon: const Icon(Icons.local_pharmacy_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),

            // ── Date & Time ─────────────────────────────────────────────
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
                    trailing: Text(
                      _formatDate(_selectedDate),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    onTap: _pickDate,
                  ),
                  const Divider(height: 1, indent: 16),
                  ListTile(
                    leading: const Icon(Icons.access_time_outlined),
                    title: const Text('Time'),
                    trailing: Text(
                      _selectedTime.format(context),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    onTap: _pickTime,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Weight (optional) ──────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Weight (optional)',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      'Track weight on injection day for trend analysis.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Weight (lbs)',
                        prefixIcon:
                            const Icon(Icons.monitor_weight_outlined),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Injection site ─────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Injection Site',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _injectionSites.map((site) {
                        return ChoiceChip(
                          label: Text(site),
                          selected: _injectionSite == site,
                          onSelected: (selected) {
                            setState(() {
                              _injectionSite = selected ? site : null;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Side effects ───────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Side Effects',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      'Tap any effects observed since the previous dose.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _commonSideEffects.map((effect) {
                        final selected = _selectedEffects.contains(effect);
                        return FilterChip(
                          label: Text(effect),
                          selected: selected,
                          onSelected: (v) {
                            setState(() {
                              if (v) {
                                _selectedEffects.add(effect);
                              } else {
                                _selectedEffects.remove(effect);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    // Show any custom (non-preset) effects already attached.
                    if (_selectedEffects.any((e) => !_commonSideEffects.contains(e))) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedEffects
                            .where((e) => !_commonSideEffects.contains(e))
                            .map((e) => InputChip(
                                  label: Text(e),
                                  onDeleted: () =>
                                      setState(() => _selectedEffects.remove(e)),
                                ))
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _addCustomEffect,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add custom effect'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Injection Site Reaction ────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Injection Site Reaction',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: IsrSeverity.values.map((s) {
                        return ChoiceChip(
                          label: Text(s.label),
                          selected: _isrSeverity == s,
                          onSelected: (v) {
                            setState(
                                () => _isrSeverity = v ? s : null);
                          },
                        );
                      }).toList(),
                    ),
                    if (_isrSeverity != null &&
                        _isrSeverity != IsrSeverity.none) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _isrController,
                        decoration: InputDecoration(
                          labelText: 'Description (optional)',
                          hintText: 'redness, bruising, swelling…',
                          prefixIcon:
                              const Icon(Icons.healing_outlined),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Notes ───────────────────────────────────────────────────
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
                  Text(widget.isEditing ? 'Save Changes' : 'Log Dose'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addCustomEffect() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Side Effect'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'e.g. Brain fog',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(context, controller.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _selectedEffects.add(result));
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _isrController.dispose();
    _weightController.dispose();
    super.dispose();
  }
}
