import 'package:event_hive/core/theme/admin/admin_theme.dart';
import 'package:event_hive/widgets/admin/admin_widgets.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin analytics: how EventHive is doing.
/// Everything comes from one call, admin_analytics(range) (schema 4.28).
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _supabase = Supabase.instance.client;

  static const _rangeLabels = {
    '7d': '7 days',
    '30d': '30 days',
    '12m': '12 months',
  };
  static const _metricLabels = {
    'registrations': 'Registrations',
    'users': 'New users',
    'events': 'Events',
  };

  String _range = '7d';
  String _metric = 'registrations';
  Map<String, dynamic>? _data;
  bool _loading = true; // first load only
  bool _refreshing = false; // range switched, old data still shown
  bool _failed = false;
  int? _selected; // point touched on the chart

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final asked = _range;
    setState(() => _refreshing = true);
    try {
      final res = await _supabase.rpc(
        'admin_analytics',
        params: {'p_range': asked},
      );
      if (!mounted || asked != _range) return; // a newer choice took over
      setState(() {
        _data = Map<String, dynamic>.from(res as Map);
        _loading = false;
        _failed = false;
        _refreshing = false;
        _selected = null;
      });
    } catch (e) {
      debugPrint('Analytics load error: $e');
      if (!mounted || asked != _range) return;
      setState(() {
        _refreshing = false;
        _loading = false;
        if (_data == null) _failed = true;
      });
      if (_data != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(adminError(e))));
      }
    }
  }

  int _n(dynamic v) => (v as num?)?.toInt() ?? 0;

  String _fmt(int n) => n.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );

  /// "2026-11-12" -> "12 Nov" (days) or "Nov" (months); long form adds the year.
  String _pointLabel(String t, String unit, {bool short = true}) {
    final d = DateTime.tryParse(t);
    if (d == null) return t;
    final p = adminDate(d).split(' '); // [12, Nov, 2026]
    if (unit == 'month') return short ? p[1] : '${p[1]} ${p[2]}';
    return short ? '${p[0]} ${p[1]}' : '${p[0]} ${p[1]} ${p[2]}';
  }

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
            : _failed || _data == null
            ? AdminMessage(
                icon: Icons.cloud_off_outlined,
                text: 'Could not load analytics.',
                actionLabel: 'Retry',
                onAction: () {
                  setState(() => _loading = true);
                  _load();
                },
              )
            : _content(),
      ),
    );
  }

  Widget _content() {
    final c = AdminColors.of(context);
    final t = Theme.of(context).textTheme;
    final d = _data!;
    final totals = Map<String, dynamic>.from(d['totals'] as Map);
    final period = Map<String, dynamic>.from(d['period'] as Map);
    final unit = '${d['unit']}';
    final series = List<Map<String, dynamic>>.from(
      ((d['series'] as Map)[_metric] as List).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    final values = series.map((p) => _n(p['n'])).toList();
    final total = values.fold<int>(0, (a, b) => a + b);
    final sel = (_selected != null && _selected! < series.length)
        ? _selected
        : null;
    final shortRange = _range;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Text(
            'Analytics',
            style: t.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              color: c.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'How EventHive is doing.',
            style: t.bodyMedium?.copyWith(color: c.muted),
          ),
          const SizedBox(height: 20),

          _Segmented(
            options: _rangeLabels,
            value: _range,
            onChanged: (v) {
              if (v == _range) return;
              setState(() {
                _range = v;
                _selected = null;
              });
              _load();
            },
          ),
          SizedBox(
            height: 3,
            child: _refreshing
                ? const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: LinearProgressIndicator(minHeight: 2),
                  )
                : null,
          ),
          const SizedBox(height: 12),

          // ── Totals
          Row(
            children: [
              Expanded(
                child: _Kpi(
                  label: 'Events',
                  value: _fmt(_n(totals['events'])),
                  delta: _n(period['events']),
                  range: shortRange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Kpi(
                  label: 'Organizers',
                  value: _fmt(_n(totals['organizers'])),
                  delta: _n(period['organizers']),
                  range: shortRange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Kpi(
                  label: 'Registered',
                  value: _fmt(_n(totals['registrations'])),
                  delta: _n(period['registrations']),
                  range: shortRange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Growth chart
          AdminCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Segmented(
                  options: _metricLabels,
                  value: _metric,
                  compact: true,
                  onChanged: (v) => setState(() {
                    _metric = v;
                    _selected = null;
                  }),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _fmt(total),
                      style: AdminTheme.numeral(c.ink, size: 30),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        'in ${_rangeLabels[_range]}',
                        style: t.bodySmall?.copyWith(color: c.muted),
                      ),
                    ),
                    const Spacer(),
                    if (sel != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '${_pointLabel('${series[sel]['t']}', unit, short: false)}'
                          '  ·  ${values[sel]}',
                          style: t.bodySmall?.copyWith(
                            color: c.brand,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _LineChart(
                  values: values,
                  xLabels: [
                    for (final p in series) _pointLabel('${p['t']}', unit),
                  ],
                  selected: sel,
                  onSelect: (i) => setState(() => _selected = i),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Funnel
          _funnelCard(Map<String, dynamic>.from(d['funnel'] as Map)),
          const SizedBox(height: 16),

          // ── Fullest upcoming events
          _fillCard(
            List<Map<String, dynamic>>.from(
              (d['fill'] as List).map(
                (e) => Map<String, dynamic>.from(e as Map),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Categories
          _categoriesCard(
            List<Map<String, dynamic>>.from(
              (d['categories'] as List).map(
                (e) => Map<String, dynamic>.from(e as Map),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── cards ─────────────────────────

  Color _success() => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF6FCF97)
      : const Color(0xFF1E7A4C);

  Widget _funnelCard(Map<String, dynamic> f) {
    final c = AdminColors.of(context);
    final registered = _n(f['registered']);
    final confirmed = _n(f['confirmed']);
    final pending = _n(f['pending']);
    final lost = _n(f['lost']);
    final rate = registered == 0 ? 0 : (confirmed * 100 / registered).round();

    return _Section(
      title: 'Registration funnel',
      subtitle:
          'What happened to the registrations made in the last '
          '${_rangeLabels[_range]}',
      child: registered == 0
          ? const _Empty('No registrations in this period.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BarRow(
                  label: 'Registered',
                  value: registered,
                  max: registered,
                  color: c.brand,
                ),
                _BarRow(
                  label: 'Confirmed',
                  value: confirmed,
                  max: registered,
                  color: _success(),
                  percent: true,
                ),
                _BarRow(
                  label: 'Awaiting payment',
                  value: pending,
                  max: registered,
                  color: c.accent,
                  percent: true,
                ),
                _BarRow(
                  label: 'Cancelled or expired',
                  value: lost,
                  max: registered,
                  color: Theme.of(context).colorScheme.error,
                  percent: true,
                  last: true,
                ),
                const SizedBox(height: 4),
                Text(
                  '$rate% of registrations ended up confirmed.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: c.muted),
                ),
              ],
            ),
    );
  }

  Widget _fillCard(List<Map<String, dynamic>> rows) {
    final c = AdminColors.of(context);
    return _Section(
      title: 'Fullest upcoming events',
      subtitle: 'Seats taken against capacity',
      child: rows.isEmpty
          ? const _Empty('No upcoming events.')
          : Column(
              children: [
                for (var i = 0; i < rows.length; i++)
                  _BarRow(
                    label: '${rows[i]['name']}',
                    value: _n(rows[i]['registered']),
                    max: _n(rows[i]['capacity']),
                    trailing:
                        '${_n(rows[i]['registered'])} / ${_n(rows[i]['capacity'])}',
                    color: _n(rows[i]['registered']) >= _n(rows[i]['capacity'])
                        ? c.accent
                        : c.brand,
                    last: i == rows.length - 1,
                    onTap: () =>
                        context.push('/admin/events/${rows[i]['event_id']}'),
                  ),
              ],
            ),
    );
  }

  Widget _categoriesCard(List<Map<String, dynamic>> rows) {
    final c = AdminColors.of(context);
    final top = rows.isEmpty ? 0 : _n(rows.first['n']);
    return _Section(
      title: 'Popular categories',
      subtitle:
          'Registrations by event category in the last '
          '${_rangeLabels[_range]}',
      child: rows.isEmpty
          ? const _Empty('No registrations in this period.')
          : Column(
              children: [
                for (var i = 0; i < rows.length; i++)
                  _BarRow(
                    label: '${rows[i]['name']}',
                    value: _n(rows[i]['n']),
                    max: top,
                    color: c.brand,
                    last: i == rows.length - 1,
                  ),
              ],
            ),
    );
  }
}

// ═════════════════════════ pieces ═════════════════════════

/// Equal-width segmented control (range and metric pickers).
class _Segmented extends StatelessWidget {
  final Map<String, String> options;
  final String value;
  final ValueChanged<String> onChanged;
  final bool compact;
  const _Segmented({
    required this.options,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: compact ? c.bg : c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          for (final e in options.entries)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: EdgeInsets.symmetric(vertical: compact ? 8 : 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == e.key ? c.brandSoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      e.value,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: value == e.key ? c.brand : c.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final int delta;
  final String range;
  const _Kpi({
    required this.label,
    required this.value,
    required this.delta,
    required this.range,
  });

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    final t = Theme.of(context).textTheme;
    final good = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF6FCF97)
        : const Color(0xFF1E7A4C);
    return AdminCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.bodySmall?.copyWith(color: c.muted)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AdminTheme.numeral(c.ink, size: 26)),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '+$delta in $range',
              style: t.labelSmall?.copyWith(
                color: delta > 0 ? good : c.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _Section({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    final t = Theme.of(context).textTheme;
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: t.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: c.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: t.bodySmall?.copyWith(color: c.muted)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: c.muted),
      ),
    );
  }
}

/// Label, value and a proportional bar. Used by all three lists.
class _BarRow extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final Color color;
  final bool percent; // show "· 62%" of max next to the count
  final String? trailing; // overrides the count text
  final bool last;
  final VoidCallback? onTap;
  const _BarRow({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    this.percent = false,
    this.trailing,
    this.last = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    final t = Theme.of(context).textTheme;
    final ratio = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0).toDouble();
    final pct = max <= 0 ? 0 : (value * 100 / max).round();
    final right = trailing ?? (percent ? '$value  ·  $pct%' : '$value');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyMedium,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  right,
                  style: t.bodyMedium?.copyWith(
                    color: c.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: c.border,
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════ line chart ═════════════════════════

class _LineChart extends StatelessWidget {
  final List<int> values;
  final List<String> xLabels;
  final int? selected;
  final ValueChanged<int?> onSelect;
  const _LineChart({
    required this.values,
    required this.xLabels,
    required this.selected,
    required this.onSelect,
  });

  static const _height = 210.0;

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    return SizedBox(
      height: _height,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          void pick(double dx) {
            if (values.isEmpty) return;
            if (values.length == 1) {
              onSelect(0);
              return;
            }
            final plotW = w - _LinePainter.left - _LinePainter.right;
            final i = ((dx - _LinePainter.left) / plotW * (values.length - 1))
                .round()
                .clamp(0, values.length - 1)
                .toInt();
            onSelect(i);
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => pick(d.localPosition.dx),
            onHorizontalDragUpdate: (d) => pick(d.localPosition.dx),
            child: CustomPaint(
              size: Size(w, _height),
              painter: _LinePainter(
                values: values,
                xLabels: xLabels,
                selected: selected,
                line: c.brand,
                grid: c.border,
                muted: c.muted,
                surface: c.surface,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  static const left = 34.0;
  static const right = 8.0;
  static const top = 10.0;
  static const bottom = 24.0;

  final List<int> values;
  final List<String> xLabels;
  final int? selected;
  final Color line;
  final Color grid;
  final Color muted;
  final Color surface;

  const _LinePainter({
    required this.values,
    required this.xLabels,
    required this.selected,
    required this.line,
    required this.grid,
    required this.muted,
    required this.surface,
  });

  /// Top of the y axis: an even number, so the middle gridline is whole.
  static int _niceMax(int m) {
    if (m <= 4) return 4;
    if (m <= 10) return m.isOdd ? m + 1 : m;
    var mag = 1;
    while (mag * 10 <= m) {
      mag *= 10;
    }
    return ((m + mag - 1) ~/ mag) * mag;
  }

  static String _short(int v) => v >= 1000
      ? '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k'
      : '$v';

  /// Draws text anchored at [at]; fx / fy are how much of the text's width /
  /// height to shift left / up (1, 0.5 or 0).
  void _text(
    Canvas canvas,
    String s,
    Offset at, {
    double fx = 0,
    double fy = 0,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(color: muted, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(at.dx - tp.width * fx, at.dy - tp.height * fy));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final n = values.length;
    final maxV = n == 0 ? 0 : values.reduce((a, b) => a > b ? a : b);
    final yMax = _niceMax(maxV);

    // gridlines and y labels: 0, half, top
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = plot.bottom - plot.height * i / 2;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      _text(
        canvas,
        _short(yMax * i ~/ 2),
        Offset(plot.left - 6, y),
        fx: 1,
        fy: 0.5,
      );
    }
    if (n == 0) return;

    Offset pt(int i) {
      final x = n == 1 ? plot.center.dx : plot.left + plot.width * i / (n - 1);
      final y = plot.bottom - plot.height * values[i] / yMax;
      return Offset(x, y);
    }

    // x labels: first, middle, last
    final ticks = <int>{0, (n - 1) ~/ 2, n - 1}.toList()..sort();
    for (final i in ticks) {
      final fx = i == 0 ? 0.0 : (i == n - 1 ? 1.0 : 0.5);
      _text(canvas, xLabels[i], Offset(pt(i).dx, plot.bottom + 6), fx: fx);
    }

    // area under the line
    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < n; i++) {
      path.lineTo(pt(i).dx, pt(i).dy);
    }
    if (n > 1) {
      final area = Path.from(path)
        ..lineTo(pt(n - 1).dx, plot.bottom)
        ..lineTo(pt(0).dx, plot.bottom)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [line.withValues(alpha: 0.22), line.withValues(alpha: 0)],
          ).createShader(plot),
      );
    }

    // the line
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // selected point
    final s = selected;
    if (s != null && s < n) {
      final p = pt(s);
      canvas.drawLine(
        Offset(p.dx, plot.top),
        Offset(p.dx, plot.bottom),
        Paint()
          ..color = line.withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(p, 7, Paint()..color = surface);
      canvas.drawCircle(p, 4.5, Paint()..color = line);
    } else if (n == 1) {
      canvas.drawCircle(pt(0), 4, Paint()..color = line);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.values != values ||
      old.selected != selected ||
      old.line != line ||
      old.grid != grid ||
      old.muted != muted ||
      old.surface != surface ||
      old.xLabels != xLabels;
}
