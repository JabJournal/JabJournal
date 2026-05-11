import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/peptide.dart';
import '../../models/schedule.dart';
import '../../providers/dose_history_provider.dart';
import '../../providers/peptide_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/weight_provider.dart';
import '../../utils/peptide_colors.dart';
import '../peptides/peptide_detail_screen.dart';
import '../weight/weight_history_screen.dart';

// ─── Timeframe definition ────────────────────────────────────────────────────

enum DashboardTimeframe {
  day('1D', 1),
  week('1W', 7),
  twoWeeks('2W', 14),
  month('1M', 30),
  threeMonths('3M', 90),
  all('All', 0);

  final String label;
  final int days;
  const DashboardTimeframe(this.label, this.days);

  DateTime get rangeStart {
    if (days == 0) return DateTime.fromMillisecondsSinceEpoch(0);
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
  }

  DateTime? get filterFrom => days == 0 ? null : rangeStart;

  double get labelInterval {
    switch (this) {
      case day:
        return 1;
      case week:
        return 1;
      case twoWeeks:
        return 2;
      case month:
        return 7;
      case threeMonths:
        return 15;
      case all:
        return 30;
    }
  }
}

// ─── Dashboard tab ────────────────────────────────────────────────────────────

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  DashboardTimeframe _timeframe = DashboardTimeframe.week;

  @override
  Widget build(BuildContext context) {
    return Consumer3<PeptideProvider, DoseHistoryProvider, ScheduleProvider>(
      builder: (context, peptideProvider, doseProvider, scheduleProvider, _) {
        if (peptideProvider.isLoading || doseProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final peptides = peptideProvider.peptides;
        final filtered = doseProvider.dosesInRange(_timeframe.filterFrom);
        final doseCountByPeptide = <String, int>{};
        final mcgByPeptide = <String, double>{};

        for (final d in filtered) {
          doseCountByPeptide[d.peptideId] =
              (doseCountByPeptide[d.peptideId] ?? 0) + 1;
          mcgByPeptide[d.peptideId] =
              (mcgByPeptide[d.peptideId] ?? 0) + d.amountMcg;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ──────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Overview',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  _TimeframeSelector(
                    selected: _timeframe,
                    onChanged: (tf) => setState(() => _timeframe = tf),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Stat cards ───────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Peptides',
                      value: peptides.length.toString(),
                      icon: Icons.science,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Doses',
                      value: filtered.length.toString(),
                      icon: Icons.local_pharmacy,
                      color: Colors.green,
                      subtitle: _timeframe.days > 0
                          ? 'last ${_timeframe.days}d'
                          : 'all time',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Next dose card ───────────────────────────────────────────
              _NextDoseCard(
                scheduleProvider: scheduleProvider,
                peptides: peptides,
              ),
              const SizedBox(height: 12),

              // ── Weight summary ──────────────────────────────────────────
              const _WeightSummaryCard(),
              const SizedBox(height: 24),

              // ── Chart section ─────────────────────────────────────────────
              if (peptides.isEmpty)
                _EmptyState(
                  icon: Icons.science_outlined,
                  title: 'No peptides yet',
                  subtitle: 'Tap + to add your first peptide',
                )
              else ...[
                // ── Monthly activity grid ──────────────────────────────────
                _MonthlyDoseGrid(
                  peptides: peptides,
                  doseProvider: doseProvider,
                ),
                const SizedBox(height: 16),

                Text(
                  'Dose History',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _DoseBarChart(
                  peptides: peptides,
                  doseProvider: doseProvider,
                  timeframe: _timeframe,
                ),
                const SizedBox(height: 24),

                // ── Per-peptide summary ──────────────────────────────────
                Text(
                  'Peptide Summary',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ...peptides.asMap().entries.map(
                  (e) => _PeptideSummaryCard(
                    peptideId: e.value.id,
                    name: e.value.name,
                    doseCount: doseCountByPeptide[e.value.id] ?? 0,
                    totalMcg: mcgByPeptide[e.value.id] ?? 0.0,
                    color: resolvedColor(e.value, e.key),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─── Timeframe selector ───────────────────────────────────────────────────────

class _TimeframeSelector extends StatelessWidget {
  final DashboardTimeframe selected;
  final ValueChanged<DashboardTimeframe> onChanged;

  const _TimeframeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 500) {
      return DropdownButton<DashboardTimeframe>(
        value: selected,
        isDense: true,
        underline: const SizedBox(),
        items: DashboardTimeframe.values
            .map((tf) => DropdownMenuItem(value: tf, child: Text(tf.label)))
            .toList(),
        onChanged: (tf) {
          if (tf != null) onChanged(tf);
        },
      );
    }
    return SegmentedButton<DashboardTimeframe>(
      segments: DashboardTimeframe.values
          .map(
            (tf) => ButtonSegment(
              value: tf,
              label: Text(tf.label, style: const TextStyle(fontSize: 12)),
            ),
          )
          .toList(),
      selected: {selected},
      onSelectionChanged: (s) => onChanged(s.first),
      style: ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

// ─── Next dose card ───────────────────────────────────────────────────────────

class _NextDoseCard extends StatefulWidget {
  final ScheduleProvider scheduleProvider;
  final List<Peptide> peptides;

  const _NextDoseCard({
    required this.scheduleProvider,
    required this.peptides,
  });

  @override
  State<_NextDoseCard> createState() => _NextDoseCardState();
}

class _NextDoseCardState extends State<_NextDoseCard> {
  late Timer _ticker;

  @override
  void initState() {
    super.initState();
    // Rebuild every minute so the "in Xh Ym" label stays current without
    // needing a provider notification or an app restart.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _computeNextDose(widget.scheduleProvider.schedules);
    if (result == null) return const SizedBox.shrink();

    final schedule = result.$1;
    final nextAt = result.$2;

    final peptideIndex =
        widget.peptides.indexWhere((p) => p.id == schedule.peptideId);
    final peptide =
        peptideIndex >= 0 ? widget.peptides[peptideIndex] : null;
    final color = peptide != null
        ? resolvedColor(peptide, peptideIndex)
        : widget.scheduleProvider.colorForSchedule(schedule);
    final peptideName = widget.scheduleProvider.peptideNameForSchedule(schedule);

    final now = DateTime.now();
    final diff = nextAt.difference(now);
    final String whenLabel;
    if (diff.inMinutes < 60) {
      whenLabel = 'in ${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      whenLabel = 'in ${diff.inHours}h';
    } else if (diff.inDays == 1) {
      whenLabel = 'tomorrow';
    } else {
      whenLabel = 'in ${diff.inDays}d';
    }

    final timeStr = TimeOfDay(
      hour: nextAt.hour,
      minute: nextAt.minute,
    ).format(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.alarm, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next dose',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    peptideName,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: color),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  whenLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(timeStr, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static (PeptideSchedule, DateTime)? _computeNextDose(
      List<PeptideSchedule> schedules) {
    final now = DateTime.now();
    DateTime? earliest;
    PeptideSchedule? found;

    for (final s in schedules) {
      if (!s.enabled || s.isExpired()) continue;

      if (s.frequency == ScheduleFrequency.once) {
        final sd = s.specificDate;
        if (sd == null) continue;
        final fireAt = DateTime(
          sd.year, sd.month, sd.day,
          s.timeOfDay ~/ 3600,
          (s.timeOfDay % 3600) ~/ 60,
        );
        if (fireAt.isAfter(now)) {
          if (earliest == null || fireAt.isBefore(earliest)) {
            earliest = fireAt;
            found = s;
          }
        }
      } else {
        for (int offset = 0; offset <= 7; offset++) {
          final candidate = now.add(Duration(days: offset));
          if (s.endDate != null) {
            final ed = DateTime(
                s.endDate!.year, s.endDate!.month, s.endDate!.day);
            if (DateTime(candidate.year, candidate.month, candidate.day)
                .isAfter(ed)) { continue; }
          }
          if (s.daysOfWeek.isNotEmpty &&
              !s.daysOfWeek.contains(candidate.weekday)) { continue; }
          final fireAt = DateTime(
            candidate.year, candidate.month, candidate.day,
            s.timeOfDay ~/ 3600,
            (s.timeOfDay % 3600) ~/ 60,
          );
          if (fireAt.isAfter(now)) {
            if (earliest == null || fireAt.isBefore(earliest)) {
              earliest = fireAt;
              found = s;
            }
            break;
          }
        }
      }
    }

    if (found == null || earliest == null) return null;
    return (found, earliest);
  }
}

// ─── Monthly activity grid ────────────────────────────────────────────────────

class _MonthlyDoseGrid extends StatelessWidget {
  final List<Peptide> peptides;
  final DoseHistoryProvider doseProvider;

  const _MonthlyDoseGrid({
    required this.peptides,
    required this.doseProvider,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Grid starts on the Monday of the week 4 weeks before the current Monday.
    final currentWeekMonday =
        today.subtract(Duration(days: today.weekday - 1));
    final gridStart = currentWeekMonday.subtract(const Duration(days: 28));
    // gridEnd = Sunday of current week (may be in the future)
    final gridEnd = currentWeekMonday.add(const Duration(days: 6));

    final dailyData = doseProvider.dailyMcgPerPeptide(
      rangeStart: gridStart,
      from: gridStart,
    );

    const cols = 7; // Mon–Sun
    const rows = 5; // 5 weeks
    const gap = 4.0;
    const weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Activity',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                // Date range label
                Text(
                  '${_monthLabel(gridStart)} – ${_monthLabel(gridEnd)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Weekday header
            Row(
              children: List.generate(cols, (col) {
                return Expanded(
                  child: Center(
                    child: Text(
                      weekdayLabels[col],
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 4),
            // Grid rows
            for (int row = 0; row < rows; row++) ...[
              if (row > 0) const SizedBox(height: gap),
              Row(
                children: List.generate(cols * 2 - 1, (i) {
                  if (i.isOdd) return const SizedBox(width: gap);
                  final col = i ~/ 2;
                  final dayOffset = row * 7 + col;
                  final date = gridStart.add(Duration(days: dayOffset));
                  final isFuture = date.isAfter(today);
                  final isToday = date == today;
                  final offsetIndex = date.difference(gridStart).inDays;

                  final colors = <Color>[];
                  for (int pi = 0; pi < peptides.length; pi++) {
                    final val =
                        dailyData[peptides[pi].id]?[offsetIndex] ?? 0.0;
                    if (val > 0) {
                      colors.add(resolvedColor(peptides[pi], pi));
                    }
                  }

                  return Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: _DayCell(
                        colors: colors,
                        isFuture: isFuture,
                        isToday: isToday,
                      ),
                    ),
                  );
                }),
              ),
            ],
            // Legend
            if (peptides.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: peptides.asMap().entries.map((e) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: resolvedColor(e.value, e.key),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        e.value.name,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _monthLabel(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }
}

// ─── Day cell (single square with optional split colors) ─────────────────────

class _DayCell extends StatelessWidget {
  final List<Color> colors;
  final bool isFuture;
  final bool isToday;

  const _DayCell({
    required this.colors,
    required this.isFuture,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (isFuture) {
      return const SizedBox.expand();
    }

    if (colors.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(3),
          border: isToday
              ? Border.all(color: scheme.primary, width: 1.5)
              : null,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Stack(
        children: [
          CustomPaint(
            painter: _SplitColorPainter(colors: colors),
            child: const SizedBox.expand(),
          ),
          if (isToday)
            DecoratedBox(
              decoration: BoxDecoration(
                border:
                    Border.all(color: scheme.primary, width: 1.5),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const SizedBox.expand(),
            ),
        ],
      ),
    );
  }
}

class _SplitColorPainter extends CustomPainter {
  final List<Color> colors;
  const _SplitColorPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    if (colors.isEmpty) return;
    final paint = Paint()..style = PaintingStyle.fill;
    final segH = size.height / colors.length;
    for (int i = 0; i < colors.length; i++) {
      paint.color = colors[i];
      canvas.drawRect(
        Rect.fromLTWH(0, i * segH, size.width, segH),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SplitColorPainter old) {
    if (old.colors.length != colors.length) return true;
    for (int i = 0; i < colors.length; i++) {
      if (old.colors[i] != colors[i]) return true;
    }
    return false;
  }
}

// ─── Stacked bar chart ────────────────────────────────────────────────────────

class _DoseBarChart extends StatelessWidget {
  final List<Peptide> peptides;
  final DoseHistoryProvider doseProvider;
  final DashboardTimeframe timeframe;

  const _DoseBarChart({
    required this.peptides,
    required this.doseProvider,
    required this.timeframe,
  });

  @override
  Widget build(BuildContext context) {
    final rangeStart = _effectiveRangeStart();
    final rangeEnd = DateTime.now();
    final spanDays = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day)
        .difference(
            DateTime(rangeStart.year, rangeStart.month, rangeStart.day))
        .inDays;

    final dailyData = doseProvider.dailyMcgPerPeptide(
      rangeStart: rangeStart,
      from: timeframe.filterFrom,
    );

    final hasAnyData = dailyData.values.any((m) => m.isNotEmpty);
    if (!hasAnyData) {
      return _ChartPlaceholder(
          message: 'No doses recorded in this timeframe');
    }

    double maxY = 0;
    final barGroups = <BarChartGroupData>[];

    for (int dayOffset = 0; dayOffset <= spanDays; dayOffset++) {
      final stackItems = <BarChartRodStackItem>[];
      double cumulative = 0;

      for (int i = 0; i < peptides.length; i++) {
        final value = dailyData[peptides[i].id]?[dayOffset] ?? 0.0;
        if (value > 0) {
          stackItems.add(BarChartRodStackItem(
              cumulative, cumulative + value, resolvedColor(peptides[i], i)));
          cumulative += value;
        }
      }

      if (cumulative > maxY) maxY = cumulative;

      barGroups.add(BarChartGroupData(
        x: dayOffset,
        barRods: [
          BarChartRodData(
            toY: cumulative,
            width: _barWidth(spanDays),
            rodStackItems: stackItems.isEmpty
                ? [BarChartRodStackItem(0, 0, Colors.transparent)]
                : stackItems,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(3)),
            color: Colors.transparent,
          ),
        ],
      ));
    }

    final textStyle = TextStyle(
      fontSize: 10,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final labelEvery = timeframe.labelInterval.toInt().clamp(1, 999);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          child: Padding(
            padding: const EdgeInsets.only(right: 12, top: 8),
            child: BarChart(
              BarChartData(
                maxY: maxY * 1.25,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.2),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      interval: maxY > 0 ? maxY / 4 : 1,
                      getTitlesWidget: (value, meta) {
                        if (value == 0 || value == meta.max) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          value >= 1000
                              ? '${(value / 1000).toStringAsFixed(1)}k'
                              : value.toStringAsFixed(0),
                          style: textStyle,
                          textAlign: TextAlign.right,
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final intVal = value.toInt();
                        if (intVal % labelEvery != 0) {
                          return const SizedBox.shrink();
                        }
                        final date =
                            rangeStart.add(Duration(days: intVal));
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${date.month}/${date.day}',
                            style: textStyle,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: barGroups,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    tooltipPadding: const EdgeInsets.all(8),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      if (rod.toY == 0) return null;
                      final date =
                          rangeStart.add(Duration(days: group.x));
                      final buf =
                          StringBuffer('${date.month}/${date.day}\n');
                      for (int i = 0; i < peptides.length; i++) {
                        final val =
                            dailyData[peptides[i].id]?[group.x] ?? 0.0;
                        if (val > 0) {
                          buf.write(
                              '${peptides[i].name}: ${val.toStringAsFixed(1)} mcg\n');
                        }
                      }
                      return BarTooltipItem(
                        buf.toString().trimRight(),
                        TextStyle(
                          color:
                              Theme.of(context).colorScheme.onSurface,
                          fontSize: 11,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: peptides.asMap().entries.where((e) {
            return dailyData[e.value.id]?.isNotEmpty ?? false;
          }).map((e) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: resolvedColor(e.value, e.key),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  e.value.name,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  double _barWidth(int spanDays) {
    if (spanDays <= 7) return 26.0;
    if (spanDays <= 14) return 18.0;
    if (spanDays <= 30) return 10.0;
    return 6.0;
  }

  DateTime _effectiveRangeStart() {
    if (timeframe.days > 0) return timeframe.rangeStart;
    final allDoses = doseProvider.doses;
    if (allDoses.isEmpty) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 29));
    }
    final oldest = allDoses.last.takenAt;
    return DateTime(oldest.year, oldest.month, oldest.day);
  }
}

// ─── Shared small widgets ─────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 10),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            if (subtitle != null)
              Text(
                subtitle!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}

class _PeptideSummaryCard extends StatelessWidget {
  final String peptideId;
  final String name;
  final int doseCount;
  final double totalMcg;
  final Color color;

  const _PeptideSummaryCard({
    required this.peptideId,
    required this.name,
    required this.doseCount,
    required this.totalMcg,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PeptideDetailScreen(peptideId: peptideId),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: Theme.of(context).textTheme.titleSmall),
                    Text(
                      '$doseCount dose${doseCount == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                '${totalMcg.toStringAsFixed(1)} mcg',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartPlaceholder extends StatelessWidget {
  final String message;
  const _ChartPlaceholder({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        border: Border.all(
          color:
              Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart, size: 40, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
          ],
        ),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
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
      ),
    );
  }
}

// ─── Weight summary card ──────────────────────────────────────────────────────

class _WeightSummaryCard extends StatelessWidget {
  const _WeightSummaryCard();

  @override
  Widget build(BuildContext context) {
    return Consumer<WeightProvider>(
      builder: (context, wp, _) {
        final latest = wp.latest;
        final trend = wp.trendLbs;
        final scheme = Theme.of(context).colorScheme;

        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const WeightHistoryScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.monitor_weight,
                        color: Colors.teal, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Weight',
                            style:
                                Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: 2),
                        Text(
                          latest == null
                              ? 'Not tracked yet'
                              : '${latest.weightLbs.toStringAsFixed(1)} lbs',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (latest != null)
                          Text(
                            _relativeDate(latest.recordedAt),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: scheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  if (trend != null) _MiniTrend(deltaLbs: trend),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _relativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }
}

class _MiniTrend extends StatelessWidget {
  final double deltaLbs;
  const _MiniTrend({required this.deltaLbs});

  @override
  Widget build(BuildContext context) {
    final isFlat = deltaLbs.abs() < 0.05;
    final isLoss = deltaLbs < 0;
    final color = isFlat
        ? Theme.of(context).colorScheme.onSurfaceVariant
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            '$sign${deltaLbs.toStringAsFixed(1)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
