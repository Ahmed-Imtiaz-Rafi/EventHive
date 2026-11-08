import 'package:event_hive/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Screen 8 — Notify Attendees
/// Organizer picks an audience and sends an announcement via send_announcement() RPC.
class NotifyAttendeesScreen extends StatefulWidget {
  final String eventId;
  const NotifyAttendeesScreen({super.key, required this.eventId});

  @override
  State<NotifyAttendeesScreen> createState() => _NotifyAttendeesScreenState();
}

class _NotifyAttendeesScreenState extends State<NotifyAttendeesScreen> {
  final _supabase = Supabase.instance.client;
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  // Who receives the announcement: participants, organizers, or both
  String _audience = 'participants';
  bool _sending = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  /// Calls the send_announcement() RPC with scope='event'.
  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();

    if (title.isEmpty || body.isEmpty) {
      _show('Please enter both a title and a message.');
      return;
    }

    setState(() => _sending = true);
    try {
      await _supabase.rpc('send_announcement', params: {
        'p_scope': 'event',
        'p_event_id': widget.eventId,
        'p_club_id': null,
        'p_audience': _audience,
        'p_title': title,
        'p_body': body,
      });
      if (!mounted) return;
      _show('Notification sent!');
      _titleCtrl.clear();
      _bodyCtrl.clear();
    } catch (e) {
      _show('Failed to send: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
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
        title: const Text('Notify Attendees',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/organizer/event/${widget.eventId}'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Send To
            _card(children: [
              const Text('Send To',
                  style: TextStyle(
                      color: kNavy,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              const SizedBox(height: 12),
              // Audience picker — three options
              ...[
                ('participants', 'All Registered Attendees'),
                ('organizers', 'Co-organizers Only'),
                ('both', 'Everyone'),
              ].map((opt) => RadioListTile<String>(
                value: opt.$1,
                groupValue: _audience,
                title: Text(opt.$2,
                    style: const TextStyle(fontSize: 14, color: kTextMain)),
                activeColor: kNavy,
                dense: true,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _audience = v!),
              )),
            ]),

            const SizedBox(height: 16),

            // ── Message
            _card(children: [
              const Text('Message',
                  style: TextStyle(
                      color: kNavy,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              const SizedBox(height: 12),
              _field(_titleCtrl, 'Title', 1, 120),
              const SizedBox(height: 12),
              _field(_bodyCtrl, 'Type your message here...', 5, 2000),
            ]),

            const SizedBox(height: 16),

            // ── Quick Templates
            _card(children: [
              const Text('Quick Templates',
                  style: TextStyle(
                      color: kNavy,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _template('Event Update',
                      'Important update about the event details.'),
                  _template('Venue Change', 'The venue has been changed.'),
                  _template(
                      'Reminder', 'Don\'t forget — the event is tomorrow!'),
                  _template('Thank You',
                      'Thank you for attending! We hope to see you again.'),
                ],
              ),
            ]),

            const SizedBox(height: 24),

            // ── Send button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_outlined, color: Colors.white),
                label: Text(
                  _sending ? 'Sending...' : 'Send Notification',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kNavy,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A white rounded card that wraps its children.
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

  /// Reusable text field with a character limit.
  Widget _field(
      TextEditingController ctrl, String hint, int lines, int maxLen) =>
      TextFormField(
        controller: ctrl,
        maxLines: lines,
        maxLength: maxLen,
        style: const TextStyle(fontSize: 14, color: kTextMain),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: kTextSub, fontSize: 13),
          contentPadding: const EdgeInsets.all(14),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kBorder)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kBorder)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kNavy, width: 1.5)),
        ),
      );

  /// Tapping a template fills in the title and body fields.
  Widget _template(String label, String body) => ActionChip(
    label: Text(label, style: const TextStyle(fontSize: 12, color: kNavy)),
    backgroundColor: kBg,
    side: BorderSide.none,
    onPressed: () {
      _titleCtrl.text = label;
      _bodyCtrl.text = body;
    },
  );
}
