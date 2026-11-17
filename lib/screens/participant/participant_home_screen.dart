import 'package:event_hive/core/theme/app_theme.dart';
import 'package:event_hive/provider/common/category_provider.dart';
import 'package:event_hive/provider/common/user_provider.dart';
import 'package:event_hive/provider/common/notification_provider.dart';
import 'package:event_hive/provider/participant/event_provider.dart';
import 'package:event_hive/widgets/common/event_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Home tab of the participant side: header, search bar, category chips
/// and the list of upcoming events.
///
/// The bottom navigation bar is not built here; it belongs to
/// `ParticipantShell`, which the router puts around this screen.
///
/// The header, search bar and chips keep their height; the event list
/// takes the remaining space and scrolls on its own.
class ParticipantHomeScreen extends StatelessWidget {
  const ParticipantHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeHeader(),
          SizedBox(height: 16),
          _SearchBar(),
          SizedBox(height: 16),
          _CategoryChips(),
          SizedBox(height: 20),
          Text(
            'Upcoming events',
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: kTextMain,
            ),
          ),
          SizedBox(height: 12),
          // Expanded gives the list all the remaining height, so it
          // scrolls on its own while the header and chips stay put.
          Expanded(child: _EventList()),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// Home tab: header
// ------------------------------------------------------------------

/// Navy card at the top of Home: greeting, the user's name, and the
/// notification bell.
///
/// The name is the logged-in user's `username`, read through
/// [currentUsernameProvider].
class _HomeHeader extends ConsumerWidget {
  const _HomeHeader();

  /// Picks the greeting from the phone's local time.
  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Loading shows nothing in the name's place. If the name cannot be
    // loaded, a generic label keeps the header from looking broken.
    final name = ref
        .watch(currentUsernameProvider)
        .when(
          data: (username) => username,
          loading: () => '',
          error: (e, _) {
            debugPrint('Failed to load username: $e');
            return 'Participant';
          },
        );

    // Unread announcements, from the database.
    final unread = ref
        .watch(unreadNotificationsProvider)
        .maybeWhen(data: (n) => n, orElse: () => 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kNavy,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // Expanded makes the text take all the space the bell leaves,
          // so a long name is cut with "..." instead of overflowing.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(),
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
                // Fixed height, so the header does not jump in size
                // while the name is still loading.
                SizedBox(
                  height: 32,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _NotificationBell(count: unread),
        ],
      ),
    );
  }
}

/// Rounded bell button with an amber count badge in its corner.
/// The badge is hidden when [count] is 0.
class _NotificationBell extends StatelessWidget {
  final int count;
  const _NotificationBell({required this.count});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/participant/notifications'),
      child: Stack(
        // Lets the badge sit partly outside the 48x48 box.
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(
              Icons.notifications_none_outlined,
              color: Colors.white,
            ),
          ),
          if (count > 0)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: kAmber,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// Home tab: search bar
// ------------------------------------------------------------------

/// Search box under the header. Every keystroke is stored in
/// [searchQueryProvider]; the event list reads it from there.
///
/// It is a [ConsumerWidget] because it needs `ref` to reach a provider.
/// The typed text itself stays inside the TextField, so no controller
/// is needed. Fill, border and hint style come from the global
/// inputDecorationTheme in app_theme.dart.
class _SearchBar extends ConsumerWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextField(
      onChanged: (value) => ref.read(searchQueryProvider.notifier).set(value),
      decoration: const InputDecoration(
        hintText: 'Search events...',
        prefixIcon: Icon(Icons.search, color: kTextSub),
      ),
    );
  }
}

// ------------------------------------------------------------------
// Home tab: category chips
// ------------------------------------------------------------------

/// Horizontally scrolling chips: [kAllCategory] first, then every
/// category from the database. Tapping one stores it in
/// [selectedCategoryProvider].
class _CategoryChips extends ConsumerWidget {
  const _CategoryChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // watch = rebuild this widget whenever the value changes.
    final categories = ref.watch(categoriesProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);

    // A FutureProvider is always in one of three states, so .when
    // makes us handle all of them.
    return categories.when(
      // Empty box of the same height, so the layout doesn't jump.
      loading: () => const SizedBox(height: 40),
      error: (e, _) {
        debugPrint('Failed to load categories: $e');
        return const Text(
          'Could not load categories',
          style: TextStyle(color: kTextSub),
        );
      },
      data: (names) {
        // The "All" chip is not a database row; it is added here.
        final labels = [kAllCategory, ...names];

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...labels.map((label) {
                final isSelected = selectedCategory == label;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    // read (not watch): we only trigger a change here.
                    onSelected: (_) => ref
                        .read(selectedCategoryProvider.notifier)
                        .select(label),
                    selectedColor: kNavy,
                    backgroundColor: kSurface,
                    showCheckmark: false,
                    shape: const StadiumBorder(),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : kTextMain,
                      fontWeight: FontWeight.bold,
                    ),
                    side: BorderSide(color: isSelected ? kNavy : kBorder),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------
// Home tab: event list
// ------------------------------------------------------------------

/// Scrollable list of [EventCard]s.
///
/// Handles the three states of the database request:
///  - loading: spinner
///  - error:   message + Retry button
///  - data:    the filtered list, or "No events found" if nothing matches
///
/// It watches two providers on purpose. [upcomingEventsProvider] says
/// whether the request itself succeeded; [filteredEventsProvider] gives
/// the list after search and chip filtering. Pulling the list down
/// fetches fresh data from the database.
class _EventList extends ConsumerWidget {
  const _EventList();

  /// Fallback thumbnail colors for events without an image, reused in
  /// order.
  static const _accents = [kNavy, kAmber, kTextSub];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(upcomingEventsProvider);
    final events = ref.watch(filteredEventsProvider);

    return request.when(
      // ---- Loading ----
      loading: () => const Center(child: CircularProgressIndicator()),

      // ---- Error ----
      // Details go to the console; the user only sees a generic message.
      error: (e, _) {
        debugPrint('Failed to load events: $e');
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Could not load events',
                style: TextStyle(color: kTextSub),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                // invalidate = throw away the failed result and fetch again.
                onPressed: () => ref.invalidate(upcomingEventsProvider),
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
      // The request succeeded. An empty list here means the search or
      // chip matched nothing, not that something went wrong.
      data: (_) {
        if (events.isEmpty) {
          return const Center(
            child: Text('No events found', style: TextStyle(color: kTextSub)),
          );
        }

        return RefreshIndicator(
          color: kNavy,
          // refresh = fetch again; the spinner stays until it finishes.
          onRefresh: () => ref.refresh(upcomingEventsProvider.future),
          child: ListView.separated(
            // Keeps pull-to-refresh working even with only a few cards.
            physics: const AlwaysScrollableScrollPhysics(),
            // Room for the card's hover lift and shadow, which a list
            // would otherwise clip.
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 12),
            itemCount: events.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => EventCard(
              event: events[i],
              accent: _accents[i % _accents.length],
              // push (not go) keeps Home in the stack, so Back returns here.
              onTap: () => context.push('/participant/event/${events[i].id}'),
            ),
          ),
        );
      },
    );
  }
}