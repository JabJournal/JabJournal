import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/weight_entry.dart';
import '../../providers/weight_provider.dart';
import 'log_weight_screen.dart';

class WeightHistoryScreen extends StatefulWidget {
  const WeightHistoryScreen({super.key});

  @override
  State<WeightHistoryScreen> createState() => _WeightHistoryScreenState();
}

class _WeightHistoryScreenState extends State<WeightHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WeightProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weight Log')),
      body: Consumer<WeightProvider>(
        builder: (context, wp, _) {
          if (wp.isLoading && wp.entries.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (wp.entries.isEmpty) {
            return _EmptyState(onAdd: () => _openLogScreen(context));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SummaryCard(provider: wp),
              const SizedBox(height: 16),
              if (wp.entries.length >= 2) ...[
                _WeightChart(entries: wp.entries),
                const SizedBox(height: 16),
              ],
              Text('History',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...wp.entries.map((e) => _WeightTile(
                    entry: e,
                    onEdit: () => _openLogScreen(context, entry: e),
                    onDelete: () => _confirmDelete(context, e),
                  )),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openLogScreen(context),
        icon: const Icon(Icons.add),
        label: const Text('Log Weight'),
      ),
    );
  }

  void _openLogScreen(BuildContext context, {WeightEntry? entry}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LogWeightScreen(entry: entry)),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WeightEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: Text(
            'Delete weight entry from ${_formatDate(entry.recordedAt)}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                  foregroundColor:
                      Theme.of(context).colorScheme.error),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<WeightProvider>().deleteWeight(entry.id);
    }
  }
}

String _formatDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

// ─── Summary Card (latest weight + trend) ────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final WeightProvider provider;
  const _SummaryCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final latest = provider.latest;
    final trend = provider.trendLbs;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current Weight',
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(
                    latest == null
                        ? '—'
                        : '${latest.weightLbs.toStringAsFixed(1)} lbs',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (latest != null)
                    Text(
                      _formatDate(latest.recordedAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
            if (trend != null) _TrendBadge(deltaLbs: trend),
          ],
        ),
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  final double deltaLbs;
  const _TrendBadge({required this.deltaLbs});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLoss = deltaLbs < 0;
    final isFlat = deltaLbs.abs() < 0.05;
    final color = isFlat
        ? scheme.onSurfaceVariant
        : isLoss
            ? Colors.green
            : Colors.orange;
    final icon = isFlat
        ? Icons.trending_flat
        : isLoss
            ? Icons.trending_down
            : Icons.trending_up;
    final sign = deltaLbs > 0 ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 4),
              Text(
                '$sign${deltaLbs.toStringAsFixed(1)} lbs',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Text('vs last entry',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ─── Chart ───────────────────────────────────────────────────────────────────

class _WeightChart extends StatelessWidget {
  final List<WeightEntry> entries;
  const _WeightChart({required this.entries});

  @override
  Widget build(BuildContext context) {
    // Oldest first for x-axis ordering.
    final ordered = entries.reversed.toList();
    final spots = <FlSpot>[];
    for (var i = 0; i < ordered.length; i++) {
      spots.add(FlSpot(i.toDouble(), ordered[i].weightLbs));
    }
    final minY = ordered
            .map((e) => e.weightLbs)
            .reduce((a, b) => a < b ? a : b) -
        2;
    final maxY = ordered
            .map((e) => e.weightLbs)
            .reduce((a, b) => a > b ? a : b) +
        2;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trend',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: minY,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: ((maxY - minY) / 4).clamp(1, 10),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (v, _) => Text(
                          v.toStringAsFixed(0),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: (ordered.length / 5).ceilToDouble().clamp(1, 100),
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= ordered.length) {
                            return const SizedBox();
                          }
                          final d = ordered[i].recordedAt;
                          return Text(
                            '${d.month}/${d.day}',
                            style: Theme.of(context).textTheme.bodySmall,
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: scheme.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: scheme.primary.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) =>
                          scheme.surfaceContainerHighest,
                      getTooltipItems: (spots) => spots.map((s) {
                        final i = s.x.toInt();
                        final d = ordered[i].recordedAt;
                        return LineTooltipItem(
                          '${d.month}/${d.day}\n${s.y.toStringAsFixed(1)} lbs',
                          TextStyle(color: scheme.onSurface),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tile ────────────────────────────────────────────────────────────────────

class _WeightTile extends StatelessWidget {
  final WeightEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _WeightTile({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.monitor_weight_outlined),
        title: Text('${entry.weightLbs.toStringAsFixed(1)} lbs'),
        subtitle: Text(_formatDate(entry.recordedAt) +
            (entry.doseId != null ? '  •  paired with dose' : '')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: Theme.of(context).colorScheme.error,
              onPressed: onDelete,
            ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monitor_weight_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No weight entries yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Track your weight on injection day to see trends.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Log Your First Weight'),
            ),
          ],
        ),
      ),
    );
  }
}
