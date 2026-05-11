import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/peptide_provider.dart';
import 'add_peptide_screen.dart';
import 'peptide_detail_screen.dart';

class PeptidesListScreen extends StatelessWidget {
  const PeptidesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Peptides')),
      body: Consumer<PeptideProvider>(
        builder: (context, peptideProvider, _) {
          if (peptideProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (peptideProvider.peptides.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.science_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No peptides added yet',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddPeptideScreen()),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Peptide'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: peptideProvider.peptides.length,
            itemBuilder: (context, index) {
              final peptide = peptideProvider.peptides[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(peptide.name),
                  subtitle: peptide.description != null
                      ? Text(peptide.description!)
                      : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PeptideDetailScreen(peptideId: peptide.id),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddPeptideScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
