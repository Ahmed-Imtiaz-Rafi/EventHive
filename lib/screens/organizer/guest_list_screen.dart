/// guest_list_screen.dart
///
/// Screen 6 — Guest List & Payments for a specific event.
/// Shows all registrations for the event with status filter tabs (All, Paid,
/// Pending, Cancelled) and a search bar.
/// Organizers can review submitted payments via the review_payment() RPC.
/// Reads from: registration, users, payments tables (via registration_balance view).
/// Navigated to from manage_event_screen.dart.

import 'package:event_hive/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GuestListScreen extends StatefulWidget {
  final String eventId;
  const GuestListScreen({super.key, required this.eventId});

  @override
  State<GuestListScreen> createState() => _GuestListScreenState();
}

class _GuestListScreenState extends State<GuestListScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  // All registrations loaded from Supabase
  List<Map<String, dynamic>> _all = [];

  // Filtered list shown in the current tab
  List<Map<String, dynamic>> _filtered = [];

  bool _loading = true;
  String? _error;

  // Active status filter: 'all', 'paid', 'pending', 'cancelled'
  String _filter = 'all';

  // Search query for attendee name / email
  final _searchCtrl = TextEditingController();

  late final TabController _tabCtrl;

  // Tab labels and their corresponding filter keys
  static const _tabs = [
    {'label': 'All', 'key': 'all'},
    {'label': 'Paid', 'key': 'paid'},
    {'label': 'Pending', 'key': 'pending'},
    {'label': 'Cancelled', 'key': 'cancelled'},
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) return;
      setState(() {
        _filter = _tabs[_tabCtrl.index]['key']!;
        _applyFilter();
      });
    });
    _searchCtrl.addListener(_applyFilter);
    _loadGuests();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── DATA ────────────────────────────────────────────────────────────────

  /// Loads all registrations for this event by joining registration → users.
  /// Uses the event_registrant view defined in the schema, which already
  /// filters to events the signed-in organizer manages.
  Future<void> _loadGuests() async {
    setState(() { _loading = true; _error = null; });
    try {
      // event_registrant view joins registration + users + departments
      // and filters by can_manage_event() so only authorized organizers see this
      final rows = await _supabase
          .from('event_registrant')
          .select()
          .eq('event_id', widget.eventId)
          .order('registered_at', ascending: false);

      // Also fetch the latest payment info for each registration
      // to show payment_status and amount
      final regIds = (rows as List)
          .map((r) => r['registration_id'].toString())
          .toList();

      Map<String, Map<String, dynamic>> balanceMap = {};
      if (regIds.isNotEmpty) {
        final balRows = await _supabase
            .from('registration_balance')
            .select()
            .inFilter('registration_id', regIds);
        for (final b in balRows as List) {
          balanceMap[b['registration_id'].toString()] =
          Map<String, dynamic>.from(b);
        }
      }

      // Merge balance data into each row
      final merged = (rows).map<Map<String, dynamic>>((r) {
        final rid = r['registration_id'].toString();
        final bal = balanceMap[rid] ?? {};
        return {
          ...Map<String, dynamic>.from(r),
          'total_amount'  : bal['total_amount'] ?? 0,
          'paid_amount'   : bal['paid_amount'] ?? 0,
          'payment_status': r['payment_status'] ?? 'unpaid',
          'waiting_count' : bal['waiting_count'] ?? 0,
          'next_payment_id': bal['next_payment_id'],
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _all = merged;
        _loading = false;
        _applyFilter();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  /// Filters _all by the active tab and search query.
  void _applyFilter() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = _all.where((r) {
        // Tab filter — maps payment_status to tab keys
        final ps = (r['payment_status'] ?? '').toString().toLowerCase();
        final st = (r['status'] ?? '').toString().toLowerCase();
        final matchesTab = _filter == 'all' ||
            (_filter == 'paid' && ps == 'paid') ||
            (_filter == 'pending' && st == 'pending') ||
            (_filter == 'cancelled' && st == 'cancelled');

        // Search filter
        final name = (r['username'] ?? '').toString().toLowerCase();
        final matchesSearch = query.isEmpty || name.contains(query);

        return matchesTab && matchesSearch;
      }).toList();
    });
  }

  // ─── PAYMENT REVIEW ──────────────────────────────────────────────────────

  /// Opens a dialog to approve or reject a submitted payment.
  /// Calls the review_payment() RPC — the only permitted way to review payments.
  /// p_received_amount is required when approving.
  Future<void> _reviewPayment(Map<String, dynamic> guest) async {
    final paymentId = guest['next_payment_id']?.toString();
    if (paymentId == null) {
      _msg('No payment waiting for review.');
      return;
    }

    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    bool approve = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Review Payment',
              style: TextStyle(color: kNavy, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Approve / Reject toggle
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Approve'),
                      selected: approve,
                      selectedColor: const Color(0xFFD4F4DD),
                      onSelected: (_) => set(() => approve = true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Reject'),
                      selected: !approve,
                      selectedColor: const Color(0xFFFFE0E0),
                      onSelected: (_) => set(() => approve = false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Amount received — required when approving
              if (approve)
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Amount Received',
                    hintText: 'Actual amount on statement',
                  ),
                ),
              // Note — required when rejecting
              if (!approve) ...[
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Reason for rejection',
                    hintText: 'Required',
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kNavy),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) {
      amountCtrl.dispose();
      noteCtrl.dispose();
      return;
    }

    try {
      final amount = double.tryParse(amountCtrl.text.trim());
      final note = noteCtrl.text.trim();

      if (approve && (amount == null || amount <= 0)) {
        _msg('Enter the amount actually received.');
        return;
      }
      if (!approve && note.isEmpty) {
        _msg('A reason is required when rejecting.');
        return;
      }

      // Calls the schema's review_payment() SECURITY DEFINER RPC.
      // Only organizers of this event (or admins) can call this.
      await _supabase.rpc('review_payment', params: {
        'p_payment_id'      : paymentId,
        'p_approve'         : approve,
        'p_received_amount' : approve ? amount : null,
        'p_note'            : approve ? null : note,
      });

      _msg(approve ? 'Payment approved!' : 'Payment rejected.');
      await _loadGuests(); // refresh the list
    } catch (e) {
      _msg('Failed: $e');
    } finally {
      amountCtrl.dispose();
      noteCtrl.dispose();
    }
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  // ─── BUILD ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kNavy,
        title: const Text('Guest List & Payments',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/organizer/event/${widget.eventId}'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadGuests,
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: kAmber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _tabs.map((t) => Tab(text: t['label'])).toList(),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name...',
                prefixIcon: const Icon(Icons.search, color: kTextSub),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBorder),
                ),
              ),
            ),
          ),

          // Total count
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Total Registered: ${_all.length}',
                  style: const TextStyle(
                      color: kTextSub, fontSize: 12),
                ),
              ),
            ),

          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center,
                style: const TextStyle(color: kTextSub)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadGuests,
              style: ElevatedButton.styleFrom(backgroundColor: kNavy),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (_filtered.isEmpty) {
      return const Center(
        child: Text('No attendees found.', style: TextStyle(color: kTextSub)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadGuests,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _GuestCard(
          guest: _filtered[i],
          onReview: () => _reviewPayment(_filtered[i]),
        ),
      ),
    );
  }
}

// ─── Guest card widget ────────────────────────────────────────────────────────

class _GuestCard extends StatelessWidget {
  final Map<String, dynamic> guest;
  final VoidCallback onReview;

  const _GuestCard({required this.guest, required this.onReview});

  @override
  Widget build(BuildContext context) {
    final name = (guest['username'] ?? 'Unknown').toString();
    final studentId = (guest['student_id'] ?? '—').toString();
    final role = (guest['role_name'] ?? '—').toString();
    final regStatus = (guest['status'] ?? 'pending').toString();
    final payStatus = (guest['payment_status'] ?? 'unpaid').toString();
    final total = (guest['total_amount'] as num?)?.toDouble() ?? 0;
    final waiting = (guest['waiting_count'] as num?)?.toInt() ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Avatar circle with initial
          CircleAvatar(
            backgroundColor: kNavy.withValues(alpha: 0.1),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: kNavy, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),

          // Name, student ID, role
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: kNavy,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(studentId,
                    style: const TextStyle(
                        color: kTextSub, fontSize: 12)),
                const SizedBox(height: 2),
                Text(role,
                    style: const TextStyle(
                        color: kTextSub, fontSize: 12)),
              ],
            ),
          ),

          // Amount + status badges
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                total == total.truncateToDouble()
                    ? total.toInt().toString()
                    : total.toStringAsFixed(2),
                style: const TextStyle(
                    color: kNavy,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
              const SizedBox(height: 4),
              _StatusPill(label: payStatus),
              // Show "Review" button only when a payment is waiting
              if (waiting > 0) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onReview,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: kAmber,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Review',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
              // Show registration status if cancelled
              if (regStatus == 'cancelled')
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _StatusPill(label: regStatus),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small coloured pill badge for payment / registration status.
class _StatusPill extends StatelessWidget {
  final String label;
  const _StatusPill({required this.label});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (label.toLowerCase()) {
      case 'paid':
        bg = const Color(0xFFD4F4DD); fg = const Color(0xFF1A7A3A);
        break;
      case 'pending':
      case 'unpaid':
        bg = const Color(0xFFFFF3CD); fg = const Color(0xFF856404);
        break;
      case 'cancelled':
      case 'failed':
      case 'refund_pending':
        bg = const Color(0xFFFFE0E0); fg = const Color(0xFFD32F2F);
        break;
      default:
        bg = const Color(0xFFE3EEFF); fg = const Color(0xFF1A55CC);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label,
          style: TextStyle(
              color: fg, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}
