import 'package:event_hive/core/theme/admin/admin_theme.dart';
import 'package:event_hive/widgets/admin/admin_widgets.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Event oversight: every event, split into Upcoming / Past / Cancelled.
/// Tapping an event opens /admin/events/:eventId.
class EventOversightScreen extends StatefulWidget {
  const EventOversightScreen({super.key});

  @override
  State<EventOversightScreen> createState() => _EventOversightScreenState();
}

class _EventOversightScreenState extends State<EventOversightScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  bool _failed = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // event_overview already carries categories and the exact seat count.
      final rows = await _supabase
          .from('event_overview')
          .select(
            'event_id, name, event_date, start_time, venue, capacity, status, '
            'categories, registered_count, hosting_org',
          );
      if (!mounted) return;
      setState(() {
        _events = List<Map<String, dynamic>>.from(rows);
        _loading = false;
        _failed = false;
      });
    } catch (e) {
      debugPrint('Event oversight load error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  bool _matches(Map<String, dynamic> e) {
    if (_query.isEmpty) return true;
    final cats = ((e['categories'] as List?) ?? []).join(' ');
    final hay = '${e['name']} ${e['venue']} ${e['hosting_org']} $cats'
        .toLowerCase();
    return hay.contains(_query);
  }

  int _byDate(Map<String, dynamic> a, Map<String, dynamic> b) {
    final d = '${a['event_date']}'.compareTo('${b['event_date']}');
    return d != 0 ? d : '${a['start_time']}'.compareTo('${b['start_time']}');
  }

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    final shown = _events.where(_matches).toList();
    final upcoming =
        shown
            .where(
              (e) =>
                  e['status'] == 'active' &&
                  '${e['event_date']}'.compareTo(today) >= 0,
            )
            .toList()
          ..sort(_byDate);
    final past =
        shown
            .where(
              (e) =>
                  e['status'] == 'active' &&
                  '${e['event_date']}'.compareTo(today) < 0,
            )
            .toList()
          ..sort((a, b) => _byDate(b, a));
    final cancelled = shown.where((e) => e['status'] == 'cancelled').toList()
      ..sort((a, b) => _byDate(b, a));

    String label(String name, List list) =>
        _loading ? name : '$name (${list.length})';

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              const AdminHeader(
                title: 'Event oversight',
                subtitle: 'Monitor events and their registrations',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: AdminSearchField(
                  hint: 'Search by name, venue or tag',
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                ),
              ),
              AdminTabBar(
                labels: [
                  label('Upcoming', upcoming),
                  label('Past', past),
                  label('Cancelled', cancelled),
                ],
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : _failed
                    ? AdminMessage(
                        icon: Icons.cloud_off_outlined,
                        text: 'Could not load events.',
                        actionLabel: 'Retry',
                        onAction: () {
                          setState(() => _loading = true);
                          _load();
                        },
                      )
                    : TabBarView(
                        children: [
                          _list(upcoming, 'No upcoming events.'),
                          _list(past, 'No past events.'),
                          _list(cancelled, 'No cancelled events.'),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(List<Map<String, dynamic>> items, String empty) {
    return AdminRefreshList(
      onRefresh: _load,
      itemCount: items.length,
      emptyText: empty,
      emptyIcon: Icons.event_busy_outlined,
      itemBuilder: (_, i) => _EventCard(event: items[i]),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    final t = Theme.of(context).textTheme;

    final date = DateTime.tryParse('${event['event_date'] ?? ''}');
    final time = adminTime(event['start_time']?.toString());
    final venue = (event['venue'] ?? '').toString();
    final cap = (event['capacity'] as num?)?.toInt() ?? 0;
    final reg = (event['registered_count'] as num?)?.toInt() ?? 0;
    final ratio = cap <= 0 ? 0.0 : (reg / cap).clamp(0.0, 1.0).toDouble();
    final full = cap > 0 && reg >= cap;
    final cancelled = event['status'] == 'cancelled';
    final cats = ((event['categories'] as List?) ?? [])
        .map((x) => x.toString())
        .toList();

    return AdminCard(
      onTap: () => context.push('/admin/events/${event['event_id']}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date block
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: c.brandSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  date == null ? '–' : '${date.day}',
                  style: AdminTheme.numeral(c.brand, size: 22),
                ),
                const SizedBox(height: 4),
                Text(
                  date == null ? '' : adminMonth(date),
                  style: t.labelSmall?.copyWith(
                    color: c.brand,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (event['name'] ?? 'Untitled').toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (time.isNotEmpty) time,
                    if (venue.isNotEmpty) venue,
                  ].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySmall?.copyWith(color: c.muted),
                ),
                if (cancelled || cats.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (cancelled)
                        const AdminPill(
                          label: 'Cancelled',
                          tone: AdminTone.danger,
                        ),
                      for (final cat in cats.take(2)) AdminPill(label: cat),
                      if (cats.length > 2)
                        AdminPill(label: '+${cats.length - 2}'),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 4,
                        backgroundColor: c.border,
                        color: full ? c.accent : c.brand,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      cap > 0 ? '$reg / $cap' : '$reg',
                      style: t.labelMedium?.copyWith(
                        color: c.muted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: c.muted),
        ],
      ),
    );
  }
}
