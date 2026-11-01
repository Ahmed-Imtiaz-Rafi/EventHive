import 'package:event_hive/core/theme/app_theme.dart';
import 'package:event_hive/model/common/user_profile.dart';
import 'package:event_hive/provider/common/notification_provider.dart';
import 'package:event_hive/provider/common/user_provider.dart';
import 'package:event_hive/widgets/common/tab_title_bar.dart';
import 'package:event_hive/widgets/common/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Profile tab: who the user is, a way to edit it, and shortcuts.
///
/// The card shows the username and email (the schema has no full-name
/// column). The pencil opens the edit screen, where phone, student ID and
/// department can be changed. A reminder shows while the profile lacks
/// the student ID or department, because registering needs both.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  /// Menu items without a screen yet.
  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Coming soon')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final unread = ref
        .watch(unreadNotificationsProvider)
        .maybeWhen(data: (n) => n, orElse: () => 0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TabTitleBar(title: 'Profile'),
          const SizedBox(height: 16),
          Expanded(
            child: profile.when(
              // ---- Loading ----
              loading: () => const Center(child: CircularProgressIndicator()),

              // ---- Error ----
              // Details go to the console; the user sees a generic message.
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
                        onPressed: () => ref.invalidate(currentProfileProvider),
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

              // ---- Data ----
              data: (p) => ListView(
                children: [
                  _UserCard(
                    profile: p,
                    onEdit: () => context.push('/participant/profile/edit'),
                  ),
                  if (!p.isComplete) ...[
                    const SizedBox(height: 12),
                    _CompleteProfileNote(
                      onTap: () => context.push('/participant/profile/edit'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _MenuCard(
                    entries: [
                      _MenuEntry(
                        icon: Icons.confirmation_number_outlined,
                        title: 'My events / tickets',
                        onTap: () => context.go('/participant/my-events'),
                      ),
                      _MenuEntry(
                        icon: Icons.notifications_none_outlined,
                        title: 'Notifications',
                        badge: unread,
                        onTap: () => context.push('/participant/notifications'),
                      ),
                      _MenuEntry(
                        icon: Icons.credit_card_outlined,
                        title: 'Payment methods',
                        onTap: () => _comingSoon(context),
                      ),
                      _MenuEntry(
                        icon: Icons.settings_outlined,
                        title: 'Settings',
                        onTap: () => _comingSoon(context),
                      ),
                      _MenuEntry(
                        icon: Icons.help_outline,
                        title: 'Help & support',
                        onTap: () => _comingSoon(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// User card
// ------------------------------------------------------------------

/// Avatar, username, email and the edit pencil.
class _UserCard extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onEdit;

  const _UserCard({required this.profile, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          // The profile picture, or a person icon until one is set.
          UserAvatar(imageUrl: profile.avatarUrl, size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: kTextMain,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  profile.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: kTextSub),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 20, color: kTextSub),
          ),
        ],
      ),
    );
  }
}

/// Reminder shown while the student ID or department is missing.
class _CompleteProfileNote extends StatelessWidget {
  final VoidCallback onTap;
  const _CompleteProfileNote({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kBorder,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: kTextMain),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Add your student ID and department to register for events.',
                  style: TextStyle(fontSize: 13, color: kTextMain),
                ),
              ),
              Icon(Icons.chevron_right, color: kTextSub),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// Menu
// ------------------------------------------------------------------

/// One row of the menu.
class _MenuEntry {
  final IconData icon;
  final String title;

  /// Count shown in an amber badge; hidden when 0.
  final int badge;
  final VoidCallback onTap;

  const _MenuEntry({
    required this.icon,
    required this.title,
    this.badge = 0,
    required this.onTap,
  });
}

/// White card holding the menu rows, separated by thin lines.
class _MenuCard extends StatelessWidget {
  final List<_MenuEntry> entries;
  const _MenuCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            _MenuRow(entry: entries[i]),
            if (i < entries.length - 1)
              const Divider(height: 1, indent: 16, endIndent: 16, color: kBorder),
          ],
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final _MenuEntry entry;
  const _MenuRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: entry.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(entry.icon, size: 20, color: kTextMain),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                entry.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: kTextMain,
                ),
              ),
            ),
            if (entry.badge > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: kAmber,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${entry.badge}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right, color: kTextSub),
          ],
        ),
      ),
    );
  }
}