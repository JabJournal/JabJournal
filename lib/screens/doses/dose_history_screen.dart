import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/dose_history.dart';
import '../../models/peptide.dart';
import '../../providers/dose_history_provider.dart';
import '../../providers/peptide_provider.dart';
import '../../utils/peptide_colors.dart';
import 'log_dose_screen.dart';

class DoseHistoryScreen extends StatefulWidget {
  const DoseHistoryScreen({super.key});

  @override
  State<DoseHistoryScreen> createState() => _DoseHistoryScreenState();
}

class _DoseHistoryScreenState extends State<DoseHistoryScreen> {
  String? _filterPeptideId;

  String _formatDateHeader(DateTime d) {
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    final dateNorm = DateTime(d.year, d.month, d.day);
    final diff = todayNorm.difference(dateNorm).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(d);
    return DateFormat('MMMM d, y').format(d);
  }

  String _formatTime(DateTime d) => DateFormat('h:mm a').format(d);

  Map<DateTime, List<DoseHistory>> _groupByDay(List<DoseHistory> doses) {
    final result = <DateTime, List<DoseHistory>>{};
    for (final dose in doses) {
      final key = DateTime(dose.takenAt.year, dose.takenAt.month, dose.takenAt.day);
      (result[key] ??= []).add(dose);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<DoseHistoryProvider, PeptideProvider>(
        builder: (context, doseProvider, peptideProvider, _) {
          if (doseProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (doseProvider.doses.isEmpty) {
            return _buildEmptyState(context);
          }

          final peptides = peptideProvider.peptides;
          final peptideById = {for (final p in peptides) p.id: p};

          final filtered = _filterPeptideId == null
              ? doseProvider.doses
              : doseProvider.doses
                  .where((d) => d.peptideId == _filterPeptideId)
                  .toList();

          return Column(
            children: [
              if (peptides.length > 1)
                _FilterChipBar(
                  peptides: peptides,
                  selectedId: _filterPeptideId,
                  onSelect: (id) => setState(() => _filterPeptideId = id),
                ),
              Expanded(
                child: filtered.isEmpty
                    ? _buildFilteredEmpty(context)
                    : _buildList(
                        context, filtered, peptideById, peptides, doseProvider),
              ),
            ],
          );
        },
      );
  }

  Widget _buildList(
    BuildContext context,
    List<DoseHistory> doses,
    Map<String, Peptide> peptideById,
    List<Peptide> peptides,
    DoseHistoryProvider doseProvider,
  ) {
    final grouped = _groupByDay(doses);
    final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    // Flatten to [_DateHeader, _DoseItem, _DoseItem, _DateHeader, ...]
    final items = <_ListItem>[];
    for (final day in days) {
      items.add(_DateHeader(_formatDateHeader(day)));
      for (final dose in grouped[day]!) {
        items.add(_DoseItem(dose));
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        if (item is _DateHeader) {
          return _DateHeaderRow(label: item.label);
        }
        final dose = (item as _DoseItem).dose;
        final peptide = peptideById[dose.peptideId];
        final color = peptide == null
            ? Colors.grey
            : resolvedColor(peptide, peptides.indexOf(peptide));
        return _DoseCard(
          dose: dose,
          peptide: peptide,
          color: color,
          timeLabel: _formatTime(dose.takenAt),
          onEdit: () => _editDose(context, dose, peptide, doseProvider),
          onDelete: () => _confirmDelete(context, dose, doseProvider),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No doses logged yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Start logging doses to see them here',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildFilteredEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_list_off, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No doses for this peptide',
              style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  Future<void> _editDose(
    BuildContext context,
    DoseHistory dose,
    Peptide? peptide,
    DoseHistoryProvider doseProvider,
  ) async {
    if (peptide == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LogDoseScreen(
          peptideId: peptide.id,
          peptideName: peptide.name,
          dose: dose,
        ),
      ),
    );
    if (mounted) await doseProvider.loadAllDoses();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    DoseHistory dose,
    DoseHistoryProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Dose?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) provider.deleteDose(dose.id);
  }
}

// ─── List item types ──────────────────────────────────────────────────────────

sealed class _ListItem {}

class _DateHeader extends _ListItem {
  final String label;
  _DateHeader(this.label);
}

class _DoseItem extends _ListItem {
  final DoseHistory dose;
  _DoseItem(this.dose);
}

// ─── Filter chips ─────────────────────────────────────────────────────────────

class _FilterChipBar extends StatelessWidget {
  final List<Peptide> peptides;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  const _FilterChipBar({
    required this.peptides,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          FilterChip(
            label: const Text('All'),
            selected: selectedId == null,
            onSelected: (_) => onSelect(null),
          ),
          ...peptides.indexed.map(((int, Peptide) entry) {
            final (idx, p) = entry;
            final color = resolvedColor(p, idx);
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: FilterChip(
                avatar: CircleAvatar(
                  backgroundColor: color,
                  radius: 8,
                  child: Icon(peptideIconData(p.iconName),
                      size: 10, color: Colors.white),
                ),
                label: Text(p.name),
                selected: selectedId == p.id,
                onSelected: (_) =>
                    onSelect(selectedId == p.id ? null : p.id),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Date header row ──────────────────────────────────────────────────────────

class _DateHeaderRow extends StatelessWidget {
  final String label;
  const _DateHeaderRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

// ─── Dose card ────────────────────────────────────────────────────────────────

class _DoseCard extends StatelessWidget {
  final DoseHistory dose;
  final Peptide? peptide;
  final Color color;
  final String timeLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DoseCard({
    required this.dose,
    required this.peptide,
    required this.color,
    required this.timeLabel,
    required this.onEdit,
    required this.onDelete,
  });

  String get _amountLabel {
    final v = dose.amountMcg;
    return v == v.truncateToDouble() ? '${v.toInt()} mcg' : '$v mcg';
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final hasIsr =
        dose.isrSeverity != null && dose.isrSeverity != IsrSeverity.none;
    final peptideName = peptide?.name ?? 'Unknown Peptide';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(
                peptideIconData(peptide?.iconName),
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Body
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name row + time
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(peptideName,
                            style: tt.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                      Text(timeLabel,
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Dose amount
                  Text(
                    _amountLabel,
                    style: tt.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // Injection site
                  if (dose.injectionSite != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.place_outlined,
                            size: 12, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(dose.injectionSite!,
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ],
                  // Notes
                  if (dose.notes != null && dose.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      dose.notes!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                  // Tags: ISR + side effects
                  if (hasIsr || dose.sideEffects.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (hasIsr) _IsrBadge(severity: dose.isrSeverity!),
                        ...dose.sideEffects.take(3).map(
                              (e) => _Tag(label: e),
                            ),
                        if (dose.sideEffects.length > 3)
                          _Tag(
                              label:
                                  '+${dose.sideEffects.length - 3} more'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Menu
            _DoseMenu(
              onEdit: onEdit,
              onDelete: onDelete,
              canEdit: peptide != null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── ISR severity badge ───────────────────────────────────────────────────────

class _IsrBadge extends StatelessWidget {
  final IsrSeverity severity;
  const _IsrBadge({required this.severity});

  Color _baseColor(BuildContext context) => switch (severity) {
        IsrSeverity.mild => Colors.amber,
        IsrSeverity.moderate => Colors.orange,
        IsrSeverity.severe => Theme.of(context).colorScheme.error,
        IsrSeverity.none => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final c = _baseColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Text(
        'ISR: ${severity.label}',
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: c, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── Tag chip ─────────────────────────────────────────────────────────────────

class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

// ─── Per-dose popup menu ──────────────────────────────────────────────────────

class _DoseMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool canEdit;

  const _DoseMenu({
    required this.onEdit,
    required this.onDelete,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      onSelected: (v) {
        if (v == 'edit') onEdit();
        if (v == 'delete') onDelete();
      },
      itemBuilder: (_) => [
        if (canEdit)
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
    );
  }
}
