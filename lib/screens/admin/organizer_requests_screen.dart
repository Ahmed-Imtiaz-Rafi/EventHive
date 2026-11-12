import 'package:event_hive/core/theme/admin/admin_theme.dart';
import 'package:event_hive/widgets/admin/admin_widgets.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Organizer oversight: Pending / Approved / Rejected organizer requests.
/// Approve and reject call the existing RPCs. "Remove organizer" and
/// "Reconsider" are placeholders until their backend functions exist.
class OrganizerRequestsScreen extends StatefulWidget {
  const OrganizerRequestsScreen({super.key});

  @override
  State<OrganizerRequestsScreen> createState() =>
      _OrganizerRequestsScreenState();
}

class _OrganizerRequestsScreenState extends State<OrganizerRequestsScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  bool _failed = false;
  String? _busyId; // request currently being approved / rejected

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _supabase
          .from('organizer_requests')
          .select(
            'request_id, user_id, club_id, proof_image_url, status, '
            'requested_at, reviewed_at, review_note, '
            'users(username, full_name, email, student_id, avatar_url, '
            'departments(department_name)), '
            'clubs(club_name)',
          )
          .order('requested_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _requests = List<Map<String, dynamic>>.from(rows);
        _loading = false;
        _failed = false;
      });
    } catch (e) {
      debugPrint('Organizer requests load error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _approve(Map<String, dynamic> r) async {
    final name = adminName(r['users'] as Map?);
    final club = (r['clubs'] as Map?)?['club_name'] ?? 'their club';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve organizer?'),
        content: Text('$name will be able to create events for $club.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busyId = r['request_id'] as String);
    try {
      await _supabase.rpc(
        'approve_organizer_request',
        params: {'req_id': r['request_id'], 'applicant_id': r['user_id']},
      );
      _toast('$name is now an organizer.');
      await _load();
    } catch (e) {
      _toast(adminError(e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _reject(Map<String, dynamic> r) async {
    final name = adminName(r['users'] as Map?);
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _RejectDialog(name: name),
    );
    if (note == null) return; // cancelled

    setState(() => _busyId = r['request_id'] as String);
    try {
      await _supabase.rpc(
        'reject_organizer_request',
        params: {'req_id': r['request_id'], 'note': note.isEmpty ? null : note},
      );
      _toast('Request from $name rejected.');
      await _load();
    } catch (e) {
      _toast(adminError(e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  /// The proof bucket is private, so the admin gets a short-lived signed link.
  Future<void> _viewProof(String path) async {
    try {
      final url = await _supabase.storage
          .from('organizer-proofs')
          .createSignedUrl(path, 300);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: InteractiveViewer(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('The proof image could not be displayed.'),
                    ),
                    loadingBuilder: (_, child, p) => p == null
                        ? child
                        : const Padding(
                            padding: EdgeInsets.all(48),
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      _toast('Could not open the proof.');
    }
  }

  void _comingSoon(String what) =>
      _toast('$what needs the next backend patch. Not wired yet.');

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    List<Map<String, dynamic>> byStatus(String s) =>
        _requests.where((r) => r['status'] == s).toList();
    final pending = byStatus('pending');
    final approved = byStatus('approved');
    final rejected = byStatus('rejected');

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
                title: 'Organizer oversight',
                subtitle: 'Review who may host events',
              ),
              AdminTabBar(
                labels: [
                  label('Pending', pending),
                  label('Approved', approved),
                  label('Rejected', rejected),
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
                        text: 'Could not load requests.',
                        actionLabel: 'Retry',
                        onAction: () {
                          setState(() => _loading = true);
                          _load();
                        },
                      )
                    : TabBarView(
                        children: [
                          _list(pending, 'pending', 'No pending requests.'),
                          _list(
                            approved,
                            'approved',
                            'No approved organizers yet.',
                          ),
                          _list(rejected, 'rejected', 'No rejected requests.'),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(List<Map<String, dynamic>> items, String tab, String empty) {
    return AdminRefreshList(
      onRefresh: _load,
      itemCount: items.length,
      emptyText: empty,
      emptyIcon: Icons.how_to_reg_outlined,
      itemBuilder: (_, i) {
        final r = items[i];
        return _RequestCard(
          request: r,
          tab: tab,
          busy: _busyId == r['request_id'],
          onApprove: () => _approve(r),
          onReject: () => _reject(r),
          onViewProof: () => _viewProof(r['proof_image_url'] as String),
          onRemove: () => _comingSoon('Removing an organizer'),
          onReconsider: () => _comingSoon('Reconsidering a rejected request'),
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final String tab; // pending | approved | rejected
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onViewProof;
  final VoidCallback onRemove;
  final VoidCallback onReconsider;

  const _RequestCard({
    required this.request,
    required this.tab,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onViewProof,
    required this.onRemove,
    required this.onReconsider,
  });

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    final t = Theme.of(context).textTheme;

    final user = request['users'] as Map?;
    final name = adminName(user);
    final studentId = (user?['student_id'] ?? '').toString();
    final dept = ((user?['departments'] as Map?)?['department_name'] ?? '')
        .toString();
    final club = ((request['clubs'] as Map?)?['club_name'] ?? '').toString();
    final proof = request['proof_image_url'] as String?;
    final note = (request['review_note'] ?? '').toString();
    final requestedAt = DateTime.tryParse(
      '${request['requested_at'] ?? ''}',
    )?.toLocal();
    final reviewedAt = DateTime.tryParse(
      '${request['reviewed_at'] ?? ''}',
    )?.toLocal();

    final ready = club.isNotEmpty && proof != null && proof.isNotEmpty;
    final sub = [
      if (studentId.isNotEmpty) studentId,
      if (dept.isNotEmpty) dept,
    ].join('  ·  ');

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AdminAvatar(path: user?['avatar_url'] as String?, name: name),
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
                    if (sub.isNotEmpty)
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall?.copyWith(color: c.muted),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (club.isNotEmpty) AdminPill(label: club),
              Text(
                tab == 'pending'
                    ? 'Requested ${adminAgo(requestedAt)}'
                    : '${tab == 'approved' ? 'Approved' : 'Rejected'} '
                          '${adminAgo(reviewedAt)}',
                style: t.bodySmall?.copyWith(color: c.muted),
              ),
            ],
          ),
          if (tab == 'rejected' && note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Reason: $note', style: t.bodySmall?.copyWith(color: c.muted)),
          ],
          if (tab == 'pending' && !ready) ...[
            const SizedBox(height: 10),
            Text(
              'Waiting for the applicant to choose a club and upload proof.',
              style: t.bodySmall?.copyWith(color: c.accent),
            ),
          ],
          const SizedBox(height: 14),
          Divider(color: c.border, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              if (tab != 'rejected' || (proof != null && proof.isNotEmpty))
                TextButton.icon(
                  onPressed: (proof == null || proof.isEmpty)
                      ? null
                      : onViewProof,
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: const Text('View proof'),
                ),
              const Spacer(),
              if (tab == 'pending') ...[
                OutlinedButton(
                  onPressed: busy ? null : onReject,
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: (busy || !ready) ? null : onApprove,
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Approve'),
                ),
              ],
              if (tab == 'approved')
                OutlinedButton(
                  onPressed: onRemove,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('Remove'),
                ),
              if (tab == 'rejected')
                OutlinedButton(
                  onPressed: onReconsider,
                  child: const Text('Reconsider'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Asks for an optional reason. Pops the text ('' if left empty) or null on cancel.
/// Its own State so the controller is disposed safely with the dialog.
class _RejectDialog extends StatefulWidget {
  final String name;
  const _RejectDialog({required this.name});

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject request?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.name} will see the reason you give.'),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLines: 3,
            maxLength: 200,
            decoration: const InputDecoration(
              hintText: 'Reason (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _note.text.trim()),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}
