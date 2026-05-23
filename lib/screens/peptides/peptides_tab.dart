import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/dose_history.dart';
import '../../providers/dose_history_provider.dart';
import '../../providers/peptide_provider.dart';
import '../../utils/peptide_colors.dart';
import '../doses/log_dose_screen.dart';
import 'add_peptide_screen.dart';
import 'peptide_detail_screen.dart';

class PeptidesTab extends StatelessWidget {
  const PeptidesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PeptideProvider>(
      builder: (context, peptideProvider, _) {
        if (peptideProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (peptideProvider.peptides.isEmpty) {
          return _EmptyState(
            icon: Icons.science_outlined,
            title: 'No peptides added yet',
            subtitle: 'Tap + to add your first peptide',
          );
        }
        return Consumer<DoseHistoryProvider>(
          builder: (context, doseProvider, _) {
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: peptideProvider.peptides.length,
              itemBuilder: (context, index) {
                final peptide = peptideProvider.peptides[index];
                final color = resolvedColor(peptide, index);
                final icon = peptideIconData(peptide.iconName);
                final doses = doseProvider.doses
                    .where((d) => d.peptideId == peptide.id)
                    .toList();
                final doseCount = doses.length;
                final lastDose = doses.isNotEmpty ? doses.first : null;
                final muted = Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5);
                final hasMetadata =
                    peptide.dosageStrength != null || peptide.vendor != null;

                return Dismissible(
                  key: ValueKey(peptide.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete Peptide?'),
                        content: Text(
                          '"${peptide.name}" and all its dose history will be permanently deleted.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.error,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (_) => peptideProvider.deletePeptide(peptide.id),
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PeptideDetailScreen(peptideId: peptide.id),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: color.withValues(alpha: 0.15),
                              child: Icon(icon, color: color, size: 26),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    peptide.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w600),
                                  ),
                                  if (hasMetadata) ...[
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        if (peptide.dosageStrength !=
                                            null) ...[
                                          Icon(Icons.medication_outlined,
                                              size: 13, color: muted),
                                          const SizedBox(width: 3),
                                          Text(
                                            peptide.dosageStrength!,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(color: muted),
                                          ),
                                        ],
                                        if (peptide.dosageStrength != null &&
                                            peptide.vendor != null)
                                          Text(
                                            ' · ',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(
                                                            alpha: 0.3)),
                                          ),
                                        if (peptide.vendor != null) ...[
                                          Icon(Icons.storefront_outlined,
                                              size: 13, color: muted),
                                          const SizedBox(width: 3),
                                          Flexible(
                                            child: Text(
                                              peptide.vendor!,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(color: muted),
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                  if (peptide.description != null &&
                                      peptide.description!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      peptide.description!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: muted),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 7),
                                  Row(
                                    children: [
                                      _StatChip(
                                        icon: Icons.history,
                                        label: doseCount == 1
                                            ? '1 dose'
                                            : '$doseCount doses',
                                        color: color,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          _lastDosedLabel(lastDose),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(color: muted),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.add_circle_outline,
                                      color: color),
                                  tooltip: 'Log dose',
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => LogDoseScreen(
                                        peptideId: peptide.id,
                                        peptideName: peptide.name,
                                      ),
                                    ),
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert,
                                      size: 20, color: muted),
                                  itemBuilder: (_) => [
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
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AddPeptideScreen(
                                              peptide: peptide),
                                        ),
                                      );
                                    } else if (value == 'delete') {
                                      showDialog(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title:
                                              const Text('Delete Peptide?'),
                                          content: Text(
                                            '"${peptide.name}" and all its dose history will be permanently deleted.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                peptideProvider
                                                    .deletePeptide(peptide.id);
                                                Navigator.pop(context);
                                              },
                                              style: TextButton.styleFrom(
                                                foregroundColor:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .error,
                                              ),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

String _lastDosedLabel(DoseHistory? last) {
  if (last == null) return 'Never dosed';
  final now = DateTime.now();
  final d = last.takenAt.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final dDay = DateTime(d.year, d.month, d.day);
  final diff = today.difference(dDay).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff < 30) return '$diff days ago';
  return DateFormat('MMM d').format(d);
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
