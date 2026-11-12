import 'package:event_hive/core/theme/admin/admin_theme.dart';
import 'package:event_hive/widgets/admin/admin_widgets.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin view of one event: Details / Registrations / Payments.
/// Admin actions: cancel the event, cancel a registration (reason required),
/// record that a refund was sent. Payments are read-only here (the organizer
/// reviews them).
class EventDetailScreen extends StatefulWidget {
  final String eventId; // UUID
  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

/// Supabase returns at most 1000 rows per request: read in pages.
Future<List<Map<String, dynamic>>> _fetchAll(
  Future<List<Map<String, dynamic>>> Function(int from, int to) page,
) async {
  const size = 1000;
  final all = <Map<String, dynamic>>[];
  var from = 0;
  while (true) {
    final rows = await page(from, from + size - 1);
    all.addAll(rows);
    if (rows.length < size) break;
    from += size;
  }
  return all;
}

num _num(dynamic v) => num.tryParse('$v') ?? 0;

String _money(dynamic v) {
  final n = _num(v);
  final s = n == n.roundToDouble()
      ? n.toStringAsFixed(0)
      : n.toStringAsFixed(2);
  final parts = s.split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return 'BDT ${parts.length > 1 ? '$whole.${parts[1]}' : whole}';
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? _event;
  List<Map<String, dynamic>> _organizers = [];
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _addons = [];
  List<Map<String, dynamic>> _registrants = [];
  List<Map<String, dynamic>> _balances = [];
  List<Map<String, dynamic>> _payments = [];

  bool _loading = true;
  bool _failed = false;
  bool _busy = false;

  String _regQuery = '';
  String _regFilter = 'all';
  String _payFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.eventId;
    try {
      final r = await Future.wait<Object?>([
        _supabase
            .from('event_overview')
            .select(
              'event_id, name, event_date, start_time, end_time, venue, '
              'capacity, status, categories, registered_count, hosting_org, '
              'image_url, description',
            )
            .eq('event_id', id)
            .single(),
        _supabase
            .from('event_organizer')
            .select('users(username, full_name, avatar_url)')
            .eq('event_id', id),
        _supabase
            .from('event_role_availability')
            .select('role_name, track_name, price, slots, taken')
            .eq('event_id', id)
            .order('role_name')
            .order('track_name'),
        _supabase
            .from('event_accessories')
            .select('accessory_name, size, price')
            .eq('event_id', id)
            .order('accessory_name'),
        _fetchAll(
          (a, b) => _supabase
              .from('event_registrant')
              .select(
                'registration_id, username, full_name, student_id, '
                'department_name, role_name, track_name, status, '
                'payment_status, total_amount, registered_at, avatar_url',
              )
              .eq('event_id', id)
              .order('registered_at', ascending: false)
              .order('registration_id')
              .range(a, b),
        ),
        _fetchAll(
          (a, b) => _supabase
              .from('registration_balance')
              .select(
                'registration_id, status, payment_status, total_amount, '
                'paid_amount, remaining_amount',
              )
              .eq('event_id', id)
              .order('registration_id')
              .range(a, b),
        ),
        _fetchAll(
          (a, b) => _supabase
              .from('payments')
              .select(
                'payment_id, registration_id, transaction_id, '
                'amount_expected, amount_received, status, submitted_at, '
                'review_note, registration!inner(event_id, '
                'users!registration_user_id_fkey(username, full_name)), '
                'payment_accounts(payment_methods(label))',
              )
              .eq('registration.event_id', id)
              .order('submitted_at', ascending: false)
              .order('payment_id')
              .range(a, b),
        ),
      ]);
      if (!mounted) return;
      List<Map<String, dynamic>> list(Object? o) =>
          List<Map<String, dynamic>>.from(o as List);
      setState(() {
        _event = Map<String, dynamic>.from(r[0] as Map);
        _organizers = list(r[1]);
        _roles = list(r[2]);
        _addons = list(r[3]);
        _registrants = list(r[4]);
        _balances = list(r[5]);
        _payments = list(r[6]);
        _loading = false;
        _failed = false;
      });
    } catch (e) {
      debugPrint('Event detail load error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Runs an RPC, shows the outcome, then refreshes everything.
  Future<void> _run(
    String rpc,
    Map<String, dynamic> params,
    String success,
  ) async {
    setState(() => _busy = true);
    try {
      await _supabase.rpc(rpc, params: params);
      _toast(success);
      await _load();
    } catch (e) {
      _toast(adminError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _open {
    final e = _event;
    if (e == null || e['status'] != 'active') return false;
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    return '${e['event_date']}'.compareTo(today) >= 0;
  }

  Future<void> _cancelEvent() async {
    final live = _registrants
        .where((r) => r['status'] == 'pending' || r['status'] == 'confirmed')
        .length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this event?'),
        content: Text(
          '$live live registration${live == 1 ? '' : 's'} will be cancelled. '
          'Participants who already paid will be marked as refund due. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Cancel event'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run('cancel_event', {
      'p_event_id': widget.eventId,
    }, 'Event cancelled.');
  }

  Future<void> _cancelRegistration(Map<String, dynamic> r) async {
    final name = adminName(r);
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _NoteDialog(
        title: 'Cancel registration?',
        message:
            'The seat of $name is released. If they have paid, a refund '
            'becomes due. They will see the reason below.',
        hint: 'Reason (required)',
        action: 'Cancel registration',
        required: true,
        destructive: true,
      ),
    );
    if (reason == null) return;
    await _run('cancel_registration_by_admin', {
      'p_registration_id': r['registration_id'],
      'p_reason': reason,
    }, 'Registration cancelled.');
  }

  Future<void> _recordRefund(Map<String, dynamic> r) async {
    final name = adminName(r);
    final bal = _balances.firstWhere(
      (b) => b['registration_id'] == r['registration_id'],
      orElse: () => const {},
    );
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _NoteDialog(
        title: 'Record refund?',
        message:
            'Confirm that ${_money(bal['paid_amount'])} was sent back to '
            '$name outside the app.',
        hint: 'Note (optional)',
        action: 'Mark refunded',
        required: false,
      ),
    );
    if (note == null) return;
    await _run('mark_refunded', {
      'p_registration_id': r['registration_id'],
      'p_note': note.isEmpty ? null : note,
    }, 'Refund recorded.');
  }

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              AdminHeader(
                title: 'Event details',
                subtitle:
                    (_event?['name'] ?? 'Details, registrations, payments')
                        .toString(),
              ),
              AdminTabBar(
                labels: [
                  'Details',
                  _loading
                      ? 'Registrations'
                      : 'Registrations (${_registrants.length})',
                  _loading ? 'Payments' : 'Payments (${_payments.length})',
                ],
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : _failed || _event == null
                    ? AdminMessage(
                        icon: Icons.cloud_off_outlined,
                        text: 'Could not load this event.',
                        actionLabel: 'Retry',
                        onAction: () {
                          setState(() => _loading = true);
                          _load();
                        },
                      )
                    : TabBarView(
                        children: [
                          _detailsTab(),
                          _registrationsTab(),
                          _paymentsTab(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── Details ─────────────────────────

  Widget _detailsTab() {
    final c = AdminColors.of(context);
    final t = Theme.of(context).textTheme;
    final e = _event!;

    final cancelled = e['status'] == 'cancelled';
    final date = DateTime.tryParse('${e['event_date'] ?? ''}');
    final start = adminTime(e['start_time']?.toString());
    final end = adminTime(e['end_time']?.toString());
    final cap = (e['capacity'] as num?)?.toInt() ?? 0;
    final reg = (e['registered_count'] as num?)?.toInt() ?? 0;
    final full = cap > 0 && reg >= cap;
    final imageUrl = (e['image_url'] ?? '').toString().trim();
    final desc = (e['description'] ?? '').toString().trim();
    final cats = ((e['categories'] as List?) ?? [])
        .map((x) => x.toString())
        .toList();

    final stateLabel = cancelled ? 'Cancelled' : (_open ? 'Upcoming' : 'Past');
    final stateTone = cancelled ? AdminTone.danger : AdminTone.neutral;

    // add-ons grouped by name: "T-shirt" -> ["M · BDT 450", "L · BDT 450"]
    final grouped = <String, List<String>>{};
    for (final a in _addons) {
      final size = '${a['size']}';
      final label = size == 'one_size'
          ? _money(a['price'])
          : '${size.toUpperCase()} · ${_money(a['price'])}';
      grouped.putIfAbsent('${a['accessory_name']}', () => []).add(label);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          if (imageUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                imageUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            (e['name'] ?? 'Untitled').toString(),
            style: t.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: c.ink,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AdminPill(label: stateLabel, tone: stateTone),
              for (final cat in cats) AdminPill(label: cat),
            ],
          ),
          const SizedBox(height: 20),

          const _SectionTitle('Overview'),
          AdminCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Date',
                  value: date == null ? '–' : adminDate(date),
                ),
                _InfoRow(
                  icon: Icons.schedule_outlined,
                  label: 'Time',
                  value: [start, end].where((x) => x.isNotEmpty).join(' – '),
                ),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Venue',
                  value: (e['venue'] ?? '').toString(),
                ),
                _InfoRow(
                  icon: Icons.groups_outlined,
                  label: 'Hosted by',
                  value: (e['hosting_org'] ?? '').toString(),
                ),
                _InfoRow(
                  icon: Icons.event_seat_outlined,
                  label: 'Seats',
                  value: cap > 0 ? '$reg of $cap taken' : '$reg taken',
                  footer: cap > 0
                      ? LinearProgressIndicator(
                          value: (reg / cap).clamp(0.0, 1.0).toDouble(),
                          minHeight: 4,
                          backgroundColor: c.border,
                          color: full ? c.accent : c.brand,
                          borderRadius: BorderRadius.circular(4),
                        )
                      : null,
                ),
                _InfoRow(
                  icon: Icons.badge_outlined,
                  label: _organizers.length == 1 ? 'Organizer' : 'Organizers',
                  value: _organizers.isEmpty
                      ? '–'
                      : _organizers
                            .map((o) => adminName(o['users'] as Map?))
                            .join(', '),
                  last: true,
                ),
              ],
            ),
          ),

          if (desc.isNotEmpty) ...[
            const SizedBox(height: 20),
            const _SectionTitle('About'),
            AdminCard(
              child: Text(desc, style: t.bodyMedium?.copyWith(height: 1.5)),
            ),
          ],

          const SizedBox(height: 20),
          const _SectionTitle('Roles and pricing'),
          if (_roles.isEmpty)
            AdminCard(
              child: Text(
                'No roles listed for this event.',
                style: t.bodyMedium?.copyWith(color: c.muted),
              ),
            )
          else
            AdminCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  for (var i = 0; i < _roles.length; i++)
                    _RoleRow(role: _roles[i], last: i == _roles.length - 1),
                ],
              ),
            ),

          if (grouped.isNotEmpty) ...[
            const SizedBox(height: 20),
            const _SectionTitle('Add-ons'),
            AdminCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  for (final entry in grouped.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: t.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final l in entry.value) AdminPill(label: l),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),
          if (cancelled)
            _Notice(
              icon: Icons.block_outlined,
              text:
                  'This event was cancelled. Check the Registrations tab to '
                  'see who still needs a refund.',
              tone: AdminTone.danger,
            )
          else if (!_open)
            _Notice(
              icon: Icons.history_outlined,
              text: 'This event has finished, so it can no longer be changed.',
            )
          else
            OutlinedButton.icon(
              onPressed: _busy ? null : _cancelEvent,
              icon: const Icon(Icons.event_busy_outlined),
              label: const Text('Cancel event'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.6),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────── Registrations ───────────────────────

  Widget _registrationsTab() {
    final q = _regQuery;
    bool statusOk(Map<String, dynamic> r) {
      final s = r['status'];
      switch (_regFilter) {
        case 'confirmed':
          return s == 'confirmed';
        case 'pending':
          return s == 'pending';
        case 'cancelled':
          return s == 'cancelled' || s == 'refunded';
        default:
          return true;
      }
    }

    final shown = _registrants.where((r) {
      if (!statusOk(r)) return false;
      if (q.isEmpty) return true;
      return '${r['username']} ${r['full_name']} ${r['student_id']}'
          .toLowerCase()
          .contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: AdminSearchField(
            hint: 'Search name or student ID',
            onChanged: (v) =>
                setState(() => _regQuery = v.trim().toLowerCase()),
          ),
        ),
        _FilterChips(
          value: _regFilter,
          onChanged: (v) => setState(() => _regFilter = v),
          options: const [
            ('all', 'All'),
            ('confirmed', 'Confirmed'),
            ('pending', 'Pending'),
            ('cancelled', 'Cancelled'),
          ],
        ),
        Expanded(
          child: AdminRefreshList(
            onRefresh: _load,
            itemCount: shown.length,
            emptyText: _registrants.isEmpty
                ? 'Nobody has registered yet.'
                : 'No registrations match.',
            emptyIcon: Icons.how_to_reg_outlined,
            itemBuilder: (_, i) {
              final r = shown[i];
              final status = '${r['status']}';
              final canCancel =
                  _open && (status == 'pending' || status == 'confirmed');
              final canRefund =
                  status == 'cancelled' &&
                  r['payment_status'] == 'refund_pending';
              return _RegistrantCard(
                reg: r,
                busy: _busy,
                onCancel: canCancel ? () => _cancelRegistration(r) : null,
                onRefund: canRefund ? () => _recordRefund(r) : null,
              );
            },
          ),
        ),
      ],
    );
  }

  // ───────────────────────── Payments ─────────────────────────

  Widget _paymentsTab() {
    final c = AdminColors.of(context);
    final t = Theme.of(context).textTheme;

    final live = _balances
        .where((b) => b['status'] == 'pending' || b['status'] == 'confirmed')
        .toList();
    final due = _balances
        .where(
          (b) =>
              b['status'] == 'cancelled' &&
              b['payment_status'] == 'refund_pending',
        )
        .toList();
    final refunded = _balances.where((b) => b['status'] == 'refunded').toList();
    num sum(List<Map<String, dynamic>> rows, String key) =>
        rows.fold<num>(0, (a, r) => a + _num(r[key]));

    final shown = _payments
        .where((p) => _payFilter == 'all' || p['status'] == _payFilter)
        .toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Collected',
                  value: _money(sum(live, 'paid_amount')),
                  sub: '${live.length} live registrations',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  label: 'Outstanding',
                  value: _money(sum(live, 'remaining_amount')),
                  sub: 'still to be paid',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Refunds due',
                  value: _money(sum(due, 'paid_amount')),
                  sub: '${due.length} to return',
                  highlight: due.isNotEmpty,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  label: 'Refunded',
                  value: _money(sum(refunded, 'paid_amount')),
                  sub: '${refunded.length} returned',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Transactions'),
          _FilterChips(
            padded: false,
            value: _payFilter,
            onChanged: (v) => setState(() => _payFilter = v),
            options: const [
              ('all', 'All'),
              ('submitted', 'Awaiting review'),
              ('verified', 'Verified'),
              ('rejected', 'Rejected'),
            ],
          ),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: AdminMessage(
                icon: Icons.receipt_long_outlined,
                text: _payments.isEmpty
                    ? 'No payments yet.'
                    : 'No payments match.',
              ),
            )
          else
            for (final p in shown) ...[
              _PaymentCard(payment: p, c: c, t: t),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

// ═════════════════════════ pieces ═════════════════════════

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: c.muted,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? footer;
  final bool last;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.footer,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: c.brand),
              const SizedBox(width: 12),
              SizedBox(
                width: 78,
                child: Text(
                  label,
                  style: t.bodyMedium?.copyWith(color: c.muted),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value.isEmpty ? '–' : value, style: t.bodyMedium),
                    if (footer != null) ...[const SizedBox(height: 8), footer!],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!last) Divider(color: c.border, height: 1),
      ],
    );
  }
}

class _RoleRow extends StatelessWidget {
  final Map<String, dynamic> role;
  final bool last;
  const _RoleRow({required this.role, required this.last});

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    final t = Theme.of(context).textTheme;
    final track = (role['track_name'] ?? '').toString();
    final price = _num(role['price']);
    final slots = (role['slots'] as num?)?.toInt();
    final taken = (role['taken'] as num?)?.toInt() ?? 0;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.isEmpty
                          ? '${role['role_name']}'
                          : '${role['role_name']}  ·  $track',
                      style: t.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      slots == null ? '$taken taken' : '$taken of $slots taken',
                      style: t.bodySmall?.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ),
              Text(price == 0 ? 'Free' : _money(price), style: t.bodyMedium),
            ],
          ),
        ),
        if (!last) Divider(color: c.border, height: 1),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;
  final AdminTone tone;
  const _Notice({
    required this.icon,
    required this.text,
    this.tone = AdminTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    final color = tone == AdminTone.danger
        ? Theme.of(context).colorScheme.error
        : c.muted;
    return AdminCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: c.ink, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final List<(String, String)> options;
  final String value;
  final ValueChanged<String> onChanged;
  final bool padded;
  const _FilterChips({
    required this.options,
    required this.value,
    required this.onChanged,
    this.padded = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: padded ? 20 : 0),
      child: Row(
        children: [
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(o.$2),
                selected: value == o.$1,
                onSelected: (_) => onChanged(o.$1),
                showCheckmark: false,
                selectedColor: c.brandSoft,
                backgroundColor: c.surface,
                side: BorderSide(color: value == o.$1 ? c.brand : c.border),
                labelStyle: TextStyle(
                  color: value == o.$1 ? c.brand : c.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final bool highlight;
  const _StatTile({
    required this.label,
    required this.value,
    required this.sub,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    final t = Theme.of(context).textTheme;
    return AdminCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.bodySmall?.copyWith(color: c.muted)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AdminTheme.numeral(highlight ? c.accent : c.ink, size: 22),
            ),
          ),
          const SizedBox(height: 6),
          Text(sub, style: t.bodySmall?.copyWith(color: c.muted)),
        ],
      ),
    );
  }
}

class _RegistrantCard extends StatelessWidget {
  final Map<String, dynamic> reg;
  final bool busy;
  final VoidCallback? onCancel;
  final VoidCallback? onRefund;
  const _RegistrantCard({
    required this.reg,
    required this.busy,
    this.onCancel,
    this.onRefund,
  });

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    final t = Theme.of(context).textTheme;
    final name = adminName(reg);
    final sid = (reg['student_id'] ?? '').toString();
    final dept = (reg['department_name'] ?? '').toString();
    final sub = [
      if (sid.isNotEmpty) sid,
      if (dept.isNotEmpty) dept,
    ].join('  ·  ');
    final role = (reg['role_name'] ?? '').toString();
    final track = (reg['track_name'] ?? '').toString();
    final status = '${reg['status']}';
    final pay = '${reg['payment_status']}';

    final String label;
    final AdminTone tone;
    switch (status) {
      case 'confirmed':
        label = 'Confirmed';
        tone = AdminTone.success;
      case 'pending':
        label = 'Pending';
        tone = AdminTone.attention;
      case 'refunded':
        label = 'Refunded';
        tone = AdminTone.neutral;
      case 'cancelled':
        final due = pay == 'refund_pending';
        label = due ? 'Refund due' : 'Cancelled';
        tone = due ? AdminTone.danger : AdminTone.neutral;
      default:
        label = status;
        tone = AdminTone.neutral;
    }

    final hasMenu = onCancel != null || onRefund != null;

    return AdminCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminAvatar(path: reg['avatar_url'] as String?, name: name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
                if (sub.isNotEmpty)
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(color: c.muted),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AdminPill(label: label, tone: tone),
                    if (role.isNotEmpty)
                      AdminPill(label: track.isEmpty ? role : '$role · $track'),
                    Text(
                      _money(reg['total_amount']),
                      style: t.bodySmall?.copyWith(
                        color: c.muted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (hasMenu)
            PopupMenuButton<String>(
              enabled: !busy,
              icon: Icon(Icons.more_vert_rounded, color: c.muted),
              onSelected: (v) {
                if (v == 'cancel') onCancel?.call();
                if (v == 'refund') onRefund?.call();
              },
              itemBuilder: (_) => [
                if (onCancel != null)
                  PopupMenuItem(
                    value: 'cancel',
                    child: Text(
                      'Cancel registration',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (onRefund != null)
                  const PopupMenuItem(
                    value: 'refund',
                    child: Text('Record refund'),
                  ),
              ],
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;
  final AdminColors c;
  final TextTheme t;
  const _PaymentCard({required this.payment, required this.c, required this.t});

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final who = adminName((p['registration'] as Map?)?['users'] as Map?);
    final method =
        (((p['payment_accounts'] as Map?)?['payment_methods']
                    as Map?)?['label'] ??
                '')
            .toString();
    final status = '${p['status']}';
    final received = p['amount_received'];
    final amount = received ?? p['amount_expected'];
    final submitted = DateTime.tryParse(
      '${p['submitted_at'] ?? ''}',
    )?.toLocal();
    final note = (p['review_note'] ?? '').toString();

    final String label;
    final AdminTone tone;
    switch (status) {
      case 'verified':
        label = 'Verified';
        tone = AdminTone.success;
      case 'rejected':
        label = 'Rejected';
        tone = AdminTone.danger;
      default:
        label = 'Awaiting review';
        tone = AdminTone.attention;
    }

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  who,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
              ),
              Text(
                _money(amount),
                style: t.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              '${p['transaction_id']}',
              if (method.isNotEmpty) method,
            ].join('  ·  '),
            style: t.bodySmall?.copyWith(color: c.muted),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              AdminPill(label: label, tone: tone),
              const SizedBox(width: 10),
              Text(
                adminAgo(submitted),
                style: t.bodySmall?.copyWith(color: c.muted),
              ),
            ],
          ),
          if (status == 'rejected' && note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Reason: $note', style: t.bodySmall?.copyWith(color: c.muted)),
          ],
        ],
      ),
    );
  }
}

/// A confirm dialog with a text box. Pops the trimmed text, or null on cancel.
/// Owns its controller, so it is disposed safely with the dialog.
class _NoteDialog extends StatefulWidget {
  final String title;
  final String message;
  final String hint;
  final String action;
  final bool required;
  final bool destructive;
  const _NoteDialog({
    required this.title,
    required this.message,
    required this.hint,
    required this.action,
    required this.required,
    this.destructive = false,
  });

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text.trim();
    final canSubmit = !widget.required || text.isNotEmpty;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 3,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: widget.hint,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Go back'),
        ),
        FilledButton(
          onPressed: canSubmit ? () => Navigator.pop(context, text) : null,
          style: widget.destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                )
              : null,
          child: Text(widget.action),
        ),
      ],
    );
  }
}
