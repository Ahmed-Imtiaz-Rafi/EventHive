import 'package:event_hive/core/theme/app_theme.dart';
import 'package:event_hive/widgets/common/status_badge_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only event detail screen.
/// Shown when an organizer taps an event on the Home screen.
/// No edit or manage actions — just information about the event.
class EventDetailScreen extends StatefulWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? _event;
  List<String> _categories = [];
  List<Map<String, dynamic>> _roles = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  Future<void> _loadEvent() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Fetch the event row
      final row = await _supabase
          .from('events')
          .select()
          .eq('event_id', widget.eventId)
          .single();

      // Fetch categories
      final catRows = await _supabase
          .from('event_category_map')
          .select('event_categories(category_name)')
          .eq('event_id', widget.eventId);

      final cats = (catRows as List)
          .map((r) =>
          (r['event_categories']?['category_name'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toList();

      // Fetch role prices
      final roleRows = await _supabase
          .from('event_role_price')
          .select('role_name, price')
          .eq('event_id', widget.eventId);

      if (!mounted) return;
      setState(() {
        _event = Map<String, dynamic>.from(row);
        _categories = cats;
        _roles = List<Map<String, dynamic>>.from(roleRows);
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
          onPressed: () => context.go('/organizer/home'),
        ),
      ),
      body: _buildBody(),
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
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text(
                'Could not load event.\n$_error',
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
        ),
      );
    }

    if (_event == null) return const SizedBox.shrink();

    final ev = _event!;
    final imageUrl = (ev['image_url'] ?? '').toString().trim();
    final name = (ev['name'] ?? 'Untitled').toString();
    final date = (ev['event_date'] ?? '').toString();
    final venue = (ev['venue'] ?? '').toString();
    final club = (ev['hosting_org'] ?? '').toString();
    final status = (ev['status'] ?? 'active').toString();
    final capacity = (ev['capacity'] as num?)?.toInt() ?? 0;
    final description = (ev['description'] ?? '').toString().trim();
    final startTime = (ev['start_time'] ?? '').toString();
    final endTime = (ev['end_time'] ?? '').toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event image
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            )
          else
            Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.event, size: 64, color: Colors.grey),
            ),

          const SizedBox(height: 16),

          // Name + status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: kNavy,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: status),
            ],
          ),

          const SizedBox(height: 16),

          // Info card
          _infoCard([
            _infoRow(Icons.calendar_today_outlined, 'Date', date),
            if (startTime.isNotEmpty)
              _infoRow(Icons.access_time_outlined, 'Time',
                  endTime.isNotEmpty ? '$startTime – $endTime' : startTime),
            _infoRow(Icons.location_on_outlined, 'Venue', venue),
            _infoRow(Icons.groups_outlined, 'Hosted by', club),
            _infoRow(Icons.people_outline, 'Capacity', '$capacity seats'),
          ]),

          // Categories
          if (_categories.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionTitle('Categories'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _categories
                  .map(
                    (cat) => Chip(
                  label: Text(cat,
                      style: const TextStyle(
                          fontSize: 12, color: kNavy)),
                  backgroundColor: kNavy.withValues(alpha: 0.08),
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              )
                  .toList(),
            ),
          ],

          // Description
          if (description.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionTitle('Description'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorder),
              ),
              child: Text(
                description,
                style: const TextStyle(
                    fontSize: 14, color: kTextMain, height: 1.5),
              ),
            ),
          ],

          // Role prices
          if (_roles.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionTitle('Registration Roles'),
            const SizedBox(height: 8),
            _infoCard(
              _roles.map((r) {
                final price = (r['price'] as num?)?.toDouble() ?? 0;
                return _infoRow(
                  Icons.badge_outlined,
                  r['role_name'].toString(),
                  price == 0 ? 'Free' : '৳${price.toStringAsFixed(0)}',
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: kNavy,
      ),
    );
  }

  Widget _infoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children
            .expand((w) => [w, const Divider(height: 1)])
            .toList()
          ..removeLast(), // remove last divider
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: kNavy),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: kTextSub,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                color: kTextMain,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
