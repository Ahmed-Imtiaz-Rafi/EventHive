
import 'package:event_hive/core/theme/app_theme.dart';
import 'package:event_hive/widgets/common/status_badge_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Holds event data fetched from Supabase.
class _EventItem {
  final String title;
  final String date;
  final String location;
  final String status;
  final int registered;
  final int capacity;
  final String imageUrl;
  final String eventId;

  const _EventItem({
    required this.title,
    required this.date,
    required this.location,
    required this.status,
    required this.registered,
    required this.capacity,
    required this.imageUrl,
    required this.eventId,
  });
}

class OrganizerHomeScreen extends StatefulWidget {
  const OrganizerHomeScreen({super.key});

  @override
  State<OrganizerHomeScreen> createState() =>
      _OrganizerHomeScreenState();
}

class _OrganizerHomeScreenState extends State<OrganizerHomeScreen> {
  // Tracks the selected bottom navigation item.
  int _selectedTab = 0;

  // Controls event search.
  final TextEditingController _searchCtrl =
  TextEditingController();

  // Stores all events loaded from Supabase.
  List<_EventItem> _events = [];

  // Stores events filtered by search.
  List<_EventItem> _filteredEvents = [];

  // Shows a loader while events are being fetched.
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _searchCtrl.addListener(_onSearchChanged);
    _loadEvents();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Fetches events, including each event's own image URL.
  Future<void> _loadEvents() async {
    try {
      final data = await Supabase.instance.client
          .from('events')
          .select()
          .order('event_date', ascending: true);

      final events = data.map<_EventItem>((event) {
        return _EventItem(
          eventId: (event['event_id'] ?? '').toString(),
          title: (event['name'] ?? '').toString(),
          date: (event['event_date'] ?? '').toString(),
          location: (event['venue'] ?? '').toString(),
          status: (event['status'] ?? 'unknown').toString(),
          registered: 0,
          capacity:
          (event['capacity'] as num?)?.toInt() ?? 0,

          // Uses the URL saved in this event's image_url column.
          imageUrl: (event['image_url'] ?? '').toString().trim(),
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        _events = events;
        _filteredEvents = events;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      debugPrint('Error loading events: $e');
    }
  }

  // Filters events whenever the user types in the search field.
  void _onSearchChanged() {
    final query = _searchCtrl.text.trim().toLowerCase();

    setState(() {
      _filteredEvents = _events
          .where(
            (event) => event.title.toLowerCase().contains(query),
      )
          .toList();
    });
  }

  // Opens the screen associated with the selected navigation item.
  void _onTabTapped(int index) {
    setState(() => _selectedTab = index);

    switch (index) {
      case 0:
        context.go('/organizer/home');
        break;
      case 1:
        context.go('/organizer/my-events');
        break;
      case 3:
        context.go('/organizer/analytics');
        break;
      case 4:
        context.go('/organizer/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNavy,
      body: CustomScrollView(
        slivers: [
          // Navy header with greeting, notification and search.
          SliverToBoxAdapter(
            child: _buildHeader(context),
          ),

          // White section containing the event list.
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: _buildEventsSection(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),

      // Opens the Create Event screen.
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            context.go('/organizer/create-event'),
        backgroundColor: kAmber,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.add,
          color: Colors.white,
          size: 28,
        ),
      ),
      floatingActionButtonLocation:
      FloatingActionButtonLocation.centerDocked,
    );
  }

  // Builds the top navy header.
  Widget _buildHeader(BuildContext context) {
    return Container(
      color: kNavy,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 12,
        20,
        20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting and notification icon.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good morning,',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'Event Organizer',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        '👋',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Search events by title.
          TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search your events...',
              hintStyle: const TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: Colors.white54,
                size: 20,
              ),
              filled: true,
              fillColor: Colors.white12,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Opens Create Event screen.
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () {
                context.go('/organizer/create-event');
              },
              icon: const Icon(
                Icons.add,
                color: Colors.white,
                size: 18,
              ),
              label: const Text(
                'Create Event',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kAmber,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Builds the My Events section.
  Widget _buildEventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Events',
                style: TextStyle(
                  color: kNavy,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  context.go('/organizer/my-events');
                },
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: kNavy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Loading state.
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          )

        // Empty state.
        else if (_filteredEvents.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                'No events found.',
                style: TextStyle(color: kTextSub),
              ),
            ),
          )

        // Displays events fetched from Supabase.
        else
          ...List.generate(_filteredEvents.length, (index) {
            final event = _filteredEvents[index];

            return Column(
              children: [
                _EventCard(
                  event: event,
                  onTap: () {
                    context.go(
                      '/organizer/event/${event.eventId}',
                    );
                  },
                ),
                if (index < _filteredEvents.length - 1)
                  const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
              ],
            );
          }),

        const SizedBox(height: 24),
      ],
    );
  }

  // Builds the bottom navigation bar.
  Widget _buildBottomNav() {
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
              selected: _selectedTab == 0,
              onTap: () => _onTabTapped(0),
            ),
            _NavItem(
              icon: Icons.calendar_month_outlined,
              label: 'My Events',
              selected: _selectedTab == 1,
              onTap: () => _onTabTapped(1),
            ),

            // Leaves space for the center Create Event button.
            const SizedBox(width: 48),

            _NavItem(
              icon: Icons.bar_chart_rounded,
              label: 'Analytics',
              selected: _selectedTab == 3,
              onTap: () => _onTabTapped(3),
            ),
            _NavItem(
              icon: Icons.person_outline_rounded,
              label: 'Profile',
              selected: _selectedTab == 4,
              onTap: () => _onTabTapped(4),
            ),
          ],
        ),
      ),
    );
  }
}

// Displays one event and its image.
class _EventCard extends StatelessWidget {
  final _EventItem event;
  final VoidCallback onTap;

  const _EventCard({
    required this.event,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Loads this event's image from its own image URL.
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: event.imageUrl.isEmpty
                  ? _imagePlaceholder()
                  : Image.network(
                event.imageUrl,
                width: 78,
                height: 78,
                fit: BoxFit.cover,
                loadingBuilder: (
                    context,
                    child,
                    progress,
                    ) {
                  if (progress == null) return child;

                  return _imagePlaceholder();
                },
                errorBuilder: (
                    context,
                    error,
                    stackTrace,
                    ) {
                  return _imagePlaceholder();
                },
              ),
            ),
            const SizedBox(width: 12),

            // Displays the event information.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: const TextStyle(
                            color: kNavy,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: kTextSub,
                        size: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        event.date,
                        style: const TextStyle(
                          color: kTextSub,
                          fontSize: 12,
                        ),
                      ),
                      const Text(
                        '  •  ',
                        style: TextStyle(
                          color: kTextSub,
                          fontSize: 12,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          event.location,
                          style: const TextStyle(
                            color: kTextSub,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  StatusBadge(status: event.status),
                  const SizedBox(height: 5),
                  Text(
                    '${event.registered} / ${event.capacity} registered',
                    style: const TextStyle(
                      color: kTextSub,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Shows a placeholder when an image is missing or unavailable.
  Widget _imagePlaceholder() {
    return Container(
      width: 78,
      height: 78,
      color: Colors.grey.shade200,
      child: const Icon(
        Icons.image_outlined,
        color: Colors.grey,
      ),
    );
  }
}

// One item in the bottom navigation bar.
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
          Icon(
            icon,
            color: color,
            size: 22,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight:
              selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
