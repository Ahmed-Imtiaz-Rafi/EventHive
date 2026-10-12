import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Username of the logged-in user, read from the `users` table.
///
/// Lives in `common` because every role shows the user's name. It is
/// `autoDispose` so the name is dropped when no screen is watching it,
/// which means logging out and logging in as someone else never shows
/// the previous user's name.
final currentUsernameProvider = FutureProvider.autoDispose<String>((ref) async {
  final client = Supabase.instance.client;

  final userId = client.auth.currentUser?.id;
  if (userId == null) {
    throw const AuthException('Not signed in');
  }

  final row = await client
      .from('users')
      .select('username')
      .eq('user_id', userId)
      .single();

  return row['username'] as String;
});