import 'package:event_hive/core/theme/app_theme.dart';
import 'package:event_hive/widgets/common/status_badge_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shows all events that belong to the signed-in organizer.
/// Splits into two sections: upcoming/active and ended/cancelled.
/// Ended/cancelled section can be hidden with a toggle.
class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _events = [];
  Map<String, int> _seatCounts = {};
  bool _loading = true;
  String? _error;

  // Controls whether ended/cancelled events are shown
  bool _showOld = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() { _loading = true; _error = null; });
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not signed in.');

      final orgRows = await _supabase
          .from('event_organizer')
          .select('event_id')
          .eq('user_id', userId);

      final eventIds = (orgRows as List)
          .map((r) => r['event_id'].toString())
          .toList();

      if (eventIds.isEmpty) {
        if (!mounted) return;
        setState(() { _events = []; _loading = false; });
        return;
      }

      final rows = await _supabase
          .from('events')
          .select()
          .inFilter('event_id', eventIds)
          .order('event_date', ascending: false);

      // Count pending+confirmed registrations per event
      final seatRows = await _supabase
          .from('registration')
          .select('event_id')
          .inFilter('event_id', eventIds)
          .inFilter('status', ['pending', 'confirmed']);

      final counts = <String, int>{};
      for (final r in seatRows as List) {
        final id = r['event_id'].toString();
        counts[id] = (counts[id] ?? 0) + 1;
      }

      if (!mounted) return;
      setState(() {
        _events = List<Map<String, dynamic>>.from(rows);
        _seatCounts = counts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  /// Returns true if the event is effectively over (past date or cancelled).
  bool _isOld(Map<String, dynamic> ev) {
    final status = (ev['status'] ?? '').toString();
    if (status == 'cancelled') return true;
    final dateStr = (ev['event_date'] ?? '').toString();
    if (dateStr.isEmpty) return false;
    final date = DateTime.tryParse(dateStr);
    return date != null && date.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kNavy,
        title: const Text('My Events',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/organizer/home'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadEvents,
          ),
        ],
      ),
      body: _buildBody(),
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

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text('Could not load events.\n$_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: kTextSub)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadEvents,
                style: ElevatedButton.styleFrom(backgroundColor: kNavy),
                child: const Text('Retry',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (_events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_busy, size: 64, color: kTextSub),
            const SizedBox(height: 16),
            const Text('No events yet',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kNavy)),
            const SizedBox(height: 8),
            const Text('Tap the + button to create your first event.',
                style: TextStyle(color: kTextSub)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/organizer/create-event'),
              icon: const Icon(Icons.add),
              label: const Text('Create Event'),
              style: ElevatedButton.styleFrom(backgroundColor: kAmber),
            ),
          ],
        ),
      );
    }

    // Split into active/upcoming and ended/cancelled
    final active = _events.where((e) => !_isOld(e)).toList();
    final old = _events.where((e) => _isOld(e)).toList();

    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Active / upcoming events ──────────────────────────────────
          if (active.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No upcoming events.',
                    style: TextStyle(color: kTextSub)),
              ),
            )
          else
            ...active.map((ev) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildCard(ev),
            )),

          // ── Ended / cancelled toggle ──────────────────────────────────
          if (old.isNotEmpty) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => setState(() => _showOld = !_showOld),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history, color: kTextSub, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      '${old.length} ended / cancelled event${old.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: kTextSub,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    Icon(
                      _showOld
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: kTextSub,
                    ),
                  ],
                ),
              ),
            ),
            if (_showOld) ...[
              const SizedBox(height: 10),
              ...old.map((ev) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildCard(ev, dimmed: true),
              )),
            ],
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> event, {bool dimmed = false}) {
    final eventId = event['event_id'].toString();
    final capacity = (event['capacity'] as num?)?.toInt() ?? 0;
    final registered = _seatCounts[eventId] ?? 0;
    return Opacity(
      opacity: dimmed ? 0.6 : 1.0,
      child: _EventCard(
        event: event,
        registered: registered,
        available: (capacity - registered).clamp(0, capacity),
        onTap: () => context.go('/organizer/event/$eventId'),
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
            _NavItem(icon: Icons.home_rounded, label: 'Home',
                selected: false, onTap: () => context.go('/organizer/home')),
            _NavItem(icon: Icons.calendar_month_outlined, label: 'My Events',
                selected: true, onTap: () {}),
            const SizedBox(width: 48),
            _NavItem(icon: Icons.bar_chart_rounded, label: 'Analytics',
                selected: false,
                onTap: () => context.go('/organizer/analytics')),
            _NavItem(icon: Icons.person_outline_rounded, label: 'Profile',
                selected: false,
                onTap: () => context.go('/organizer/profile')),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final int registered;
  final int available;
  final VoidCallback onTap;

  const _EventCard({
    required this.event,
    required this.registered,
    required this.available,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = (event['image_url'] ?? '').toString().trim();
    final name = (event['name'] ?? 'Untitled').toString();
    final date = (event['event_date'] ?? '').toString();
    final venue = (event['venue'] ?? '').toString();
    final club = (event['hosting_org'] ?? '').toString();
    final status = (event['status'] ?? 'active').toString();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius:
              const BorderRadius.horizontal(left: Radius.circular(16)),
              child: imageUrl.isEmpty
                  ? _placeholder()
                  : Image.network(
                imageUrl,
                width: 90,
                height: 110,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(),
                loadingBuilder: (_, child, progress) =>
                progress == null ? child : _placeholder(),
              ),
            ),
            // Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(name,
                            style: const TextStyle(
                                color: kNavy,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ),
                      // Pass eventDate so badge can show "Ended" for past events
                      StatusBadge(status: status, eventDate: date),
                    ]),
                    const SizedBox(height: 6),
                    _infoRow(Icons.calendar_today_outlined, date),
                    const SizedBox(height: 4),
                    _infoRow(Icons.location_on_outlined, venue),
                    const SizedBox(height: 4),
                    _infoRow(Icons.groups_outlined, club),
                    const SizedBox(height: 4),
                    // Registration count + seats left
                    Row(children: [
                      const Icon(Icons.how_to_reg_outlined,
                          size: 13, color: kTextSub),
                      const SizedBox(width: 4),
                      Text('$registered registered',
                          style: const TextStyle(
                              color: kTextSub, fontSize: 12)),
                      const SizedBox(width: 8),
                      Container(width: 1, height: 10, color: kBorder),
                      const SizedBox(width: 8),
                      Icon(Icons.event_seat_outlined,
                          size: 13,
                          color: available == 0
                              ? Colors.redAccent
                              : const Color(0xFF1A7A3A)),
                      const SizedBox(width: 4),
                      Text(
                        available == 0 ? 'Full' : '$available seats left',
                        style: TextStyle(
                          color: available == 0
                              ? Colors.redAccent
                              : const Color(0xFF1A7A3A),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 13, color: kTextSub),
      const SizedBox(width: 4),
      Flexible(
        child: Text(text,
            style: const TextStyle(color: kTextSub, fontSize: 12),
            overflow: TextOverflow.ellipsis),
      ),
    ],
  );

  Widget _placeholder() => Container(
    width: 90,
    height: 110,
    color: Colors.grey.shade200,
    child: const Icon(Icons.image_outlined, color: Colors.grey),
  );
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? kAmber : kTextSub;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight:
                  selected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
