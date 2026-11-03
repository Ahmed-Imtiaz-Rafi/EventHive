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

  /// Uploads [file] as the profile picture, saves its PATH on the profile,
  /// and returns that path.
  ///
  /// The database only accepts a path inside the user's own folder
  /// (`<user_id>/<file>`), never a full address. Each picture gets a new
  /// file name, so the browser never shows an older cached one. The
  /// picture being replaced ([previousPath]) is deleted afterwards.
  Future<String> uploadAvatar(XFile file, {String? previousPath}) async {
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
    } on StorageException catch (e) {
      debugPrint('Picture upload failed: ${e.message}');
      throw const ProfileException(
        'Could not upload the picture. Please try again.',
      );
    }

    try {
      await _savePath(userId, path);
    } catch (e) {
      debugPrint('Saving the picture path failed: $e');
      // Do not leave an unused file behind.
      await _deleteFile(userId, path);
      throw const ProfileException(
        'Could not save your picture. Please try again.',
      );
    }

    await _deleteFile(userId, previousPath);
    return path;
  }

  /// Removes the profile picture from the profile and deletes its file
  /// ([previousPath]).
  Future<void> removeAvatar({String? previousPath}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const ProfileException('Please sign in again.');
    }

    try {
      await _savePath(userId, null);
    } catch (e) {
      debugPrint('Removing the picture failed: $e');
      throw const ProfileException(
        'Could not remove your picture. Please try again.',
      );
    }

    await _deleteFile(userId, previousPath);
  }

  /// Writes (or clears, with null) the picture path on the user's row.
  Future<void> _savePath(String userId, String? path) async {
    final updated = await _client
        .from('users')
        .update({'avatar_url': path})
        .eq('user_id', userId)
        .select('user_id');

    // An update that matched no row is silent, so check for it.
    if ((updated as List).isEmpty) {
      throw const ProfileException('The profile was not updated.');
    }
  }

  /// Deletes one of the user's own picture files. Tidying up only, so a
  /// failure is not worth bothering the user with.
  Future<void> _deleteFile(String userId, String? path) async {
    // Only paths inside the user's own folder; an old full address or an
    // empty value has no file to delete.
    if (path == null || !path.startsWith('$userId/')) return;

    try {
      await _client.storage.from('avatars').remove([path]);
    } catch (e) {
      debugPrint('Could not delete an old picture: $e');
    }
  }
}

final profileActionsProvider = Provider<ProfileActions>(
  (ref) => ProfileActions(),
);