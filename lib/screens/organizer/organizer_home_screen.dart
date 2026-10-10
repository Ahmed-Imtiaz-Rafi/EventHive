import 'package:event_hive/core/theme/app_theme.dart';
import 'package:event_hive/widgets/common/status_badge_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


// Event model used to keep Supabase event data organized
// before showing it in the UI.
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
  State<OrganizerHomeScreen> createState() => _OrganizerHomeScreenState();
}


class _OrganizerHomeScreenState extends State<OrganizerHomeScreen> {
  // Keeps track of the selected bottom navigation tab.
  int _selectedTab = 0;

  // Controls the event search field.
  final TextEditingController _searchCtrl = TextEditingController();

  // Stores events loaded from Supabase.
  List<_EventItem> _events = [];

  // Stores events currently visible after searching.
  List<_EventItem> _filteredEvents = [];

  // Shows loading indicator while events are being fetched.
  bool _isLoading = true;


  @override
  void initState() {
    super.initState();

    // Updates the event list whenever the search text changes.
    _searchCtrl.addListener(_onSearchChanged);

    // Loads events from Supabase when the screen opens.
    _loadEvents();
  }


  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }


  // Fetches event data from the Supabase events table.
  Future<void> _loadEvents() async {
    try {
      final data = await Supabase.instance.client
          .from('events')
          .select()
          .order('event_date', ascending: true);

      final events = data.map<_EventItem>((event) {
        return _EventItem(
          eventId: event['event_id'].toString(),
          title: event['name'] ?? '',
          date: event['event_date'].toString(),
          location: event['venue'] ?? '',
          status: event['status'].toString(),
          registered: 0,
          capacity: event['capacity'] ?? 0,
          imageUrl:
          'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=200',
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


  // Filters the event list based on the search text.
  void _onSearchChanged() {
    final query = _searchCtrl.text.toLowerCase();

    setState(() {
      _filteredEvents = _events
          .where(
            (event) => event.title.toLowerCase().contains(query),
      )
          .toList();
    });
  }


  // Handles bottom navigation and opens the related screen.
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
          // Header contains greeting, notification and search.
          SliverToBoxAdapter(
            child: _buildHeader(context),
          ),

          // White container contains the event list.
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
        onPressed: () => context.go('/organizer/create-event'),
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


  // Builds the top navy header section.
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

          // Greeting and notification section.
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

              // Notification icon.
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

                  // Small red notification indicator.
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

          // Search events.
          TextField(
            controller: _searchCtrl,

            style: const TextStyle(
              color: Colors.white,
            ),

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
          padding: const EdgeInsets.fromLTRB(
            20,
            20,
            16,
            12,
          ),

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

        // Shows loading indicator while Supabase data is loading.
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(40),

            child: Center(
              child: CircularProgressIndicator(),
            ),
          )

        // Shows message when no events are available.
        else if (_filteredEvents.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),

            child: Center(
              child: Text(
                'No events found.',
                style: TextStyle(
                  color: kTextSub,
                ),
              ),
            ),
          )

        // Shows events fetched from Supabase.
        else
          ...List.generate(
            _filteredEvents.length,
                (index) {
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
            },
          ),

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

            // Space for the center FAB.
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


// Single event card used to display an event.
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
        padding: const EdgeInsets.symmetric(
          vertical: 12,
        ),

        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            // Event thumbnail.
            ClipRRect(
              borderRadius: BorderRadius.circular(10),

              child: Image.network(
                event.imageUrl,

                width: 78,
                height: 78,

                fit: BoxFit.cover,

                loadingBuilder: (
                    context,
                    child,
                    progress,
                    ) {
                  return progress == null
                      ? child
                      : Container(
                    width: 78,
                    height: 78,
                    color: Colors.grey.shade200,
                  );
                },

                errorBuilder: (
                    context,
                    error,
                    stackTrace,
                    ) {
                  return Container(
                    width: 78,
                    height: 78,

                    color: Colors.grey.shade200,

                    child: const Icon(
                      Icons.image_outlined,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),

            const SizedBox(width: 12),

            // Event information.
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

                  StatusBadge(
                    status: event.status,
                  ),

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
}


// Single bottom navigation item.
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