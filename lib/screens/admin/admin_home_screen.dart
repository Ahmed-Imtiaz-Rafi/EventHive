import 'package:event_hive/core/theme/admin/admin_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin dashboard: the first screen an admin sees.
/// Three entry points (events, organizers, users), each with a live figure.
/// Needs supabase_flutter 2.x (uses .count(CountOption.exact)).
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final _supabase = Supabase.instance.client;

  int? _activeEvents;
  int? _organizers;
  int? _users;
  int? _pendingRequests;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// One round trip per figure, run in parallel. The admin RLS policies
  /// already allow reading all four tables.
  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final r = await Future.wait([
        _supabase
            .from('events')
            .select('event_id')
            .eq('status', 'active')
            .gte('event_date', today)
            .count(CountOption.exact),
        _supabase
            .from('user_role')
            .select('user_id')
            .eq('role', 'organizer')
            .count(CountOption.exact),
        _supabase.from('users').select('user_id').count(CountOption.exact),
        _supabase
            .from('organizer_requests')
            .select('user_id')
            .eq('status', 'pending')
            .count(CountOption.exact),
      ]);
      if (!mounted) return;
      setState(() {
        _activeEvents = r[0].count;
        _organizers = r[1].count;
        _users = r[2].count;
        _pendingRequests = r[3].count;
      });
    } catch (e) {
      debugPrint('Admin dashboard load error: $e');
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  /// 1204 -> "1,204"; null (still loading) -> an en dash.
  String _fmt(int? n) {
    if (n == null) return '–';
    return n.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
  }

  void _onBell() {
    // Admin notifications are not built yet. Until they are, the bell opens
    // the one thing that needs attention: pending organizer requests.
    if ((_pendingRequests ?? 0) > 0) {
      context.push('/admin/organizer-requests');
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('No new notifications')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final pending = _pendingRequests ?? 0;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              // ── Top bar
              Row(
                children: [
                  Text(
                    'EVENTHIVE',
                    style: t.labelMedium?.copyWith(
                      color: c.brand,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: dark
                        ? 'Switch to light mode'
                        : 'Switch to dark mode',
                    onPressed: () => adminDarkMode.value = !adminDarkMode.value,
                    icon: Icon(
                      dark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                      color: c.muted,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Notifications',
                    onPressed: _onBell,
                    icon: Badge(
                      isLabelVisible: pending > 0,
                      smallSize: 8,
                      backgroundColor: c.accent,
                      child: Icon(
                        Icons.notifications_none_rounded,
                        color: c.muted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Heading
              Text(
                'Dashboard',
                style: t.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Overseeing events, organizers and users.',
                style: t.bodyMedium?.copyWith(color: c.muted),
              ),
              const SizedBox(height: 24),

              if (_failed) ...[
                _ErrorBanner(onRetry: _load),
                const SizedBox(height: 14),
              ],

              // ── Oversight entries
              _OversightCard(
                icon: Icons.event_note_outlined,
                title: 'Event oversight',
                subtitle: 'Upcoming, past and cancelled events',
                value: _fmt(_activeEvents),
                unit: 'active',
                onTap: () => context.push('/admin/events'),
              ),
              const SizedBox(height: 14),
              _OversightCard(
                icon: Icons.groups_outlined,
                title: 'Organizer oversight',
                subtitle: 'Review requests and manage organizers',
                value: _fmt(_organizers),
                unit: 'organizers',
                flag: pending > 0 ? '$pending pending' : null,
                onTap: () => context.push('/admin/organizer-requests'),
              ),
              const SizedBox(height: 14),
              _OversightCard(
                icon: Icons.people_alt_outlined,
                title: 'User oversight',
                subtitle: 'Participants, organizers and admins',
                value: _fmt(_users),
                unit: 'total users',
                onTap: () => context.push('/admin/users'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One tappable dashboard entry. Material + InkWell (not a ListTile inside a
/// decorated Container), so the tap ripple is visible and clipped to the card.
class _OversightCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final String unit;
  final String? flag; // attention pill, e.g. "3 pending"
  final VoidCallback onTap;

  const _OversightCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.unit,
    required this.onTap,
    this.flag,
  });

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    final t = Theme.of(context).textTheme;

    return Material(
      color: c.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c.brandSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: c.brand, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: t.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: c.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: t.bodySmall?.copyWith(color: c.muted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: c.muted),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: c.border, height: 1),
              const SizedBox(height: 14),
              Row(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(value, style: AdminTheme.numeral(c.ink)),
                      const SizedBox(width: 8),
                      Text(unit, style: t.bodyMedium?.copyWith(color: c.muted)),
                    ],
                  ),
                  const Spacer(),
                  if (flag != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: c.accentSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        flag!,
                        style: t.labelMedium?.copyWith(
                          color: c.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    final err = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: err.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: err, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Could not load the figures.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: c.ink),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
