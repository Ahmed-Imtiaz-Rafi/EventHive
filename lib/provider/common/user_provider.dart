import 'package:event_hive/model/common/user_profile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The logged-in user's profile, read from the `users` table with the
/// department name.
///
/// Lives in `common` because every role has a profile. It is
/// `autoDispose` so the profile is dropped when no screen is watching it,
/// which means logging out and in as someone else never shows the
/// previous user's details. Call `ref.invalidate(currentProfileProvider)`
/// after saving the profile.
final currentProfileProvider = FutureProvider.autoDispose<UserProfile>((
  ref,
) async {
  final client = Supabase.instance.client;

  final userId = client.auth.currentUser?.id;
  if (userId == null) {
    throw const AuthException('Not signed in');
  }

  final row = await client
      .from('users')
      .select(
        'username, email, phone, student_id, department_id, avatar_url, '
        'departments(department_name)',
      )
      .eq('user_id', userId)
      .single();

  return UserProfile.fromMap(row);
});

/// Username of the logged-in user, taken from [currentProfileProvider].
final currentUsernameProvider = FutureProvider.autoDispose<String>((
  ref,
) async {
  final profile = await ref.watch(currentProfileProvider.future);
  return profile.username;
});

/// Student ID of the logged-in user, or null until the profile has one.
final currentStudentIdProvider = FutureProvider.autoDispose<String?>((
  ref,
) async {
  final profile = await ref.watch(currentProfileProvider.future);
  return profile.studentId;
});

/// A profile change that could not be saved. [message] is safe to show.
class ProfileException implements Exception {
  final String message;
  const ProfileException(this.message);

  @override
  String toString() => message;
}

/// Largest picture the `avatars` bucket accepts.
const _maxAvatarBytes = 2 * 1024 * 1024;

/// Saves the fields a user is allowed to change on their own profile:
/// phone, student ID, department and profile picture. Username and email
/// cannot be changed from the app.
class ProfileActions {
  SupabaseClient get _client => Supabase.instance.client;

  Future<void> save({
    String? phone,
    String? studentId,
    int? departmentId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const ProfileException('Please sign in again.');
    }

    try {
      final updated = await _client
          .from('users')
          .update({
            'phone': phone,
            'student_id': studentId,
            'department_id': departmentId,
          })
          .eq('user_id', userId)
          .select('user_id');

      // An update that matched no row is silent, so check for it.
      if ((updated as List).isEmpty) {
        throw const ProfileException(
          'Could not save your profile. Please try again.',
        );
      }
    } on PostgrestException catch (e) {
      debugPrint('Profile save failed: ${e.message}');
      // 23505 = unique violation: another account has this student ID.
      if (e.code == '23505') {
        throw const ProfileException(
          'This student ID is already used by another account.',
        );
      }
      throw const ProfileException(
        'Could not save your profile. Please try again.',
      );
    }
  }

  /// Uploads [file] as the profile picture, saves its link on the
  /// profile, and returns that link.
  ///
  /// The picture goes into a folder named after the user (the only place
  /// the database lets them write) under a new name each time, so the
  /// browser never shows an older cached picture.
  Future<String> uploadAvatar(XFile file) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const ProfileException('Please sign in again.');
    }

    // Only the picture types the bucket accepts.
    final extension = file.name.split('.').last.toLowerCase();
    final contentType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => null,
    };
    if (contentType == null) {
      throw const ProfileException('Choose a JPG, PNG or WebP picture.');
    }

    final bytes = await file.readAsBytes();
    if (bytes.length > _maxAvatarBytes) {
      throw const ProfileException(
        'This picture is larger than 2 MB. Choose a smaller one.',
      );
    }

    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$extension';
    try {
      await _client.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType),
          );
      final url = _client.storage.from('avatars').getPublicUrl(path);
      await _saveAvatarUrl(userId, url);
      return url;
    } on StorageException catch (e) {
      debugPrint('Picture upload failed: ${e.message}');
      throw const ProfileException(
        'Could not upload the picture. Please try again.',
      );
    } on PostgrestException catch (e) {
      debugPrint('Saving the picture link failed: ${e.message}');
      throw const ProfileException(
        'Could not save your picture. Please try again.',
      );
    }
  }

  /// Removes the profile picture from the profile. The file itself stays
  /// in storage, because users cannot delete files.
  Future<void> removeAvatar() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const ProfileException('Please sign in again.');
    }

    try {
      await _saveAvatarUrl(userId, null);
    } on PostgrestException catch (e) {
      debugPrint('Removing the picture failed: ${e.message}');
      throw const ProfileException(
        'Could not remove your picture. Please try again.',
      );
    }
  }

  /// Writes (or clears, with null) the picture link on the user's row.
  Future<void> _saveAvatarUrl(String userId, String? url) async {
    final updated = await _client
        .from('users')
        .update({'avatar_url': url})
        .eq('user_id', userId)
        .select('user_id');

    // An update that matched no row is silent, so check for it.
    if ((updated as List).isEmpty) {
      throw const ProfileException(
        'Could not save your picture. Please try again.',
      );
    }
  }
}

final profileActionsProvider = Provider<ProfileActions>(
  (ref) => ProfileActions(),
);