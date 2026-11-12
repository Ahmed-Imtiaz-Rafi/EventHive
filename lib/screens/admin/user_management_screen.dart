import 'package:event_hive/core/theme/admin/admin_theme.dart';
import 'package:event_hive/widgets/admin/admin_widgets.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// User oversight: read-only directory, Participant / Organizer / Admin tabs.
/// A user appears under their highest role (admin > organizer > participant).
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _supabase = Supabase.instance.client;

  static const _columns =
      'user_id, username, full_name, email, phone, '
      'student_id, avatar_url, created_at, departments(department_name), '
      'user_role(role), user_affiliation(clubs(club_name))';

  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  bool _failed = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Supabase returns at most 1000 rows per request, so read in pages.
  Future<void> _load() async {
    try {
      const page = 1000;
      final all = <Map<String, dynamic>>[];
      var from = 0;
      while (true) {
        final rows = await _supabase
            .from('users')
            .select(_columns)
            .order('created_at', ascending: false)
            .order('user_id')
            .range(from, from + page - 1);
        all.addAll(List<Map<String, dynamic>>.from(rows));
        if (rows.length < page) break;
        from += page;
      }
      if (!mounted) return;
      setState(() {
        _users = all;
        _loading = false;
        _failed = false;
      });
    } catch (e) {
      debugPrint('User oversight load error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  String _roleOf(Map<String, dynamic> u) {
    final roles = ((u['user_role'] as List?) ?? [])
        .map((r) => (r as Map)['role'])
        .toSet();
    if (roles.contains('admin')) return 'admin';
    if (roles.contains('organizer')) return 'organizer';
    return 'participant';
  }

  bool _matches(Map<String, dynamic> u) {
    if (_query.isEmpty) return true;
    final hay =
        '${u['username']} ${u['full_name']} ${u['email']} '
                '${u['student_id']}'
            .toLowerCase();
    return hay.contains(_query);
  }

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    final shown = _users.where(_matches).toList();
    List<Map<String, dynamic>> role(String r) =>
        shown.where((u) => _roleOf(u) == r).toList();
    final participants = role('participant');
    final organizers = role('organizer');
    final admins = role('admin');

    String label(String name, List list) =>
        _loading ? name : '$name (${list.length})';

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              const AdminHeader(
                title: 'User oversight',
                subtitle: 'Everyone using EventHive (read-only)',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: AdminSearchField(
                  hint: 'Search name, email or student ID',
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                ),
              ),
              AdminTabBar(
                labels: [
                  label('Participant', participants),
                  label('Organizer', organizers),
                  label('Admin', admins),
                ],
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : _failed
                    ? AdminMessage(
                        icon: Icons.cloud_off_outlined,
                        text: 'Could not load users.',
                        actionLabel: 'Retry',
                        onAction: () {
                          setState(() => _loading = true);
                          _load();
                        },
                      )
                    : TabBarView(
                        children: [
                          _list(participants, 'No participants found.'),
                          _list(organizers, 'No organizers found.'),
                          _list(admins, 'No admins found.'),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(List<Map<String, dynamic>> items, String empty) {
    return AdminRefreshList(
      onRefresh: _load,
      itemCount: items.length,
      emptyText: empty,
      emptyIcon: Icons.person_search_outlined,
      itemBuilder: (_, i) => _UserCard(
        user: items[i],
        role: _roleOf(items[i]),
        onTap: () => _showDetails(items[i]),
      ),
    );
  }

  void _showDetails(Map<String, dynamic> u) {
    final c = AdminColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _UserSheet(user: u, role: _roleOf(u)),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final String role;
  final VoidCallback onTap;
  const _UserCard({
    required this.user,
    required this.role,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    final t = Theme.of(context).textTheme;
    final name = adminName(user);
    final studentId = (user['student_id'] ?? '').toString();
    final dept = ((user['departments'] as Map?)?['department_name'] ?? '')
        .toString();
    final line2 = [
      '@${user['username']}',
      if (studentId.isNotEmpty) studentId,
    ].join('  ·  ');

    return AdminCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          AdminAvatar(path: user['avatar_url'] as String?, name: name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
                Text(
                  line2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySmall?.copyWith(color: c.muted),
                ),
                if (dept.isNotEmpty)
                  Text(
                    dept,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(color: c.muted),
                  ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.muted),
        ],
      ),
    );
  }
}

class _UserSheet extends StatelessWidget {
  final Map<String, dynamic> user;
  final String role;
  const _UserSheet({required this.user, required this.role});

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    final t = Theme.of(context).textTheme;
    final name = adminName(user);
    final dept = ((user['departments'] as Map?)?['department_name'] ?? '')
        .toString();
    final joined = DateTime.tryParse('${user['created_at'] ?? ''}')?.toLocal();
    final clubs = ((user['user_affiliation'] as List?) ?? [])
        .map((a) => ((a as Map)['clubs'] as Map?)?['club_name'])
        .whereType<String>()
        .toList();

    Widget row(String label, String? value) {
      final v = (value == null || value.isEmpty) ? '–' : value;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: Text(label, style: t.bodyMedium?.copyWith(color: c.muted)),
            ),
            Expanded(child: SelectableText(v, style: t.bodyMedium)),
          ],
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AdminAvatar(
                  path: user['avatar_url'] as String?,
                  name: name,
                  size: 56,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: t.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AdminPill(
                        label: role[0].toUpperCase() + role.substring(1),
                        tone: role == 'admin'
                            ? AdminTone.attention
                            : AdminTone.neutral,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: c.border),
            row('Username', '@${user['username']}'),
            row('Email', user['email'] as String?),
            row('Phone', user['phone'] as String?),
            row('Student ID', user['student_id'] as String?),
            row('Department', dept),
            if (clubs.isNotEmpty) row('Clubs', clubs.join(', ')),
            row('Joined', joined == null ? null : adminDate(joined)),
            const SizedBox(height: 8),
            Text(
              'Read-only. Changes are made directly in the database.',
              style: t.bodySmall?.copyWith(color: c.muted),
            ),
          ],
        ),
      ),
    );
  }
}
