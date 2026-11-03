import 'package:event_hive/core/theme/app_theme.dart';
import 'package:event_hive/widgets/common/status_badge_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Event Details / Manage screen.
/// Receives the event's UUID and loads its full data from Supabase.
/// From here the organizer can navigate to Edit Event or other sub-features.
class ManageEventScreen extends StatefulWidget {
  final String eventId; // UUID string from the router
  const ManageEventScreen({super.key, required this.eventId});

  @override
  State<ManageEventScreen> createState() => _ManageEventScreenState();
}

class _ManageEventScreenState extends State<ManageEventScreen> {
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? _event;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  /// Fetches the full event row using its UUID, after verifying ownership.
  /// Only events linked to the signed-in user via event_organizer are allowed.
  Future<void> _loadEvent() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not signed in.');

      // Ownership check: confirm this user is an organizer of this event
      // before loading any details. This prevents accessing events by URL.
      final ownerCheck = await _supabase
          .from('event_organizer')
          .select('event_id')
          .eq('event_id', widget.eventId)
          .eq('user_id', userId)
          .maybeSingle();

      if (ownerCheck == null) {
        throw Exception('You do not have permission to manage this event.');
      }

      final row = await _supabase
          .from('events')
          .select()
          .eq('event_id', widget.eventId)
          .single();

      if (!mounted) return;
      setState(() {
        _event = Map<String, dynamic>.from(row);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kNavy,
        title: const Text(
          'Event Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/organizer/my-events'),
        ),
      ),
      body: _buildBody(context),
      bottomNavigationBar: _buildBottomNav(context),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/organizer/create-event'),
        backgroundColor: kAmber,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null || _event == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(
              'Could not load event.\n${_error ?? ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: kTextSub),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadEvent,
              style: ElevatedButton.styleFrom(backgroundColor: kNavy),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    final event = _event!;
    final imageUrl = (event['image_url'] ?? '').toString().trim();
    final name = (event['name'] ?? 'Untitled').toString();
    final date = (event['event_date'] ?? '').toString();
    final startTime = (event['start_time'] ?? '').toString();
    final venue = (event['venue'] ?? '').toString();
    final club = (event['hosting_org'] ?? '').toString();
    final capacity = (event['capacity'] as num?)?.toInt() ?? 0;
    final status = (event['status'] ?? 'active').toString();
    final isCancelled = status == 'cancelled';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ── Event summary card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageUrl.isEmpty
                      ? _imagePlaceholder()
                      : Image.network(
                          imageUrl,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imagePlaceholder(),
                          loadingBuilder: (_, child, p) =>
                              p == null ? child : _imagePlaceholder(),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                color: kNavy,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          StatusBadge(status: status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _infoRow(
                        Icons.calendar_today_outlined,
                        '$date${startTime.isNotEmpty ? '  •  $startTime' : ''}',
                      ),
                      const SizedBox(height: 4),
                      _infoRow(Icons.location_on_outlined, venue),
                      const SizedBox(height: 4),
                      _infoRow(Icons.groups_outlined, club),
                      const SizedBox(height: 4),
                      _infoRow(Icons.people_outline, 'Capacity: $capacity'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Management menu
          Container(
            clipBehavior:
                Clip.antiAlias, // FIX: keeps ink inside rounded corners
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              // FIX: nearest Material for the ListTiles, so ink is visible
              color: Colors.transparent,
              child: Column(
                children: [
                  // Edit Event — fully implemented
                  _MenuItem(
                    icon: Icons.edit_outlined,
                    title: 'Edit Event',
                    subtitle: 'Update event details',
                    onTap: isCancelled
                        ? null
                        : () => context.go(
                            '/organizer/event/${widget.eventId}/edit',
                          ),
                  ),
                  _divider(),
                  // Placeholder items — implementation comes in later tasks
                  _MenuItem(
                    icon: Icons.people_alt_outlined,
                    title: 'Guest List & Payments',
                    subtitle: 'View registered users',
                    onTap: () =>
                        context.go('/organizer/event/${widget.eventId}/guests'),
                  ),
                  _divider(),
                  _MenuItem(
                    icon: Icons.sell_outlined,
                    title: 'Pricing & Add-ons',
                    subtitle: 'Manage roles and add-ons',
                    onTap: isCancelled
                        ? null
                        : () => context.go(
                            '/organizer/event/${widget.eventId}/pricing',
                          ),
                  ),
                  _divider(),
                  _MenuItem(
                    icon: Icons.bar_chart_outlined,
                    title: 'Analytics',
                    subtitle: 'View event statistics',
                    onTap: () => context.go(
                      '/organizer/event/${widget.eventId}/analytics',
                    ),
                  ),
                  _divider(),
                  _MenuItem(
                    icon: Icons.notifications_outlined,
                    title: 'Notify Attendees',
                    subtitle: 'Send messages / notifications',
                    onTap: () => _comingSoon(context),
                  ),
                  _divider(),
                  _MenuItem(
                    icon: Icons.supervised_user_circle_outlined,
                    title: 'Co-organizers',
                    subtitle: 'Manage co-organizers',
                    onTap: () => _comingSoon(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Cancel Event button (UI only — does not cancel the event yet)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isCancelled ? null : () => _confirmCancel(context),
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              label: Text(
                isCancelled ? 'Event Cancelled' : 'Cancel Event',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFFFF0F0),
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 14, color: kTextSub),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          text,
          style: const TextStyle(color: kTextSub, fontSize: 13),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );

  Widget _divider() => const Divider(height: 1, indent: 16, endIndent: 16);

  Widget _imagePlaceholder() => Container(
    width: 90,
    height: 90,
    decoration: BoxDecoration(
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Icon(Icons.image_outlined, color: Colors.grey),
  );

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This feature is coming soon.')),
    );
  }

  /// Shows a confirmation dialog before cancelling.
  /// Cancel Event implementation will be added in a future task.
  void _confirmCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Event?'),
        content: const Text(
          'Cancelling this event will notify all registered participants. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Go Back'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: call cancel_event() RPC in a future task
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cancel Event will be implemented soon.'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text(
              'Cancel Event',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return BottomAppBar(
      color: Colors.white,
      elevation: 8,
      shape: const CircularNotchedRectangle(),
      notchMargin: 6,
      child: SizedBox(
        height: 56,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              onTap: () => context.go('/organizer/home'),
            ),
            _NavItem(
              icon: Icons.calendar_month_outlined,
              label: 'My Events',
              onTap: () => context.go('/organizer/my-events'),
            ),
            const SizedBox(width: 48),
            _NavItem(
              icon: Icons.bar_chart_rounded,
              label: 'Analytics',
              onTap: () => context.go('/organizer/analytics'),
            ),
            _NavItem(
              icon: Icons.person_outline_rounded,
              label: 'Profile',
              onTap: () => context.go('/organizer/profile'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: kNavy, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: onTap == null ? kTextSub : kNavy,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: kTextSub, fontSize: 12),
      ),
      trailing: onTap == null
          ? null
          : const Icon(Icons.chevron_right, color: kTextSub),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: kTextSub, size: 22),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: kTextSub, fontSize: 10)),
        ],
      ),
    );
  }
}
