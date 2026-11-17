import 'package:event_hive/core/theme/app_theme.dart';
import 'package:event_hive/widgets/common/status_badge_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shows all events that belong to the signed-in organizer.
/// Events are identified via the event_organizer table, which links
/// a user_id to the event_ids they manage.
class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  /// Fetches the current organizer's events by joining event_organizer → events.
  /// Only events linked to the signed-in user appear here.
  Future<void> _loadEvents() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not signed in.');

      // Step 1: get event IDs this organizer owns
      final orgRows = await _supabase
          .from('event_organizer')
          .select('event_id')
          .eq('user_id', userId);

      final eventIds = (orgRows as List)
          .map((r) => r['event_id'].toString())
          .toList();

      if (eventIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _events = [];
          _loading = false;
        });
        return;
      }

      // Step 2: fetch full event rows for those IDs
      final rows = await _supabase
          .from('events')
          .select()
          .inFilter('event_id', eventIds)
          .order('event_date', ascending: false);

      if (!mounted) return;
      setState(() {
        _events = List<Map<String, dynamic>>.from(rows);
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
          'My Events',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/organizer/home'),
        ),
        actions: [
          // Pull-to-refresh button in the app bar
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                'Could not load events.\n$_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: kTextSub),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadEvents,
                style: ElevatedButton.styleFrom(backgroundColor: kNavy),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
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
            const Text(
              'No events yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kNavy,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the + button to create your first event.',
              style: TextStyle(color: kTextSub),
            ),
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

    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _events.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final event = _events[index];
          return _EventCard(
            event: event,
            // Tapping a card opens the Event Details / Manage screen
            onTap: () => context.go('/organizer/event/${event['event_id']}'),
          );
        },
      ),
    );
  }

  // Bottom nav — My Events tab highlighted
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
              selected: false,
              onTap: () => context.go('/organizer/home'),
            ),
            _NavItem(
              icon: Icons.calendar_month_outlined,
              label: 'My Events',
              selected: true, // this tab is active
              onTap: () {},
            ),
            const SizedBox(width: 48),
            _NavItem(
              icon: Icons.bar_chart_rounded,
              label: 'Analytics',
              selected: false,
              onTap: () => context.go('/organizer/analytics'),
            ),
            _NavItem(
              icon: Icons.person_outline_rounded,
              label: 'Profile',
              selected: false,
              onTap: () => context.go('/organizer/profile'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A card showing one event's image, name, date, venue, club, and status.
class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onTap;

  const _EventCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final imageUrl = (event['image_url'] ?? '').toString().trim();
    final name = (event['name'] ?? 'Untitled').toString();
    final date = (event['event_date'] ?? '').toString();
    final venue = (event['venue'] ?? '').toString();
    final club = (event['hosting_org'] ?? '').toString();
    final status = (event['status'] ?? 'active').toString();
    final capacity = (event['capacity'] as num?)?.toInt() ?? 0;

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
            // Event thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
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
            // Event details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
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
                              fontSize: 14,
                            ),
                          ),
                        ),
                        StatusBadge(status: status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _infoRow(Icons.calendar_today_outlined, date),
                    const SizedBox(height: 4),
                    _infoRow(Icons.location_on_outlined, venue),
                    const SizedBox(height: 4),
                    _infoRow(Icons.groups_outlined, club),
                    const SizedBox(height: 4),
                    _infoRow(Icons.people_outline, 'Capacity: $capacity'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 13, color: kTextSub),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(color: kTextSub, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

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
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
