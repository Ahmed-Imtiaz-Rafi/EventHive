import 'package:event_hive/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Organizer Profile Screen
/// Shows user info, affiliated clubs, event stats, and edit options.
/// Editable fields: full_name, phone, student_id, department_id, avatar_url.
class OrganizerProfileScreen extends StatefulWidget {
  const OrganizerProfileScreen({super.key});

  @override
  State<OrganizerProfileScreen> createState() => _OrganizerProfileScreenState();
}

class _OrganizerProfileScreenState extends State<OrganizerProfileScreen> {
  final _supabase = Supabase.instance.client;

  // User profile data
  Map<String, dynamic>? _profile;
  List<String> _clubs = [];
  List<Map<String, dynamic>> _departments = [];

  // Event stats
  int _totalEvents = 0;
  int _activeEvents = 0;
  int _endedEvents = 0;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  // Edit controllers
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _studentIdCtrl = TextEditingController();
  int? _selectedDeptId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _studentIdCtrl.dispose();
    super.dispose();
  }

  // ── Load all data ─────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not signed in.');

      // Load profile, departments, clubs, and event stats in parallel
      final results = await Future.wait([
        _supabase.from('users').select().eq('user_id', userId).single(),
        _supabase.from('departments').select('department_id, department_name').order('department_name'),
        _supabase
            .from('user_affiliation')
            .select('clubs(club_name)')
            .eq('user_id', userId),
        _supabase
            .from('event_organizer')
            .select('events(event_id, status, event_date)')
            .eq('user_id', userId),
      ]);

      final profile = Map<String, dynamic>.from(results[0] as Map);
      final depts = List<Map<String, dynamic>>.from(results[1] as List);
      final affRows = results[2] as List;
      final orgRows = results[3] as List;

      // Parse club names
      final clubs = affRows
          .map((r) => (r['clubs']?['club_name'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toList();

      // Compute event stats
      final today = DateTime.now();
      int total = 0, active = 0, ended = 0;
      for (final r in orgRows) {
        final ev = r['events'];
        if (ev == null) continue;
        total++;
        final status = (ev['status'] ?? '').toString();
        final dateStr = (ev['event_date'] ?? '').toString();
        final date = DateTime.tryParse(dateStr);
        if (status == 'cancelled' || (date != null && date.isBefore(today))) {
          ended++;
        } else {
          active++;
        }
      }

      if (!mounted) return;

      // Pre-fill edit controllers
      _fullNameCtrl.text = (profile['full_name'] ?? '').toString();
      _phoneCtrl.text = (profile['phone'] ?? '').toString();
      _studentIdCtrl.text = (profile['student_id'] ?? '').toString();
      _selectedDeptId = profile['department_id'] as int?;

      setState(() {
        _profile = profile;
        _departments = depts;
        _clubs = clubs;
        _totalEvents = total;
        _activeEvents = active;
        _endedEvents = ended;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Save profile changes ──────────────────────────────────────────────────

  Future<void> _save() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      await _supabase.from('users').update({
        'full_name': _fullNameCtrl.text.trim().isEmpty
            ? null
            : _fullNameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty
            ? null
            : _phoneCtrl.text.trim(),
        'student_id': _studentIdCtrl.text.trim().isEmpty
            ? null
            : _studentIdCtrl.text.trim(),
        'department_id': _selectedDeptId,
      }).eq('user_id', userId);

      _show('Profile updated.');
      await _load(); // refresh
    } catch (e) {
      _show('Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Upload avatar ─────────────────────────────────────────────────────────

  Future<void> _pickAndUploadAvatar() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
          source: ImageSource.gallery, imageQuality: 80);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last.toLowerCase();
      final path = '$userId/avatar.$ext';

      // Upload to 'avatars' bucket
      await _supabase.storage.from('avatars').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: 'image/$ext',
          upsert: true,
        ),
      );

      // Save path in users.avatar_url
      await _supabase
          .from('users')
          .update({'avatar_url': path}).eq('user_id', userId);

      _show('Profile picture updated.');
      await _load();
    } catch (e) {
      _show('Could not upload photo: $e');
    }
  }

  // ── Sign out ──────────────────────────────────────────────────────────────

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out?'),
        content: const Text('You will be returned to the login screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: kNavy),
            child: const Text('Sign Out',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _supabase.auth.signOut();
    if (mounted) context.go('/login');
  }

  void _show(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kNavy,
        title: const Text('Profile',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/organizer/home'),
        ),
        actions: [
          if (!_loading && _error == null)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Text('Save',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : _buildContent(),
    );
  }

  Widget _buildError() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
        const SizedBox(height: 12),
        Text(_error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: kTextSub)),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _load,
          style: ElevatedButton.styleFrom(backgroundColor: kNavy),
          child:
          const Text('Retry', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );

  Widget _buildContent() {
    final profile = _profile!;
    final username = (profile['username'] ?? '').toString();
    final email = (profile['email'] ?? '').toString();
    final avatarPath = (profile['avatar_url'] ?? '').toString().trim();
    final avatarUrl = avatarPath.isNotEmpty
        ? _supabase.storage.from('avatars').getPublicUrl(avatarPath)
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Avatar + name ───────────────────────────────────────────
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickAndUploadAvatar,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 52,
                        backgroundColor: kNavy.withValues(alpha: 0.12),
                        backgroundImage:
                        avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null
                            ? Text(
                          username.isNotEmpty
                              ? username[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: kNavy),
                        )
                            : null,
                      ),
                      // Camera icon badge
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: kAmber,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt,
                            color: Colors.white, size: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _fullNameCtrl.text.isNotEmpty
                      ? _fullNameCtrl.text
                      : username,
                  style: const TextStyle(
                      color: kNavy,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(email,
                    style: const TextStyle(color: kTextSub, fontSize: 13)),
                const SizedBox(height: 4),
                // Organizer badge
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: kNavy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Organizer',
                      style: TextStyle(
                          color: kNavy,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Event stats ─────────────────────────────────────────────
          Row(children: [
            Expanded(child: _statCard('Total Events', _totalEvents.toString(),
                Icons.event_outlined, kNavy)),
            const SizedBox(width: 10),
            Expanded(child: _statCard('Active', _activeEvents.toString(),
                Icons.check_circle_outline, const Color(0xFF1A7A3A))),
            const SizedBox(width: 10),
            Expanded(child: _statCard('Ended', _endedEvents.toString(),
                Icons.history, kAmber)),
          ]),

          const SizedBox(height: 20),

          // ── Editable info ───────────────────────────────────────────
          _sectionTitle('Personal Information'),
          const SizedBox(height: 10),
          _card(children: [
            _editRow(
              icon: Icons.badge_outlined,
              label: 'Full Name',
              hint: 'Your display name',
              controller: _fullNameCtrl,
            ),
            _divider(),
            _editRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              hint: 'e.g. 01XXXXXXXXX',
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
            ),
            _divider(),
            _editRow(
              icon: Icons.school_outlined,
              label: 'Student ID',
              hint: 'Your student ID',
              controller: _studentIdCtrl,
            ),
            _divider(),
            // Department dropdown
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_outlined,
                      color: kNavy, size: 18),
                  const SizedBox(width: 12),
                  const SizedBox(
                    width: 90,
                    child: Text('Department',
                        style: TextStyle(
                            color: kTextSub,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedDeptId,
                        isExpanded: true,
                        hint: const Text('Select',
                            style:
                            TextStyle(color: kTextSub, fontSize: 13)),
                        style: const TextStyle(
                            color: kTextMain, fontSize: 13),
                        items: _departments.map((d) {
                          return DropdownMenuItem<int>(
                            value: d['department_id'] as int,
                            child: Text(d['department_name'].toString()),
                          );
                        }).toList(),
                        onChanged: (v) =>
                            setState(() => _selectedDeptId = v),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]),

          const SizedBox(height: 20),

          // ── Read-only info ──────────────────────────────────────────
          _sectionTitle('Account'),
          const SizedBox(height: 10),
          _card(children: [
            _readRow(Icons.alternate_email, 'Username', '@$username'),
            _divider(),
            _readRow(Icons.email_outlined, 'Email', email),
          ]),

          const SizedBox(height: 20),

          // ── Club affiliations ───────────────────────────────────────
          if (_clubs.isNotEmpty) ...[
            _sectionTitle('Club Affiliations'),
            const SizedBox(height: 10),
            _card(children: [
              ..._clubs.asMap().entries.map((entry) {
                final isLast = entry.key == _clubs.length - 1;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: kBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.groups_outlined,
                              color: kNavy, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Text(entry.value,
                            style: const TextStyle(
                                color: kTextMain,
                                fontSize: 14,
                                fontWeight: FontWeight.w500)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4F4DD),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Verified',
                              style: TextStyle(
                                  color: Color(0xFF1A7A3A),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ]),
                    ),
                    if (!isLast) _divider(),
                  ],
                );
              }),
            ]),
            const SizedBox(height: 20),
          ],

          // ── Sign out ────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: const Text('Sign Out',
                  style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Reusable widgets ──────────────────────────────────────────────────────

  Widget _sectionTitle(String text) => Text(text,
      style: const TextStyle(
          color: kNavy, fontSize: 15, fontWeight: FontWeight.bold));

  Widget _card({required List<Widget> children}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
        crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  Widget _divider() =>
      const Divider(height: 1, color: kBorder);

  /// An editable row — label on the left, text field on the right.
  Widget _editRow({
    required IconData icon,
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, color: kNavy, size: 18),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    color: kTextSub,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, color: kTextMain),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle:
                const TextStyle(color: kBorder, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ]),
      );

  /// A read-only info row.
  Widget _readRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(children: [
      Icon(icon, color: kNavy, size: 18),
      const SizedBox(width: 12),
      SizedBox(
        width: 90,
        child: Text(label,
            style: const TextStyle(
                color: kTextSub,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ),
      Expanded(
        child: Text(value,
            textAlign: TextAlign.right,
            style: const TextStyle(
                color: kTextMain,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ),
    ]),
  );

  /// A small stat card for the event summary row.
  Widget _statCard(String label, String value, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
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
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style:
              const TextStyle(color: kTextSub, fontSize: 11)),
        ]),
      );
}
