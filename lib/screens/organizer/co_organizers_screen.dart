import 'package:event_hive/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Screen 9 — Co-organizers
/// Shows everyone linked to this event via event_organizer.
/// The main organizer (current user) is shown at the top.
/// Others can be removed by the main organizer.
/// Adding: enter a username → look up the user → insert into event_organizer.
class CoOrganizersScreen extends StatefulWidget {
  final String eventId;
  const CoOrganizersScreen({super.key, required this.eventId});

  @override
  State<CoOrganizersScreen> createState() => _CoOrganizersScreenState();
}

class _CoOrganizersScreenState extends State<CoOrganizersScreen> {
  final _supabase = Supabase.instance.client;
  final _usernameCtrl = TextEditingController();

  List<Map<String, dynamic>> _organizers = []; // {user_id, username, avatar_url}
  bool _loading = true;
  bool _adding = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _supabase.auth.currentUser?.id;
    _load();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  /// Loads all organizers for this event joined with their user profile.
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Join event_organizer → users to get username and avatar
      final rows = await _supabase
          .from('event_organizer')
          .select('user_id, users(username, avatar_url)')
          .eq('event_id', widget.eventId);

      if (!mounted) return;
      setState(() {
        _organizers = (rows as List).map((r) {
          final u = r['users'] as Map<String, dynamic>? ?? {};
          return {
            'user_id': r['user_id'].toString(),
            'username': u['username']?.toString() ?? 'Unknown',
            'avatar_url': u['avatar_url']?.toString() ?? '',
          };
        }).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _show('Failed to load co-organizers: $e');
    }
  }

  /// Looks up a user by username and adds them to event_organizer.
  /// Only the main organizer (current user who created the event) can add.
  Future<void> _add() async {
    final username = _usernameCtrl.text.trim();
    if (username.isEmpty) return;

    setState(() => _adding = true);
    try {
      // Find user by username (case-insensitive)
      final userRow = await _supabase
          .from('users')
          .select('user_id, username')
          .ilike('username', username)
          .maybeSingle();

      if (userRow == null) {
        _show('User "$username" not found.');
        return;
      }

      final newUserId = userRow['user_id'].toString();

      // Check not already added
      if (_organizers.any((o) => o['user_id'] == newUserId)) {
        _show('This user is already a co-organizer.');
        return;
      }

      // Insert into event_organizer
      await _supabase.from('event_organizer').insert({
        'event_id': widget.eventId,
        'user_id': newUserId,
      });

      _usernameCtrl.clear();
      _show('Co-organizer added.');
      await _load(); // refresh list
    } catch (e) {
      _show('Failed to add: $e');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  /// Removes a co-organizer from event_organizer.
  /// The main organizer (current user) cannot remove themselves.
  Future<void> _remove(String userId) async {
    if (userId == _currentUserId) {
      _show('You cannot remove yourself.');
      return;
    }
    try {
      await _supabase
          .from('event_organizer')
          .delete()
          .eq('event_id', widget.eventId)
          .eq('user_id', userId);
      _show('Co-organizer removed.');
      await _load();
    } catch (e) {
      _show('Failed to remove: $e');
    }
  }

  void _show(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kNavy,
        title: const Text('Co-organizers',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/organizer/event/${widget.eventId}'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Add co-organizer
            _card(children: [
              const Text('Add Co-organizer',
                  style: TextStyle(
                      color: kNavy,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _usernameCtrl,
                    style: const TextStyle(fontSize: 14, color: kTextMain),
                    decoration: InputDecoration(
                      hintText: 'Enter username',
                      hintStyle:
                      const TextStyle(color: kTextSub, fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                          const BorderSide(color: kBorder)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                          const BorderSide(color: kBorder)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: kNavy, width: 1.5)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _adding ? null : _add,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kNavy,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _adding
                        ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                        : const Text('Add',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              const Text(
                'Co-organizers can view registrations and send notifications.',
                style: TextStyle(color: kTextSub, fontSize: 12),
              ),
            ]),

            const SizedBox(height: 16),

            // ── Organizer list
            _card(children: [
              const Text('Organizers',
                  style: TextStyle(
                      color: kNavy,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              const SizedBox(height: 8),
              if (_organizers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No organizers found.',
                      style: TextStyle(color: kTextSub)),
                )
              else
                ..._organizers.map((o) {
                  final isMe = o['user_id'] == _currentUserId;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: kBg,
                      // Show avatar if available, else initials
                      child: Text(
                        (o['username'] as String)
                            .substring(0, 1)
                            .toUpperCase(),
                        style: const TextStyle(
                            color: kNavy, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(o['username'],
                        style: const TextStyle(
                            color: kNavy,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    subtitle: Text(
                      isMe ? 'Main Organizer · Full Access' : 'Co-organizer',
                      style: const TextStyle(
                          color: kTextSub, fontSize: 12),
                    ),
                    // Main organizer gets a crown; co-organizers get remove button
                    trailing: isMe
                        ? const Icon(Icons.star_rounded,
                        color: kAmber, size: 22)
                        : TextButton(
                      onPressed: () => _remove(o['user_id']),
                      child: const Text('Remove',
                          style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13)),
                    ),
                  );
                }),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2))
      ],
    ),
    child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );
}
