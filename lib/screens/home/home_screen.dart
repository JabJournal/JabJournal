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
import '../peptides/peptides_tab.dart';
import '../doses/dose_history_screen.dart';
import '../doses/log_dose_screen.dart';
import '../settings/settings_screen.dart';
import '../schedules/schedule_screen.dart';
import '../schedules/add_edit_schedule_screen.dart';
import '../weight/log_weight_screen.dart';
import '../weight/weight_history_screen.dart';
import '../../services/notification_router.dart';
import '../../services/notification_service.dart';
import '../calculator/calculator_tab.dart';
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
      // Flush any notification tap that arrived before the widget tree was
      // ready (cold-start on aggressive OEM task-killers like Samsung One UI).
      NotificationRouter.flushPending();
      NotificationService().checkLaunchDetails();
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
                PeptidesTab(),
                CalculatorTab(),
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

