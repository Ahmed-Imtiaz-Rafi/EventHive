import 'package:event_hive/core/theme/app_theme.dart';
import 'package:event_hive/model/common/user_profile.dart';
import 'package:event_hive/provider/common/department_provider.dart';
import 'package:event_hive/provider/common/user_provider.dart';
import 'package:event_hive/widgets/common/app_header_bar.dart';
import 'package:event_hive/widgets/common/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

/// Lets the user change the profile fields the database allows: phone,
/// student ID, department and profile picture. Username and email are
/// shown but cannot be changed here.
///
/// Registering for an event needs both the student ID and the department,
/// and the student ID must be unique, so a student ID another account
/// already uses is refused with a clear message.
class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppHeaderBar(
                title: 'Edit profile',
                fallbackRoute: '/participant/profile',
              ),
              const SizedBox(height: 16),
              Expanded(
                child: profile.when(
                  // Keep showing the form while the profile reloads after
                  // a picture change, so typed text is not lost.
                  skipLoadingOnReload: true,
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) {
                    debugPrint('Failed to load profile: $e');
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Could not load your profile',
                            style: TextStyle(color: kTextSub),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () =>
                                ref.invalidate(currentProfileProvider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kNavy,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  },
                  data: (p) => _EditForm(profile: p),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The form itself, built once the profile has loaded so the fields can
/// start with the saved values.
class _EditForm extends ConsumerStatefulWidget {
  final UserProfile profile;
  const _EditForm({required this.profile});

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _studentCtrl;
  int? _departmentId;

  /// True while saving; stops double taps.
  bool _busy = false;

  /// Why the save was refused, shown above the button.
  String? _error;

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController(text: widget.profile.phone ?? '');
    _studentCtrl = TextEditingController(text: widget.profile.studentId ?? '');
    _departmentId = widget.profile.departmentId;
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _studentCtrl.dispose();
    super.dispose();
  }

  /// Validates the fields and saves them. Empty fields are stored as
  /// "nothing" (null), never as empty text, because the database treats
  /// a missing student ID as an incomplete profile.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final phone = _phoneCtrl.text.trim();
    final studentId = _studentCtrl.text.trim();

    try {
      await ref
          .read(profileActionsProvider)
          .save(
            phone: phone.isEmpty ? null : phone,
            studentId: studentId.isEmpty ? null : studentId,
            departmentId: _departmentId,
          );
      if (!mounted) return;

      ref.invalidate(currentProfileProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile saved')));
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/participant/profile');
      }
    } on ProfileException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      debugPrint('Unexpected error while saving profile: $e');
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final departments = ref.watch(departmentsProvider);

    return Form(
      key: _formKey,
      child: ListView(
        children: [
          // ---- Profile picture ----
          // Changed and saved on its own, separately from the Save
          // button below.
          Center(child: _AvatarEditor(imageUrl: widget.profile.avatarUrl)),
          const SizedBox(height: 20),

          // The two things registering needs.
          if (!widget.profile.isComplete) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kBorder,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Your student ID and department are needed before you can '
                'register for events.',
                style: TextStyle(fontSize: 13, color: kTextMain),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ---- Read-only ----
          _label('Username'),
          TextFormField(
            initialValue: widget.profile.username,
            enabled: false,
          ),
          const SizedBox(height: 16),
          _label('Email'),
          TextFormField(initialValue: widget.profile.email, enabled: false),
          const SizedBox(height: 16),

          // ---- Editable ----
          _label('Phone'),
          TextFormField(
            controller: _phoneCtrl,
            enabled: !_busy,
            keyboardType: TextInputType.phone,
            // Digits only, at most 11 of them.
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
            decoration: const InputDecoration(hintText: '01XXXXXXXXX'),
            validator: (v) {
              final value = (v ?? '').trim();
              // Optional; when given it must be a Bangladeshi mobile.
              if (value.isNotEmpty &&
                  !RegExp(r'^01[3-9]\d{8}$').hasMatch(value)) {
                return 'Enter a valid 11-digit mobile number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _label('Student ID'),
          TextFormField(
            controller: _studentCtrl,
            enabled: !_busy,
            decoration: const InputDecoration(hintText: 'Your student ID'),
            validator: (v) => (v ?? '').trim().length > 30
                ? 'This looks too long'
                : null,
          ),
          const SizedBox(height: 16),
          _label('Department'),
          departments.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) {
              debugPrint('Failed to load departments: $e');
              return const Text(
                'Could not load departments',
                style: TextStyle(color: kTextSub),
              );
            },
            data: (list) => DropdownButtonFormField<int>(
              initialValue: _departmentId,
              items: [
                for (final d in list)
                  DropdownMenuItem(value: d.id, child: Text(d.name)),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _departmentId = value),
              decoration: const InputDecoration(
                hintText: 'Select your department',
              ),
            ),
          ),

          // Why the save was refused, if it was.
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(fontSize: 12, color: Colors.redAccent),
            ),
          ],
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _busy ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: kNavy,
                foregroundColor: Colors.white,
                disabledBackgroundColor: kNavy,
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Small grey label above a field.
  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 12, color: kTextSub)),
  );
}

// ------------------------------------------------------------------
// Profile picture
// ------------------------------------------------------------------

/// The profile picture with a camera badge. Tapping it (or "Change
/// photo") opens the device's pictures; the chosen one is uploaded right
/// away and saved on the profile, separately from the Save button.
class _AvatarEditor extends ConsumerStatefulWidget {
  final String? imageUrl;
  const _AvatarEditor({required this.imageUrl});

  @override
  ConsumerState<_AvatarEditor> createState() => _AvatarEditorState();
}

class _AvatarEditorState extends ConsumerState<_AvatarEditor> {
  final _picker = ImagePicker();

  /// The picture shown now. Kept here so it changes the moment an upload
  /// finishes, without waiting for the profile to reload.
  String? _url;

  /// True while uploading or removing; stops double taps.
  bool _busy = false;

  /// Why the last change failed, shown under the picture.
  String? _error;

  @override
  void initState() {
    super.initState();
    _url = widget.imageUrl;
  }

  /// Lets the user choose a picture from the device and uploads it.
  Future<void> _change() async {
    if (_busy) return;

    // The picture is reduced before upload, so it stays small and fast.
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final url = await ref.read(profileActionsProvider).uploadAvatar(file);
      if (!mounted) return;
      setState(() => _url = url);
      // The Profile tab shows the new picture too.
      ref.invalidate(currentProfileProvider);
    } on ProfileException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      debugPrint('Unexpected error while uploading the picture: $e');
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Takes the picture off the profile.
  Future<void> _remove() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(profileActionsProvider).removeAvatar();
      if (!mounted) return;
      setState(() => _url = null);
      ref.invalidate(currentProfileProvider);
    } on ProfileException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      debugPrint('Unexpected error while removing the picture: $e');
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _change,
            child: Stack(
              children: [
                UserAvatar(imageUrl: _url, size: 96),

                // Dims the picture while uploading.
                if (_busy)
                  const Positioned.fill(
                    child: ClipOval(
                      child: ColoredBox(
                        color: Colors.black38,
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Camera badge in the corner.
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: kAmber,
                      shape: BoxShape.circle,
                      border: Border.all(color: kBg, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy ? null : _change,
          child: const Text('Change photo'),
        ),
        if (_url != null)
          TextButton(
            onPressed: _busy ? null : _remove,
            child: const Text(
              'Remove photo',
              style: TextStyle(color: kDanger),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.redAccent),
            ),
          ),
      ],
    );
  }
}