import 'package:event_hive/core/theme/admin/admin_theme.dart';
import 'package:event_hive/widgets/admin/admin_widgets.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin profile: change full name, phone and profile picture; sign out.
/// Username and email are shown but not editable (they come from sign-up).
/// Needs image_picker in pubspec.yaml.
class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _fullName = TextEditingController();
  final _phone = TextEditingController();

  Map<String, dynamic>? _user;
  bool _loading = true;
  bool _failed = false;
  bool _saving = false;
  bool _uploading = false;

  static const _allowedTypes = ['image/jpeg', 'image/png', 'image/webp'];
  static const _maxBytes = 2 * 1024 * 1024; // matches the bucket limit

  @override
  void initState() {
    super.initState();
    _fullName.addListener(() => setState(() {}));
    _phone.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? get _uid => _supabase.auth.currentUser?.id;

  Future<void> _load() async {
    final uid = _uid;
    if (uid == null) {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    try {
      final row = await _supabase
          .from('users')
          .select('username, email, full_name, phone, avatar_url, created_at')
          .eq('user_id', uid)
          .single();
      if (!mounted) return;
      setState(() {
        _user = Map<String, dynamic>.from(row);
        _fullName.text = (row['full_name'] ?? '').toString();
        _phone.text = (row['phone'] ?? '').toString();
        _loading = false;
        _failed = false;
      });
    } catch (e) {
      debugPrint('Admin profile load error: $e');
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

  bool get _dirty {
    final u = _user;
    if (u == null) return false;
    return _fullName.text.trim() != (u['full_name'] ?? '').toString().trim() ||
        _phone.text.trim() != (u['phone'] ?? '').toString().trim();
  }

  String? get _phoneError {
    final p = _phone.text.trim();
    if (p.isEmpty) return null;
    return RegExp(r'^[0-9+\-\s]{7,20}$').hasMatch(p)
        ? null
        : 'Enter a valid phone number';
  }

  Future<void> _save() async {
    final uid = _uid;
    if (uid == null || _saving) return;
    final name = _fullName.text.trim();
    final phone = _phone.text.trim();
    setState(() => _saving = true);
    try {
      await _supabase
          .from('users')
          .update({
            'full_name': name.isEmpty ? null : name,
            'phone': phone.isEmpty ? null : phone,
          })
          .eq('user_id', uid);
      if (!mounted) return;
      setState(() {
        _user!['full_name'] = name.isEmpty ? null : name;
        _user!['phone'] = phone.isEmpty ? null : phone;
      });
      FocusScope.of(context).unfocus();
      _toast('Profile saved.');
    } catch (e) {
      _toast(adminError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAvatar() async {
    final uid = _uid;
    if (uid == null) return;
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    if (bytes.length > _maxBytes) {
      _toast('Choose a picture under 2 MB.');
      return;
    }
    final lower = file.name.toLowerCase();
    final mime = _allowedTypes.contains(file.mimeType)
        ? file.mimeType!
        : lower.endsWith('.png')
        ? 'image/png'
        : lower.endsWith('.webp')
        ? 'image/webp'
        : 'image/jpeg';
    final ext = mime == 'image/png'
        ? 'png'
        : mime == 'image/webp'
        ? 'webp'
        : 'jpg';

    setState(() => _uploading = true);
    try {
      final old = _user?['avatar_url'] as String?;
      // New file name every time, so the old picture is never served from cache.
      final path = '$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _supabase.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mime),
          );
      await _supabase
          .from('users')
          .update({'avatar_url': path})
          .eq('user_id', uid);
      await _removeFile(old);
      if (!mounted) return;
      setState(() => _user!['avatar_url'] = path);
      _toast('Profile picture updated.');
    } catch (e) {
      _toast(adminError(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removeAvatar() async {
    final uid = _uid;
    if (uid == null) return;
    setState(() => _uploading = true);
    try {
      final old = _user?['avatar_url'] as String?;
      await _supabase
          .from('users')
          .update({'avatar_url': null})
          .eq('user_id', uid);
      await _removeFile(old);
      if (!mounted) return;
      setState(() => _user!['avatar_url'] = null);
      _toast('Profile picture removed.');
    } catch (e) {
      _toast(adminError(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// Best effort: a leftover file is harmless, so failures are ignored.
  Future<void> _removeFile(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      await _supabase.storage.from('avatars').remove([path]);
    } catch (_) {}
  }

  void _avatarSheet() {
    final hasPicture = ((_user?['avatar_url'] ?? '') as String).isNotEmpty;
    final c = AdminColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: c.brand),
              title: const Text('Choose a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAvatar();
              },
            ),
            if (hasPicture)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(ctx).colorScheme.error,
                ),
                title: Text(
                  'Remove photo',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _removeAvatar();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to use the admin panel.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _supabase.auth.signOut();
      if (mounted) context.go('/login');
    } catch (e) {
      _toast(adminError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
            : _failed || _user == null
            ? AdminMessage(
                icon: Icons.cloud_off_outlined,
                text: 'Could not load your profile.',
                actionLabel: 'Retry',
                onAction: () {
                  setState(() => _loading = true);
                  _load();
                },
              )
            : _content(),
      ),
    );
  }

  Widget _content() {
    final c = AdminColors.of(context);
    final t = Theme.of(context).textTheme;
    final u = _user!;
    final name = adminName(u);
    final joined = DateTime.tryParse('${u['created_at'] ?? ''}')?.toLocal();
    final canSave = _dirty && _phoneError == null && !_saving;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Text(
          'Profile',
          style: t.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            color: c.ink,
          ),
        ),
        const SizedBox(height: 24),

        // ── Picture, name, role
        Center(
          child: Column(
            children: [
              Stack(
                children: [
                  AdminAvatar(
                    path: u['avatar_url'] as String?,
                    name: name,
                    size: 104,
                  ),
                  if (_uploading)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.bg.withValues(alpha: 0.6),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: c.brand,
                      shape: CircleBorder(
                        side: BorderSide(color: c.bg, width: 3),
                      ),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _uploading ? null : _avatarSheet,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.photo_camera_outlined,
                            size: 18,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                name,
                style: t.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 8),
              const AdminPill(
                label: 'Administrator',
                tone: AdminTone.attention,
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // ── Editable details
        _SectionLabel('Your details'),
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Field(
                label: 'Full name',
                controller: _fullName,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              _Field(
                label: 'Phone',
                controller: _phone,
                keyboardType: TextInputType.phone,
                errorText: _phoneError,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: canSave ? _save : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save changes'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Fixed details
        _SectionLabel('Account'),
        AdminCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              _FixedRow(label: 'Username', value: '@${u['username']}'),
              Divider(color: c.border, height: 1),
              _FixedRow(label: 'Email', value: '${u['email']}'),
              if (joined != null) ...[
                Divider(color: c.border, height: 1),
                _FixedRow(label: 'Member since', value: adminDate(joined)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Username and email are set at sign-up and cannot be changed here.',
            style: t.bodySmall?.copyWith(color: c.muted),
          ),
        ),
        const SizedBox(height: 24),

        OutlinedButton.icon(
          onPressed: _signOut,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
            side: BorderSide(
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.6),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: c.muted,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Label above a filled text field, matching the search field style.
class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int? maxLength;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  const _Field({
    required this.label,
    required this.controller,
    this.maxLength,
    this.errorText,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: c.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLength: maxLength,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          decoration: InputDecoration(
            counterText: '',
            errorText: errorText,
            filled: true,
            fillColor: c.bg,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: border(c.border),
            enabledBorder: border(c.border),
            focusedBorder: border(c.brand),
          ),
        ),
      ],
    );
  }
}

class _FixedRow extends StatelessWidget {
  final String label;
  final String value;
  const _FixedRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            child: Text(label, style: t.bodyMedium?.copyWith(color: c.muted)),
          ),
          Expanded(child: SelectableText(value, style: t.bodyMedium)),
          Icon(Icons.lock_outline, size: 16, color: c.muted),
        ],
      ),
    );
  }
}
