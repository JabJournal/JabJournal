import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/dose_history.dart';
import '../../models/peptide.dart';
import '../../providers/peptide_provider.dart';
import '../../providers/dose_history_provider.dart';
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
                if (peptide.vendor != null ||
                    peptide.dosageStrength != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          if (peptide.dosageStrength != null) ...[
                            const Icon(Icons.medication_outlined,
                                size: 20),
                            const SizedBox(width: 6),
                            Text(peptide.dosageStrength!,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium),
                          ],
                          if (peptide.vendor != null &&
                              peptide.dosageStrength != null)
                            const SizedBox(width: 16),
                          if (peptide.vendor != null) ...[
                            const Icon(Icons.storefront_outlined,
                                size: 20),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                peptide.vendor!,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
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
