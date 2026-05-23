import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/calculator_provider.dart';

class CalculatorTab extends StatefulWidget {
  const CalculatorTab({super.key});

  @override
  State<CalculatorTab> createState() => _CalculatorTabState();
}

class _CalculatorTabState extends State<CalculatorTab> {
  final _peptideNameController = TextEditingController();
  final _vialWaterController = TextEditingController();
  final _vialPeptideController = TextEditingController();
  final _desiredDoseController = TextEditingController();

  String _syringeType = 'U-100';
  int _syringeUnits = 100;
  double? _result;

  static const _syringeOptions = {
    'U-100': [100, 50, 30],
    'U-40': [80, 40, 20, 12],
  };

  void _calculate() {
    if (_vialWaterController.text.isEmpty ||
        _vialPeptideController.text.isEmpty ||
        _desiredDoseController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }
    final water = double.tryParse(_vialWaterController.text);
    final peptide = double.tryParse(_vialPeptideController.text);
    final dose = double.tryParse(_desiredDoseController.text);
    if (water == null || peptide == null || dose == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid numbers')),
      );
      return;
    }
    final concentration = (peptide / water) * 1000;
    final dosePerUnit = concentration / _syringeUnits;
    setState(() => _result = dose / dosePerUnit);
  }

  void _save() {
    if (_result == null) return;
    context.read<CalculatorProvider>().saveCalculation(
      peptideName: _peptideNameController.text.isEmpty
          ? 'Unknown'
          : _peptideNameController.text,
      syringeType: _syringeType,
      syringeUnits: _syringeUnits,
      vialWaterMl: double.parse(_vialWaterController.text),
      vialPeptideMl: double.parse(_vialPeptideController.text),
      desiredDoseMcg: double.parse(_desiredDoseController.text),
      resultAmount: _result!,
    );
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Calculation saved')));
    _peptideNameController.clear();
    _vialWaterController.clear();
    _vialPeptideController.clear();
    _desiredDoseController.clear();
    setState(() => _result = null);
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Syringe Settings',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _syringeType,
                    decoration: _inputDecoration('Syringe Type'),
                    onChanged: (v) => setState(() {
                      _syringeType = v!;
                      _syringeUnits = _syringeOptions[v]!.first;
                    }),
                    items: _syringeOptions.keys
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _syringeUnits,
                    decoration: _inputDecoration('Syringe Capacity'),
                    onChanged: (v) => setState(() => _syringeUnits = v!),
                    items: _syringeOptions[_syringeType]!
                        .map((u) => DropdownMenuItem(
                              value: u,
                              child: Text('$u units'),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vial Details',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _vialWaterController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: _inputDecoration('Bacteriostatic Water (mL)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _vialPeptideController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: _inputDecoration('Peptide (mg)'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Desired Dose',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _desiredDoseController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: _inputDecoration('Dose (mcg)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _peptideNameController,
                    decoration: _inputDecoration('Peptide Name (optional)'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_result != null) ...[
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Result',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_result!.toStringAsFixed(2)} units',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'on a $_syringeType $_syringeUnits-unit syringe',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed: _calculate,
            icon: const Icon(Icons.calculate),
            label: const Text('Calculate'),
          ),
          if (_result != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save Calculation'),
            ),
          ],
          const SizedBox(height: 24),
          Consumer<CalculatorProvider>(
            builder: (context, calcProvider, _) {
              if (calcProvider.calculations.isEmpty) return const SizedBox();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Calculations',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...calcProvider.calculations.take(3).map(
                        (c) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(c.peptideName),
                            subtitle: Text(
                              '${c.desiredDoseMcg} mcg → ${c.resultAmount.toStringAsFixed(2)} units',
                            ),
                            trailing: Text(
                              '${c.syringeType} ${c.syringeUnits}u',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ),
                      ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _peptideNameController.dispose();
    _vialWaterController.dispose();
    _vialPeptideController.dispose();
    _desiredDoseController.dispose();
    super.dispose();
  }
}
