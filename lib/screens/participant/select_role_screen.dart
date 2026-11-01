import 'package:event_hive/core/theme/app_theme.dart';
import 'package:event_hive/core/utils/item_icon.dart';
import 'package:event_hive/core/utils/price_format.dart';
import 'package:event_hive/model/common/event_role.dart';
import 'package:event_hive/provider/participant/registration_draft_provider.dart';
import 'package:event_hive/provider/participant/role_provider.dart';
import 'package:event_hive/widgets/common/app_header_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// First step of registration: the participant picks a role for the
/// event (and a track, when the role has tracks), each role with its
/// own fee, then continues to the add-ons.
///
/// The roles come from the database through [eventRolesProvider]; only
/// roles the organizer listed for this event appear. The choice is saved
/// into [registrationDraftProvider] for the next steps.
///
/// It is a [ConsumerStatefulWidget] because it needs providers and also
/// remembers two things locally: the selected role and track.
class SelectRoleScreen extends ConsumerStatefulWidget {
  /// UUID of the event being registered for (`events.event_id`).
  final String eventId;

  const SelectRoleScreen({super.key, required this.eventId});

  @override
  ConsumerState<SelectRoleScreen> createState() => _SelectRoleScreenState();
}

class _SelectRoleScreenState extends ConsumerState<SelectRoleScreen> {
  // ------------------------------------------------------------------
  // State
  // ------------------------------------------------------------------

  /// Name of the role the participant has chosen, or null before any
  /// choice. Nothing is preselected: this step decides what the
  /// participant pays.
  String? _selectedName;

  /// The chosen track, when the selected role has tracks.
  String? _selectedTrack;

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(eventRolesProvider(widget.eventId));

    // The loaded roles, or an empty list while loading or on error.
    // maybeWhen is safe in every state; it never throws on errors.
    final roles = request.maybeWhen(
      data: (list) => list,
      orElse: () => <EventRole>[],
    );

    // The chosen role as an object, or null if nothing is chosen.
    final selected = roles.where((r) => r.name == _selectedName).firstOrNull;

    // A role with tracks is not complete until a track is chosen.
    final canContinue =
        selected != null && (!selected.hasTracks || _selectedTrack != null);

    // The role to register as once the choice is complete, otherwise null.
    // Checked directly below, which works on every Dart version.
    final choice = canContinue ? selected : null;

    // The total will also include add-ons on the next screen.
    final total = selected?.price ?? 0;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppHeaderBar(
                title: 'Select role',
                // Without a previous screen, go to this event's details.
                fallbackRoute: '/participant/event/${widget.eventId}',
              ),
              const SizedBox(height: 16),
              const Text(
                'Choose your role for this event',
                style: TextStyle(fontSize: 14, color: kTextSub),
              ),
              const SizedBox(height: 12),

              // ---- Role list ----
              // Expanded gives this area all the space between the prompt
              // and the bottom section.
              Expanded(
                child: request.when(
                  // ---- Loading ----
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),

                  // ---- Error ----
                  // Details go to the console; the user sees a generic message.
                  error: (e, _) {
                    debugPrint('Failed to load roles: $e');
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Could not load roles',
                            style: TextStyle(color: kTextSub),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            // invalidate = throw away the failed result
                            // and fetch again.
                            onPressed: () => ref.invalidate(
                              eventRolesProvider(widget.eventId),
                            ),
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
                  data: (list) {
                    // Only roles the organizer listed can be taken, so an
                    // empty list means registration is not open yet.
                    if (list.isEmpty) {
                      return const Center(
                        child: Text(
                          'No roles are open for registration yet.',
                          style: TextStyle(color: kTextSub),
                        ),
                      );
                    }

                    return ListView(
                      children: [
                        for (final role in list) ...[
                          _RoleCard(
                            role: role,
                            selected: _selectedName == role.name,
                            onTap: () => setState(() {
                              // Another role means the old track no
                              // longer applies.
                              if (_selectedName != role.name) {
                                _selectedTrack = null;
                              }
                              _selectedName = role.name;
                            }),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Tracks of the selected role, when it has any.
                        if (selected != null && selected.hasTracks)
                          _TrackPicker(
                            roleName: selected.name,
                            tracks: selected.tracks,
                            selected: _selectedTrack,
                            onSelected: (track) =>
                                setState(() => _selectedTrack = track),
                          ),
                      ],
                    );
                  },
                ),
              ),

              // ---- Bottom section: total and Continue ----
              const Divider(color: kBorder),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Selected total',
                    style: TextStyle(fontSize: 14, color: kTextSub),
                  ),
                  Text(
                    formatBdt(total),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kTextMain,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  // null = disabled until a role (and its track) is chosen.
                  onPressed: choice == null
                      ? null
                      : () {
                          // Remember the choice for the next steps.
                          ref
                              .read(registrationDraftProvider.notifier)
                              .selectRole(
                                widget.eventId,
                                choice,
                                trackName: choice.hasTracks
                                    ? _selectedTrack
                                    : null,
                              );
                          // push keeps this screen, so Back returns here.
                          context.push(
                            '/participant/event/${widget.eventId}/addons',
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAmber,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: kAmber.withValues(alpha: 0.5),
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

// ------------------------------------------------------------------
// Role card
// ------------------------------------------------------------------

/// One selectable role: icon, name, description, fee and a radio dot.
/// The selected card gets a navy border, a navy icon square and a
/// filled dot.
class _RoleCard extends StatelessWidget {
  final EventRole role;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final description = role.description?.trim();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(16),
            // Same width in both states, so the card never shifts.
            border: Border.all(color: selected ? kNavy : kBorder, width: 1.5),
          ),
          child: Row(
            children: [
              // ---- Icon square ----
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? kNavy : kBorder,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  iconForName(role.name, fallback: Icons.badge_outlined),
                  size: 22,
                  color: selected ? Colors.white : kTextSub,
                ),
              ),
              const SizedBox(width: 12),

              // ---- Name, description, fee ----
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.name,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kTextMain,
                      ),
                    ),
                    if (description != null && description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: const TextStyle(fontSize: 12, color: kTextSub),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      role.isFree ? 'Free' : formatBdt(role.price),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: kAmber,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              _RadioDot(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round selection marker: an empty ring, or a ring with a filled
/// center when selected. Drawn by hand so it does not depend on
/// Flutter's Radio widget, whose API changes between versions.
class _RadioDot extends StatelessWidget {
  final bool selected;
  const _RadioDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: selected ? kNavy : kBorder, width: 2),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: kNavy,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}

// ------------------------------------------------------------------
// Track picker
// ------------------------------------------------------------------

/// Buttons for the tracks of the selected role, for example Music or
/// Poetry for a Performer. Shows a reminder until one is chosen.
class _TrackPicker extends StatelessWidget {
  final String roleName;
  final List<String> tracks;
  final String? selected;
  final ValueChanged<String> onSelected;

  const _TrackPicker({
    required this.roleName,
    required this.tracks,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Choose a track for $roleName',
          style: const TextStyle(fontSize: 14, color: kTextSub),
        ),
        const SizedBox(height: 8),
        // Wrap moves buttons to the next line on narrow screens.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final track in tracks)
              _TrackChip(
                label: track,
                selected: track == selected,
                onTap: () => onSelected(track),
              ),
          ],
        ),
        if (selected == null) ...[
          const SizedBox(height: 6),
          const Text(
            'Choose a track to continue',
            style: TextStyle(fontSize: 12, color: kAmber),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

/// One track button: navy when selected, white otherwise.
class _TrackChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TrackChip({
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? kNavy : kSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? kNavy : kBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : kTextMain,
            ),
          ),
        ),
      ),
    );
  }
}
