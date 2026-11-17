import 'package:event_hive/core/theme/app_theme.dart';
import 'package:event_hive/core/utils/time_ago.dart';
import 'package:event_hive/model/common/announcement.dart';
import 'package:event_hive/provider/common/notification_provider.dart';
import 'package:event_hive/widgets/common/app_header_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The messages organizers and admins sent to this user, newest first.
///
/// Unread ones have a navy icon and an amber dot; tapping one marks it as
/// read, which also lowers the badges on Home and Profile. Pulling the
/// list down fetches fresh data.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  /// Marks [item] as read and refreshes everything that counts them.
  Future<void> _open(WidgetRef ref, Announcement item) async {
    if (item.isRead) return;
    await ref.read(announcementActionsProvider).markRead(item.id);
    ref.invalidate(myAnnouncementsProvider);
    ref.invalidate(unreadNotificationsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(myAnnouncementsProvider);

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppHeaderBar(
                title: 'Notifications',
                fallbackRoute: '/participant/home',
              ),
              const SizedBox(height: 16),
              Expanded(
                child: request.when(
                  // ---- Loading ----
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),

                  // ---- Error ----
                  // Details go to the console; the user sees a generic message.
                  error: (e, _) {
                    debugPrint('Failed to load notifications: $e');
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Could not load notifications',
                            style: TextStyle(color: kTextSub),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () =>
                                ref.invalidate(myAnnouncementsProvider),
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
                  data: (list) => RefreshIndicator(
                    color: kNavy,
                    onRefresh: () async {
                      ref.invalidate(unreadNotificationsProvider);
                      await ref.refresh(myAnnouncementsProvider.future);
                    },
                    child: list.isEmpty
                        // A scrollable message, so pull-to-refresh still works.
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 48),
                              Center(
                                child: Text(
                                  'No notifications yet.',
                                  style: TextStyle(color: kTextSub),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: list.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, i) => _NotificationCard(
                              item: list[i],
                              onTap: () => _open(ref, list[i]),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One message: icon, title, text, how long ago, and an amber dot while
/// unread.
class _NotificationCard extends StatelessWidget {
  final Announcement item;
  final VoidCallback onTap;

  const _NotificationCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unread = !item.isRead;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Icon square ----
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: unread ? kNavy : kBorder,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  // A message about one event, or from a club.
                  item.scope == 'event'
                      ? Icons.event_outlined
                      : Icons.campaign_outlined,
                  size: 20,
                  color: unread ? Colors.white : kTextSub,
                ),
              ),
              const SizedBox(width: 12),

              // ---- Title, text, time ----
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: kTextMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.body,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: kTextSub,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      timeAgo(item.createdAt),
                      style: const TextStyle(fontSize: 11, color: kTextSub),
                    ),
                  ],
                ),
              ),

              // Unread marker.
              if (unread) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(
                    color: kAmber,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}