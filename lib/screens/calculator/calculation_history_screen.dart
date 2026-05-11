import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/calculator_provider.dart';

class CalculationHistoryScreen extends StatelessWidget {
  const CalculationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calculation History')),
      body: Consumer<CalculatorProvider>(
        builder: (context, calcProvider, _) {
          if (calcProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (calcProvider.calculations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calculate_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No calculations saved yet',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: calcProvider.calculations.length,
            itemBuilder: (context, index) {
              final calc = calcProvider.calculations[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(calc.peptideName,
                              style:
                                  Theme.of(context).textTheme.titleSmall),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              calcProvider.deleteCalculation(calc.id);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Desired Dose',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall),
                                Text('${calc.desiredDoseMcg} mcg'),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Result',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall),
                                Text('${calc.resultAmount.toStringAsFixed(2)} units'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                          '${calc.syringeType} ${calc.syringeUnits}u • ${calc.vialWaterMl}mL water + ${calc.vialPeptideMl}mL peptide',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 8),
                      Text(calc.calculatedAt.toString(),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
