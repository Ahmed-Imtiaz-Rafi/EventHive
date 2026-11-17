import 'package:event_hive/core/theme/app_theme.dart';
import 'package:event_hive/core/utils/event_date_time_format.dart';
import 'package:event_hive/model/common/my_registration.dart';
import 'package:event_hive/provider/participant/registration_provider.dart';
import 'package:event_hive/widgets/common/event_thumbnail.dart';
import 'package:event_hive/widgets/common/tab_title_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// My events tab: every event the student registered for, split into
/// Upcoming, Past and Cancelled.
///
/// The list comes from [myRegistrationsProvider]; the tab a registration
/// belongs to is decided by `MyRegistration.tab`. Tapping a card opens
/// its registration inside this tab: a pending one shows the payment
/// form, so it doubles as a "Pay now" entry, and a confirmed one shows
/// its status with the ticket. Pulling the list down fetches fresh data.
class MyEventsScreen extends ConsumerStatefulWidget {
  const MyEventsScreen({super.key});

  @override
  ConsumerState<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends ConsumerState<MyEventsScreen> {
  /// The tab that is open.
  RegistrationTab _tab = RegistrationTab.upcoming;

  /// Fallback thumbnail colors for events without an image, reused in
  /// order.
  static const _accents = [kNavy, kAmber, kTextSub];

  /// What to say when a tab has no registrations.
  static const _emptyText = {
    RegistrationTab.upcoming: 'You have no upcoming events.',
    RegistrationTab.past: 'No past events yet.',
    RegistrationTab.cancelled: 'No cancelled registrations.',
  };

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(myRegistrationsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TabTitleBar(title: 'My events'),
          const SizedBox(height: 16),

          // ---- Tabs ----
          Row(
            children: [
              for (final tab in RegistrationTab.values) ...[
                Expanded(
                  child: _TabChip(
                    label: switch (tab) {
                      RegistrationTab.upcoming => 'Upcoming',
                      RegistrationTab.past => 'Past',
                      RegistrationTab.cancelled => 'Cancelled',
                    },
                    selected: _tab == tab,
                    onTap: () => setState(() => _tab = tab),
                  ),
                ),
                if (tab != RegistrationTab.values.last)
                  const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // ---- List ----
          Expanded(
            child: request.when(
              // ---- Loading ----
              loading: () => const Center(child: CircularProgressIndicator()),

              // ---- Error ----
              // Details go to the console; the user sees a generic message.
              error: (e, _) {
                debugPrint('Failed to load registrations: $e');
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Could not load your events',
                        style: TextStyle(color: kTextSub),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(myRegistrationsProvider),
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
              data: (all) {
                final shown = all.where((r) => r.tab == _tab).toList()
                  ..sort(
                    (a, b) => _tab == RegistrationTab.past
                        // Most recent first.
                        ? b.eventStartsAt.compareTo(a.eventStartsAt)
                        // Soonest first.
                        : a.eventStartsAt.compareTo(b.eventStartsAt),
                  );

                return RefreshIndicator(
                  color: kNavy,
                  onRefresh: () => ref.refresh(myRegistrationsProvider.future),
                  child: shown.isEmpty
                      // A scrollable message, so pull-to-refresh still works.
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 48),
                            Center(
                              child: Text(
                                _emptyText[_tab]!,
                                style: const TextStyle(color: kTextSub),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: shown.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, i) => _RegistrationCard(
                            registration: shown[i],
                            accent: _accents[i % _accents.length],
                            // The registration pages live inside this tab,
                            // so the bottom bar stays visible.
                            onTap: () => context.push(
                              '/participant/my-events/registration/'
                              '${shown[i].registrationId}',
                            ),
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// Pieces
// ------------------------------------------------------------------

/// One of the three tab buttons: navy when selected, white otherwise.
class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? kNavy : kSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? kNavy : kBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : kTextMain,
            ),
          ),
        ),
      ),
    );
  }
}

/// One registration: thumbnail, event title with a status chip, date
/// and time, and venue.
class _RegistrationCard extends StatelessWidget {
  final MyRegistration registration;
  final Color accent;
  final VoidCallback onTap;

  const _RegistrationCard({
    required this.registration,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = registration;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EventThumbnail(imageUrl: r.imageUrl, fallback: accent, size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title on the left, status chip on the right.
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.eventTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'serif',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: kTextMain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: kBorder,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            r.statusLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: kTextMain,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatEventDate(r.eventStartsAt)} · '
                      '${formatEventTime(r.eventStartsAt)}',
                      style: const TextStyle(fontSize: 12, color: kTextSub),
                    ),
                    Text(
                      r.venue,
                      style: const TextStyle(fontSize: 12, color: kTextSub),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}