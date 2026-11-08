/// analytics_screen.dart
///
/// Screen 7 — Event Analytics for a specific event.
/// Shows: total registrations, verified revenue, capacity remaining,
/// registrations overview bar, and payment status breakdown.
/// All numbers are computed from real Supabase data:
///   - registration table for counts and status
///   - payments table for verified (approved) revenue only
///   - events table for capacity
/// Navigated to from manage_event_screen.dart (per-event analytics),
/// and also from the bottom nav (global placeholder, routed per-event later).

import 'package:event_hive/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsScreen extends StatefulWidget {
  /// eventId is optional — when null, the screen shows a message to pick an event.
  final String? eventId;
  const AnalyticsScreen({super.key, this.eventId});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _supabase = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  // Metrics computed from real data
  int _totalRegistrations = 0;
  int _confirmedCount = 0;
  int _pendingCount = 0;
  int _cancelledCount = 0;
  double _verifiedRevenue = 0;
  int _capacity = 0;
  String _eventName = '';

  // Payment status counts for the breakdown section
  int _paidCount = 0;
  int _unpaidCount = 0;
  int _refundCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.eventId != null) _loadAnalytics();
    else setState(() => _loading = false);
  }

  // ─── DATA ────────────────────────────────────────────────────────────────

  /// Loads all analytics data for the event.
  /// Revenue = sum of amount_received from payments where status = 'verified'.
  /// We never count unverified submissions as revenue.
  Future<void> _loadAnalytics() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Fetch event info, all registrations, and all verified payments in parallel
      final results = await Future.wait<dynamic>([
        _supabase
            .from('events')
            .select('name, capacity')
            .eq('event_id', widget.eventId!)
            .single(),
        _supabase
            .from('registration')
            .select('status, payment_status')
            .eq('event_id', widget.eventId!),
        // Only verified payments count as real revenue
        _supabase
            .from('payments')
            .select('amount_received, registration_id')
            .eq('status', 'verified'),
      ]);

      final event = results[0] as Map;
      final regs = results[1] as List;
      final payments = results[2] as List;

      // Get registration_ids for this event to filter payments
      final regIds = regs.isNotEmpty
          ? await _supabase
          .from('registration')
          .select('registration_id')
          .eq('event_id', widget.eventId!)
          : [];

      final regIdSet = (regIds)
          .map((r) => r['registration_id'].toString())
          .toSet();

      // Compute registration counts by status
      int confirmed = 0, pending = 0, cancelled = 0;
      int paid = 0, unpaid = 0, refund = 0;

      for (final r in regs) {
        final st = (r['status'] ?? '').toString();
        final ps = (r['payment_status'] ?? '').toString();
        if (st == 'confirmed') confirmed++;
        else if (st == 'pending') pending++;
        else if (st == 'cancelled') cancelled++;

        if (ps == 'paid') paid++;
        else if (ps == 'refund_pending') refund++;
        else unpaid++;
      }

      // Compute verified revenue — only from payments belonging to this event
      double revenue = 0;
      for (final p in payments) {
        if (regIdSet.contains(p['registration_id'].toString())) {
          revenue += (p['amount_received'] as num?)?.toDouble() ?? 0;
        }
      }

      if (!mounted) return;
      setState(() {
        _eventName = (event['name'] ?? '').toString();
        _capacity = (event['capacity'] as num?)?.toInt() ?? 0;
        _totalRegistrations = regs.length;
        _confirmedCount = confirmed;
        _pendingCount = pending;
        _cancelledCount = cancelled;
        _verifiedRevenue = revenue;
        _paidCount = paid;
        _unpaidCount = unpaid;
        _refundCount = refund;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  int get _remaining => (_capacity - _confirmedCount - _pendingCount)
      .clamp(0, _capacity);

  // ─── BUILD ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Detect if coming from event details (has eventId) or bottom nav (no eventId)
    final fromEvent = widget.eventId != null;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kNavy,
        title: const Text('Analytics',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => fromEvent
              ? context.go('/organizer/event/${widget.eventId}')
              : context.go('/organizer/home'),
        ),
        actions: [
          if (fromEvent)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadAnalytics,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : !fromEvent
          ? const Center(
        child: Text(
          'Open Analytics from an event\nto see its statistics.',
          textAlign: TextAlign.center,
          style: TextStyle(color: kTextSub, fontSize: 15),
        ),
      )
          : _buildContent(),
    );
  }

  Widget _buildError() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
        const SizedBox(height: 12),
        Text(_error!, textAlign: TextAlign.center,
            style: const TextStyle(color: kTextSub)),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _loadAnalytics,
          style: ElevatedButton.styleFrom(backgroundColor: kNavy),
          child: const Text('Retry', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event name header
          Text(
            _eventName,
            style: const TextStyle(
                color: kNavy, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // ── Top metric cards ──────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Total Registrations',
                  value: _totalRegistrations.toString(),
                  icon: Icons.people_outline,
                  color: kNavy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: 'Revenue Collected',
                  value: '৳${_verifiedRevenue.toStringAsFixed(0)}',
                  icon: Icons.payments_outlined,
                  color: const Color(0xFF1A7A3A),
                  // Only verified payments count — not pending submissions
                  note: 'Verified only',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Capacity remaining ────────────────────────────────────────
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_seat_outlined, color: kNavy, size: 20),
                    const SizedBox(width: 8),
                    const Text('Capacity Remaining',
                        style: TextStyle(
                            color: kNavy,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    const Spacer(),
                    Text(
                      '$_remaining / $_capacity',
                      style: const TextStyle(
                          color: kNavy,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Visual progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _capacity > 0
                        ? (_totalRegistrations / _capacity).clamp(0.0, 1.0)
                        : 0,
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(kAmber),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Registration overview ─────────────────────────────────────
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Registrations Overview',
                    style: TextStyle(
                        color: kNavy,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                const SizedBox(height: 16),
                _OverviewRow(
                    label: 'Confirmed',
                    count: _confirmedCount,
                    total: _totalRegistrations,
                    color: const Color(0xFF1A7A3A)),
                const SizedBox(height: 8),
                _OverviewRow(
                    label: 'Pending',
                    count: _pendingCount,
                    total: _totalRegistrations,
                    color: kAmber),
                const SizedBox(height: 8),
                _OverviewRow(
                    label: 'Cancelled',
                    count: _cancelledCount,
                    total: _totalRegistrations,
                    color: Colors.redAccent),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Payment status ────────────────────────────────────────────
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Payment Status',
                    style: TextStyle(
                        color: kNavy,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                const SizedBox(height: 16),
                // Visual donut-style legend
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _PaymentLegend(
                        label: 'Paid',
                        count: _paidCount,
                        total: _totalRegistrations,
                        color: const Color(0xFF1A7A3A)),
                    _PaymentLegend(
                        label: 'Unpaid',
                        count: _unpaidCount,
                        total: _totalRegistrations,
                        color: kAmber),
                    _PaymentLegend(
                        label: 'Refund',
                        count: _refundCount,
                        total: _totalRegistrations,
                        color: Colors.redAccent),
                  ],
                ),
                const SizedBox(height: 16),
                // Stacked bar
                if (_totalRegistrations > 0)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Row(
                      children: [
                        _barSegment(_paidCount, _totalRegistrations,
                            const Color(0xFF1A7A3A)),
                        _barSegment(_unpaidCount, _totalRegistrations, kAmber),
                        _barSegment(_refundCount, _totalRegistrations,
                            Colors.redAccent),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  '${_totalRegistrations} total registrations',
                  style: const TextStyle(color: kTextSub, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// A single coloured segment in the stacked payment bar.
  Widget _barSegment(int count, int total, Color color) {
    if (count == 0) return const SizedBox.shrink();
    return Expanded(
      flex: count,
      child: Container(height: 12, color: color),
    );
  }

  /// Wraps content in a white rounded card.
  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2))
      ],
    ),
    child: child,
  );
}

// ─── Small reusable widgets ───────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? note;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: kTextSub, fontSize: 12)),
          if (note != null) ...[
            const SizedBox(height: 2),
            Text(note!,
                style: const TextStyle(
                    color: kTextSub, fontSize: 10, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}

/// One row in the registrations overview section — label + count + bar.
class _OverviewRow extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _OverviewRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style: const TextStyle(color: kTextSub, fontSize: 13)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text('$count',
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}

/// Circular percentage widget for the payment status legend.
class _PaymentLegend extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _PaymentLegend({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (count / total * 100).round() : 0;
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.15),
          ),
          child: Center(
            child: Text('$pct%',
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(color: kTextSub, fontSize: 12)),
        Text('$count',
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
