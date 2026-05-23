import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/dose_history.dart';
import '../../models/peptide.dart';
import '../../providers/peptide_provider.dart';
import '../../providers/dose_history_provider.dart';
import '../../utils/peptide_colors.dart';
import '../doses/log_dose_screen.dart';
import 'add_peptide_screen.dart';

class PeptideDetailScreen extends StatefulWidget {
  final String peptideId;

  const PeptideDetailScreen({super.key, required this.peptideId});

  @override
  State<PeptideDetailScreen> createState() => _PeptideDetailScreenState();
}

class _PeptideDetailScreenState extends State<PeptideDetailScreen> {
  @override
  void initState() {
    super.initState();
  }

  String _formatLastDosed(DoseHistory? last) {
    if (last == null) return '—';
    final now = DateTime.now();
    final d = last.takenAt.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final dDay = DateTime(d.year, d.month, d.day);
    final diff = today.difference(dDay).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 30) return '${diff}d ago';
    return DateFormat('MMM d').format(d);
  }

  void _confirmDelete(BuildContext context, Peptide peptide) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Peptide?'),
        content: Text(
            '"${peptide.name}" and all its dose history will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<PeptideProvider>().deletePeptide(peptide.id);
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // close detail screen
            },
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PeptideProvider>(
      builder: (context, peptideProvider, _) {
        final peptide = peptideProvider.getPeptideById(widget.peptideId);

        // Peptide was deleted elsewhere — close this screen.
        if (peptide == null) {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => Navigator.pop(context));
          return const SizedBox.shrink();
        }

        final peptideIndex = peptideProvider.peptides.indexWhere((p) => p.id == widget.peptideId);
        final colorIndex = peptideIndex >= 0 ? peptideIndex : 0;
        final peptideColor = resolvedColor(peptide, colorIndex);
        final peptideIcon = peptideIconData(peptide.iconName);

        return Scaffold(
          appBar: AppBar(
            title: Text(peptide.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AddPeptideScreen(peptide: peptide),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete',
                onPressed: () => _confirmDelete(context, peptide),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Identity header ──────────────────────────────────
                Card(
                  color: peptideColor.withValues(alpha: 0.08),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: peptideColor.withValues(alpha: 0.25)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor:
                              peptideColor.withValues(alpha: 0.2),
                          child: Icon(peptideIcon,
                              color: peptideColor, size: 30),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                peptide.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              if (peptide.dosageStrength != null ||
                                  peptide.vendor != null) ...[
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 10,
                                  children: [
                                    if (peptide.dosageStrength != null)
                                      _MetaItem(
                                        icon: Icons.medication_outlined,
                                        label: peptide.dosageStrength!,
                                      ),
                                    if (peptide.vendor != null)
                                      _MetaItem(
                                        icon: Icons.storefront_outlined,
                                        label: peptide.vendor!,
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Stats row ────────────────────────────────────────
                Consumer<DoseHistoryProvider>(
                  builder: (context, doseProvider, _) {
                    final doses = doseProvider.doses
                        .where((d) => d.peptideId == widget.peptideId)
                        .toList();
                    final totalMcg = doses.fold<double>(
                        0, (sum, d) => sum + d.amountMcg);
                    final lastDose = doses.isNotEmpty ? doses.first : null;
                    final lastLabel = _formatLastDosed(lastDose);

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _StatItem(
                              label: 'Doses',
                              value: '${doses.length}',
                              color: peptideColor,
                            ),
                            _Divider(),
                            _StatItem(
                              label: 'Total mcg',
                              value: totalMcg == totalMcg.truncate()
                                  ? totalMcg.toInt().toString()
                                  : totalMcg.toStringAsFixed(1),
                              color: peptideColor,
                            ),
                            _Divider(),
                            _StatItem(
                              label: 'Last dose',
                              value: lastLabel,
                              color: peptideColor,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                if (peptide.description != null &&
                    peptide.description!.isNotEmpty) ...[
                  Text('Description',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(peptide.description!),
                  const SizedBox(height: 24),
                ],
                Text('Recent Doses',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 12),
                Consumer<DoseHistoryProvider>(
                  builder: (context, doseProvider, _) {
                    final doses = doseProvider.doses
                        .where((d) => d.peptideId == widget.peptideId)
                        .toList();
                    if (doseProvider.isLoading) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    if (doses.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.local_pharmacy_outlined,
                                  size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text('No doses logged yet',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall),
                            ],
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: doses.length,
                      itemBuilder: (context, index) {
                        final dose = doses[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                                16, 12, 8, 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${dose.amountMcg} mcg',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        dose.takenAt
                                            .toLocal()
                                            .toString()
                                            .substring(0, 16),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                      if (dose.injectionSite != null) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(
                                                Icons.place_outlined,
                                                size: 14),
                                            const SizedBox(width: 4),
                                            Text(dose.injectionSite!,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall),
                                          ],
                                        ),
                                      ],
                                      if (dose.sideEffects.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 4,
                                          runSpacing: 4,
                                          children: dose.sideEffects
                                              .map((e) => _MiniChip(
                                                    label: e,
                                                    color: Colors.orange,
                                                  ))
                                              .toList(),
                                        ),
                                      ],
                                      if (dose.isrSeverity != null &&
                                          dose.isrSeverity !=
                                              IsrSeverity.none) ...[
                                        const SizedBox(height: 6),
                                        _MiniChip(
                                          label:
                                              'ISR: ${dose.isrSeverity!.label}',
                                          color: Colors.red,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  tooltip: 'Edit',
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => LogDoseScreen(
                                        peptideId: peptide.id,
                                        peptideName: peptide.name,
                                        dose: dose,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon:
                                      const Icon(Icons.delete_outline),
                                  tooltip: 'Delete',
                                  onPressed: () =>
                                      doseProvider.deleteDose(dose.id),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LogDoseScreen(
                    peptideId: peptide.id,
                    peptideName: peptide.name),
              ),
            ),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatItem(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: VerticalDivider(
        color:
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
        width: 1,
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context)
        .colorScheme
        .onSurface
        .withValues(alpha: 0.55);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: muted),
        const SizedBox(width: 4),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: muted)),
      ],
    );
  }
}
