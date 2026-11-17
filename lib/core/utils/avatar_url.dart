import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns what `users.avatar_url` holds into an address a picture can be
/// loaded from.
///
/// The database stores only a path inside the public `avatars` bucket
/// (`<user_id>/<file>`), never a full address, so the app builds the
/// address when it shows the picture. Returns null when there is no
/// picture.
String? avatarPublicUrl(String? path) {
  final value = path?.trim();
  if (value == null || value.isEmpty) return null;

  // A full address saved before the database only allowed paths still
  // displays, until the picture is changed.
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }

  return Supabase.instance.client.storage.from('avatars').getPublicUrl(value);
}