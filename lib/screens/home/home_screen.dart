import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/peptide.dart';
import '../../utils/peptide_colors.dart';
import '../../providers/peptide_provider.dart';
import '../../providers/dose_history_provider.dart';
import '../../providers/calculator_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/weight_provider.dart';
import '../peptides/add_peptide_screen.dart';
import '../peptides/peptide_detail_screen.dart';
import '../doses/dose_history_screen.dart';
import '../doses/log_dose_screen.dart';
import '../settings/settings_screen.dart';
import '../schedules/schedule_screen.dart';
import '../schedules/add_edit_schedule_screen.dart';
import '../weight/log_weight_screen.dart';
import '../weight/weight_history_screen.dart';
import 'dashboard_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _fabExpanded = false;
  late final AnimationController _fabController;

  static const _titles = [
    'Dashboard',
    'Peptides',
    'Calculator',
    'History',
    'Schedules',
  ];

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    // Remove items from the tree only after the close animation finishes.
    _fabController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && _fabExpanded) {
        setState(() => _fabExpanded = false);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PeptideProvider>().loadPeptides();
      context.read<DoseHistoryProvider>().loadAllDoses();
      context.read<CalculatorProvider>().loadCalculations();
      context.read<ScheduleProvider>().loadAllSchedules();
      context.read<WeightProvider>().loadAll();
    });
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  void _toggleFab() {
    if (_fabExpanded) {
      // Start closing; StatusListener will set _fabExpanded = false on dismiss.
      _fabController.reverse();
    } else {
      setState(() => _fabExpanded = true);
      _fabController.forward();
    }
  }

  void _closeFab() {
    if (!_fabExpanded) return;
    _fabController.reverse();
    // _fabExpanded is cleared by the StatusListener when the animation dismisses.
  }

  void _selectTab(int index) {
    _closeFab();
    setState(() => _selectedIndex = index);
    Navigator.pop(context);
  }

  void _showLogDosePicker() {
    final peptides = context.read<PeptideProvider>().peptides;
    if (peptides.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a peptide first before logging a dose'),
        ),
      );
      return;
    }
    if (peptides.length == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LogDoseScreen(
            peptideId: peptides.first.id,
            peptideName: peptides.first.name,
          ),
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _PeptidePicker(peptides: peptides),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _closeFab,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_titles[_selectedIndex]),
          elevation: 0,
          actions: const [],
        ),
        drawer: _buildDrawer(),
        body: Stack(
          children: [
            IndexedStack(
              index: _selectedIndex,
              children: const [
                DashboardTab(),
                _PeptidesTab(),
                _CalculatorTab(),
                DoseHistoryScreen(),
                ScheduleScreen(),
              ],
            ),
            if (_fabExpanded)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeFab,
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.black26),
                ),
              ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
            _closeFab();
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.science_outlined),
              selectedIcon: Icon(Icons.science),
              label: 'Peptides',
            ),
            NavigationDestination(
              icon: Icon(Icons.calculate_outlined),
              selectedIcon: Icon(Icons.calculate),
              label: 'Calculator',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Schedules',
            ),
          ],
        ),
        floatingActionButton: _selectedIndex == 4
            ? FloatingActionButton(
                heroTag: 'schedules_fab',
                onPressed: () async {
                  final scheduleProvider = context.read<ScheduleProvider>();
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddEditScheduleScreen(),
                    ),
                  );
                  if (mounted) {
                    await scheduleProvider.loadAllSchedules();
                  }
                },
                child: const Icon(Icons.add),
              )
            : _buildSpeedDial(),
      ),
    );
  }

  Widget _buildDrawer() {
    final colorScheme = Theme.of(context).colorScheme;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: colorScheme.primaryContainer),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.science, size: 48, color: colorScheme.primary),
                const SizedBox(height: 8),
                Text(
                  'JabJournal',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  'Track your peptide journey',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          _DrawerNavItem(
            icon: Icons.dashboard,
            label: 'Dashboard',
            selected: _selectedIndex == 0,
            onTap: () => _selectTab(0),
          ),
          _DrawerNavItem(
            icon: Icons.science,
            label: 'Peptides',
            selected: _selectedIndex == 1,
            onTap: () => _selectTab(1),
          ),
          _DrawerNavItem(
            icon: Icons.calculate,
            label: 'Calculator',
            selected: _selectedIndex == 2,
            onTap: () => _selectTab(2),
          ),
          _DrawerNavItem(
            icon: Icons.history,
            label: 'History',
            selected: _selectedIndex == 3,
            onTap: () => _selectTab(3),
          ),
          _DrawerNavItem(
            icon: Icons.calendar_month,
            label: 'Schedules',
            selected: _selectedIndex == 4,
            onTap: () => _selectTab(4),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Quick Actions',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: Colors.grey),
            ),
          ),
          _DrawerNavItem(
            icon: Icons.add_circle_outline,
            label: 'Add Peptide',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddPeptideScreen()),
              );
            },
          ),
          _DrawerNavItem(
            icon: Icons.local_pharmacy_outlined,
            label: 'Log Dose',
            onTap: () {
              Navigator.pop(context);
              _showLogDosePicker();
            },
          ),
          _DrawerNavItem(
            icon: Icons.monitor_weight_outlined,
            label: 'Log Weight',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LogWeightScreen()),
              );
            },
          ),
          _DrawerNavItem(
            icon: Icons.timeline_outlined,
            label: 'Weight History',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const WeightHistoryScreen()),
              );
            },
          ),
          const Divider(),
          _DrawerNavItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedDial() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_fabExpanded) ...[
          _dialItem(0, 'Add Peptide', Icons.science, Colors.blue, () {
            _closeFab();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddPeptideScreen()),
            );
          }),
          const SizedBox(height: 10),
          _dialItem(1, 'Log Dose', Icons.local_pharmacy, Colors.green, () {
            _closeFab();
            _showLogDosePicker();
          }),
          const SizedBox(height: 10),
          _dialItem(2, 'Log Weight', Icons.monitor_weight, Colors.teal, () {
            _closeFab();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LogWeightScreen()),
            );
          }),
          const SizedBox(height: 10),
          _dialItem(3, 'Calculator', Icons.calculate, Colors.orange, () {
            _closeFab();
            setState(() => _selectedIndex = 2);
          }),
          const SizedBox(height: 10),
          _dialItem(4, 'Add Schedule', Icons.calendar_month, Colors.purple, () {
            _closeFab();
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AddEditScheduleScreen()),
            ).then((_) {
              if (mounted) {
                context.read<ScheduleProvider>().loadAllSchedules();
              }
            });
          }),
          const SizedBox(height: 10),
        ],
        FloatingActionButton(
          heroTag: 'main_fab',
          onPressed: _toggleFab,
          child: RotationTransition(
            turns: Tween(begin: 0.0, end: 0.125).animate(
              CurvedAnimation(parent: _fabController, curve: Curves.easeInOut),
            ),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  /// Builds an animated speed-dial item.
  ///
  /// Items are ordered top-to-bottom (index 0 = top).  We reverse the stagger
  /// so the item closest to the FAB (index 4) fades in first.
  Widget _dialItem(int index, String label, IconData icon, Color color,
      VoidCallback onTap) {
    const total = 5;
    // index 4 (bottom) → delay 0; index 0 (top) → delay 0.32
    final delay = (total - 1 - index) * 0.08;
    final itemCurve = CurvedAnimation(
      parent: _fabController,
      curve: Interval(delay, (delay + 0.55).clamp(0.0, 1.0),
          curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: itemCurve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.15, 0),
          end: Offset.zero,
        ).animate(itemCurve),
        child:
            _SpeedDialItem(label: label, icon: icon, color: color, onTap: onTap),
      ),
    );
  }
}

// ─── Drawer nav item ────────────────────────────────────────────────────────

class _DrawerNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  const _DrawerNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: selected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(label),
      selected: selected,
      selectedColor: Theme.of(context).colorScheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: onTap,
    );
  }
}

// ─── Speed dial mini button ─────────────────────────────────────────────────

class _SpeedDialItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SpeedDialItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          elevation: 3,
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ),
        const SizedBox(width: 10),
        FloatingActionButton.small(
          heroTag: null,
          backgroundColor: color,
          onPressed: onTap,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ],
    );
  }
}

// ─── Peptide picker bottom sheet ─────────────────────────────────────────────

class _PeptidePicker extends StatelessWidget {
  final List<Peptide> peptides;

  const _PeptidePicker({required this.peptides});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Text('Select Peptide', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...peptides.asMap().entries.map(
          (e) => ListTile(
            leading: _PeptideAvatar(peptide: e.value, index: e.key),
            title: Text(e.value.name),
            subtitle: e.value.description != null
                ? Text(e.value.description!)
                : null,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LogDoseScreen(
                      peptideId: e.value.id, peptideName: e.value.name),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─── Peptide avatar (colored circle + icon) ───────────────────────────────────

class _PeptideAvatar extends StatelessWidget {
  final Peptide peptide;
  final int index;

  const _PeptideAvatar({required this.peptide, required this.index});

  @override
  Widget build(BuildContext context) {
    final color = resolvedColor(peptide, index);
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.18),
      child: Icon(
        peptideIconData(peptide.iconName),
        color: color,
        size: 22,
      ),
    );
  }
}

// ─── Peptides tab ────────────────────────────────────────────────────────────

class _PeptidesTab extends StatelessWidget {
  const _PeptidesTab();

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
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: peptideProvider.peptides.length,
          itemBuilder: (context, index) {
            final peptide = peptideProvider.peptides[index];
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
                          foregroundColor: Theme.of(context).colorScheme.error,
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
                child: ListTile(
                  leading: _PeptideAvatar(peptide: peptide, index: index),
                  title: Text(peptide.name),
                  subtitle: peptide.description != null
                      ? Text(
                          peptide.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  trailing: PopupMenuButton(
                    icon: const Icon(Icons.more_vert),
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
                            builder: (_) => AddPeptideScreen(peptide: peptide),
                          ),
                        );
                      } else if (value == 'delete') {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete Peptide?'),
                            content: Text(
                              '"${peptide.name}" and all its dose history will be permanently deleted.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  peptideProvider.deletePeptide(peptide.id);
                                  Navigator.pop(context);
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.error,
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PeptideDetailScreen(peptideId: peptide.id),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Calculator tab ──────────────────────────────────────────────────────────

class _CalculatorTab extends StatefulWidget {
  const _CalculatorTab();

  @override
  State<_CalculatorTab> createState() => _CalculatorTabState();
}

class _CalculatorTabState extends State<_CalculatorTab> {
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Calculation saved')));
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
          // Syringe Settings
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
                        .map(
                          (u) => DropdownMenuItem(
                            value: u,
                            child: Text('$u units'),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Vial Details
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
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: _inputDecoration('Bacteriostatic Water (mL)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _vialPeptideController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: _inputDecoration('Peptide (mg)'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Desired Dose
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
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
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
          // Result
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
                      style: Theme.of(context).textTheme.headlineMedium
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
          // History preview
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
                  ...calcProvider.calculations
                      .take(3)
                      .map(
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

// ─── History tab ─────────────────────────────────────────────────────────────


// ─── Shared widgets ──────────────────────────────────────────────────────────

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
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
