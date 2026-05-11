import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/calculator_provider.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final _peptideNameController = TextEditingController();
  final _vialWaterController = TextEditingController();
  final _vialPeptideController = TextEditingController();
  final _desiredDoseController = TextEditingController();

  String _syringeType = 'U-100';
  int _syringeUnits = 100;
  double? _result;

  final Map<String, List<int>> _syringeOptions = {
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

    final vialWater = double.tryParse(_vialWaterController.text);
    final vialPeptide = double.tryParse(_vialPeptideController.text);
    final desiredDose = double.tryParse(_desiredDoseController.text);

    if (vialWater == null || vialPeptide == null || desiredDose == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid numbers')),
      );
      return;
    }

    final result = context.read<CalculatorProvider>().calculateDose(
          syringeType: _syringeType,
          syringeUnits: _syringeUnits,
          vialWaterMl: vialWater,
          vialPeptideMl: vialPeptide,
          desiredDoseMcg: desiredDose,
        );

    setState(() => _result = result);
  }

  void _saveCalculation() {
    if (_result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please calculate first')),
      );
      return;
    }

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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calculation saved')),
    );

    setState(() => _result = null);
    _clear();
  }

  void _clear() {
    _peptideNameController.clear();
    _vialWaterController.clear();
    _vialPeptideController.clear();
    _desiredDoseController.clear();
    setState(() => _result = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Peptide Calculator')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Syringe Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Syringe Settings',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 12),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: _syringeType,
                      onChanged: (value) {
                        setState(() {
                          _syringeType = value!;
                          _syringeUnits = _syringeOptions[value]!.first;
                        });
                      },
                      items: _syringeOptions.keys
                          .map((type) =>
                              DropdownMenuItem(value: type, child: Text(type)))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    DropdownButton<int>(
                      isExpanded: true,
                      value: _syringeUnits,
                      onChanged: (value) =>
                          setState(() => _syringeUnits = value!),
                      items: _syringeOptions[_syringeType]!
                          .map((units) => DropdownMenuItem(
                              value: units, child: Text('$units units')))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Vial Details
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vial Details',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _vialWaterController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Water (mL)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _vialPeptideController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Peptide (mL)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Desired Dose
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Desired Dose',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _desiredDoseController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'mcg',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _peptideNameController,
                      decoration: InputDecoration(
                        labelText: 'Peptide Name (optional)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Result
            if (_result != null) ...[
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('Result',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(color: Colors.blue)),
                      const SizedBox(height: 8),
                      Text('${_result!.toStringAsFixed(2)} units',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(color: Colors.blue)),
                      const SizedBox(height: 8),
                      Text(
                          'in a $_syringeType $_syringeUnits unit syringe',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Buttons
            ElevatedButton.icon(
              onPressed: _calculate,
              icon: const Icon(Icons.calculate),
              label: const Text('Calculate'),
            ),
            if (_result != null) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _saveCalculation,
                icon: const Icon(Icons.save),
                label: const Text('Save Calculation'),
              ),
            ],
          ],
        ),
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
