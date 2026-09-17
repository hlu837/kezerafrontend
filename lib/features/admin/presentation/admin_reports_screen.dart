import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// GET /admin/reports?days= — growth, conversion, and payment analytics
/// over a trailing window. Returns the raw response `data` object as-is
/// (range/growth/funnel/payments) rather than a parsed model — this
/// screen is the only reader, so there's no reuse benefit to a
/// dedicated class, mirroring admin_placements_screen.dart's
/// `Map<String, dynamic>` convention.
final _reportsProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, days) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.dio.get<Map<String, dynamic>>(
    '/admin/reports',
    queryParameters: {'days': days},
  );
  return response.data!['data'] as Map<String, dynamic>;
});

String _birr(num amount) => '${amount.toStringAsFixed(0)} ETB';

String _pct(num rate) => '${(rate * 100).toStringAsFixed(0)}%';

String _shortDate(String iso) {
  try {
    final d = DateTime.parse(iso);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  } catch (_) {
    return iso;
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Content pane for the `/admin/reports` sidebar destination —
/// platform-wide growth, conversion, and payment analytics over a
/// trailing window. Read-only, same dark container/card styling as the
/// rest of this admin section.
class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  int _days = 30;
  String _growthMetric = 'newUsers';

  static const _rangeOptions = [7, 30, 90];
  static const _growthMetrics = {
    'newUsers': 'New Users',
    'newJobs': 'New Jobs',
    'newPlacements': 'New Placements',
    'newApplications': 'New Applications',
  };

  @override
  Widget build(BuildContext context) {
    final asyncReport = ref.watch(_reportsProvider(_days));

    return Container(
      color: const Color(0xFF0F0F1A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFF1A1A2E),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Reports',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white54),
                      tooltip: 'Refresh',
                      onPressed: () => ref.invalidate(_reportsProvider(_days)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Growth, conversion, and payment analytics over the selected period.',
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: _rangeOptions.map((d) {
                    final selected = d == _days;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('${d}d'),
                        selected: selected,
                        onSelected: (_) => setState(() => _days = d),
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        backgroundColor: const Color(0xFF0F0F1A),
                        selectedColor: const Color(0xFF7B8CDE),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide.none,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          Expanded(
            child: asyncReport.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF7B8CDE))),
              error: (err, _) => Center(
                child: Text(err.toString(), style: const TextStyle(color: Colors.red)),
              ),
              data: (report) {
                final growth = report['growth'] as Map<String, dynamic>;
                final funnel = report['funnel'] as Map<String, dynamic>;
                final payments = report['payments'] as Map<String, dynamic>;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _StatCard(
                            label: 'Revenue',
                            value: _birr((payments['totalRevenue'] as num?) ?? 0),
                            icon: Icons.payments_outlined,
                          ),
                          _StatCard(
                            label: 'Refunded',
                            value: _birr((payments['totalRefunded'] as num?) ?? 0),
                            icon: Icons.undo_outlined,
                          ),
                          _StatCard(
                            label: 'Jobs Posted',
                            value: '${funnel['jobsPosted']}',
                            icon: Icons.work_outline,
                          ),
                          _StatCard(
                            label: 'Applications',
                            value: '${funnel['totalApplications']}',
                            icon: Icons.description_outlined,
                          ),
                          _StatCard(
                            label: 'Placements',
                            value: '${funnel['totalPlacements']}',
                            icon: Icons.handshake_outlined,
                          ),
                          _StatCard(
                            label: 'Hires',
                            value: '${funnel['hiredPlacements']}',
                            icon: Icons.emoji_events_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      _SectionHeader('Conversion Funnel'),
                      const SizedBox(height: 12),
                      _FunnelCard(funnel: funnel),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(child: _SectionHeader('Growth')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 32,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _growthMetrics.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final key = _growthMetrics.keys.elementAt(i);
                            final selected = key == _growthMetric;
                            return ChoiceChip(
                              label: Text(_growthMetrics[key]!),
                              selected: selected,
                              onSelected: (_) => setState(() => _growthMetric = key),
                              labelStyle: TextStyle(
                                color: selected ? Colors.white : Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              backgroundColor: const Color(0xFF1A1A2E),
                              selectedColor: const Color(0xFF7B8CDE),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide.none,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(14)),
                        child: _DailySeriesChart(
                          series: List<Map<String, dynamic>>.from(growth[_growthMetric] as List<dynamic>),
                          color: const Color(0xFF7B8CDE),
                          valueKey: 'count',
                        ),
                      ),
                      const SizedBox(height: 28),
                      _SectionHeader('Revenue'),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(14)),
                        child: _DailySeriesChart(
                          series: List<Map<String, dynamic>>.from(payments['daily'] as List<dynamic>),
                          color: const Color(0xFF81C784),
                          valueKey: 'amount',
                          valueFormatter: (v) => _birr(v),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _BreakdownCard(
                              title: 'By Product',
                              rows: List<Map<String, dynamic>>.from(payments['byProduct'] as List<dynamic>),
                              nameKey: 'product',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _BreakdownCard(
                              title: 'By Plan',
                              rows: List<Map<String, dynamic>>.from(payments['byPlan'] as List<dynamic>),
                              nameKey: 'plan',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF7B8CDE), size: 20),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
        ],
      ),
    );
  }
}

/// Jobs Posted -> Applications -> Placements -> Hired, each stage's bar
/// width proportional to the largest count among the four (not a strict
/// numeric funnel — applications can outnumber jobs posted — so this is
/// about relative scale, not a shrinking-width visual metaphor).
class _FunnelCard extends StatelessWidget {
  const _FunnelCard({required this.funnel});
  final Map<String, dynamic> funnel;

  @override
  Widget build(BuildContext context) {
    final jobsPosted = (funnel['jobsPosted'] as num).toInt();
    final totalApplications = (funnel['totalApplications'] as num).toInt();
    final totalPlacements = (funnel['totalPlacements'] as num).toInt();
    final hiredPlacements = (funnel['hiredPlacements'] as num).toInt();
    final applicationToShortlistRate = (funnel['applicationToShortlistRate'] as num).toDouble();
    final placementToHiredRate = (funnel['placementToHiredRate'] as num).toDouble();

    final stages = [
      (label: 'Jobs Posted', count: jobsPosted, subtitle: null as String?),
      (
        label: 'Applications',
        count: totalApplications,
        subtitle: 'Shortlisted: ${_pct(applicationToShortlistRate)}',
      ),
      (label: 'Placements', count: totalPlacements, subtitle: null as String?),
      (
        label: 'Hired',
        count: hiredPlacements,
        subtitle: 'Placement → Hire: ${_pct(placementToHiredRate)}',
      ),
    ];
    final maxCount = stages.map((s) => s.count).fold<int>(1, (a, b) => a > b ? a : b);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: stages.map((s) {
          final fraction = maxCount == 0 ? 0.0 : s.count / maxCount;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(s.label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('${s.count}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Container(
                      height: 8,
                      width: constraints.maxWidth,
                      decoration: BoxDecoration(color: const Color(0xFF0F0F1A), borderRadius: BorderRadius.circular(4)),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          height: 8,
                          width: constraints.maxWidth * fraction.clamp(0.02, 1.0),
                          decoration: BoxDecoration(color: const Color(0xFF7B8CDE), borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                    );
                  },
                ),
                if (s.subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(s.subtitle!, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// A simple horizontally-scrollable bar chart for a `{date, count}` or
/// `{date, amount}` daily series — no charting package dependency, since
/// this app doesn't otherwise pull one in (see pubspec.yaml).
class _DailySeriesChart extends StatelessWidget {
  const _DailySeriesChart({
    required this.series,
    required this.color,
    required this.valueKey,
    this.valueFormatter,
  });

  final List<Map<String, dynamic>> series;
  final Color color;
  final String valueKey;
  final String Function(num)? valueFormatter;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text('No data for this period', style: TextStyle(color: Colors.white.withOpacity(0.3))),
        ),
      );
    }

    final values = series.map((e) => (e[valueKey] as num).toDouble()).toList();
    final maxVal = values.fold<double>(0, (a, b) => a > b ? a : b);
    final total = values.fold<double>(0, (a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Total: ${valueFormatter != null ? valueFormatter!(total) : total.toStringAsFixed(0)}',
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: maxVal <= 0
              ? Center(
                  child: Text('No activity in this period', style: TextStyle(color: Colors.white.withOpacity(0.3))),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(series.length, (i) {
                      final v = values[i];
                      final barHeight = maxVal == 0 ? 0.0 : (v / maxVal) * 96;
                      final date = series[i]['date'] as String;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Tooltip(
                          message: '${_shortDate(date)}: ${valueFormatter != null ? valueFormatter!(v) : v.toStringAsFixed(0)}',
                          child: Container(
                            width: 8,
                            height: v > 0 && barHeight < 3 ? 3 : barHeight,
                            decoration: BoxDecoration(
                              color: color.withOpacity(v > 0 ? 1.0 : 0.15),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_shortDate(series.first['date'] as String), style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
            Text(_shortDate(series.last['date'] as String), style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
          ],
        ),
      ],
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.title, required this.rows, required this.nameKey});

  final String title;
  final List<Map<String, dynamic>> rows;
  final String nameKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Text('No revenue in this period', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12))
          else
            ...rows.map((r) {
              final name = (r[nameKey] as String?) ?? 'Unknown';
              final amount = (r['amount'] as num?) ?? 0;
              final count = (r['count'] as num?) ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${_birr(amount)} · $count',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
