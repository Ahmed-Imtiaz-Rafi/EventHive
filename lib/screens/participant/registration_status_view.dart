import 'package:event_hive/core/theme/app_theme.dart';
import 'package:event_hive/model/common/my_registration.dart';
import 'package:event_hive/model/common/registration_balance.dart';
import 'package:event_hive/provider/participant/registration_provider.dart';
import 'package:event_hive/widgets/common/registration_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// What a registration looks like once there is nothing left to pay:
/// confirmed, waiting for an organizer to review a payment, or closed.
///
/// Shown inside the Payment screen for those states, and reached from My
/// events. It reads the registration (event, role, add-ons) through
/// [registrationDetailsProvider]; [balance] only identifies which one.
/// A confirmed registration offers "View ticket"; a live one that has not
/// taken place yet also offers "Cancel registration".
class RegistrationStatusView extends ConsumerWidget {
  final RegistrationBalance balance;
  const RegistrationStatusView({super.key, required this.balance});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(
      registrationDetailsProvider(balance.registrationId),
    );

    return request.when(
      // ---- Loading ----
      loading: () => const Center(child: CircularProgressIndicator()),

      // ---- Error ----
      // Details go to the console; the user sees a generic message.
      error: (e, _) {
        debugPrint('Failed to load registration details: $e');
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Could not load this registration',
                style: TextStyle(color: kTextSub),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(
                  registrationDetailsProvider(balance.registrationId),
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
      data: (reg) => _StatusContent(reg: reg),
    );
  }
}

/// The status page for one registration.
class _StatusContent extends StatelessWidget {
  final MyRegistration reg;
  const _StatusContent({required this.reg});

  /// Where this registration's own pages live (inside the My events tab).
  String get _base => '/participant/my-events/registration/${reg.registrationId}';

  @override
  Widget build(BuildContext context) {
    final confirmed = reg.status == 'confirmed';

    // A live registration of an event that has not taken place yet can
    // still be cancelled.
    final canCancel = !reg.isDead && reg.tab == RegistrationTab.upcoming;

    // Icon, title and sentence depend on where the registration stands.
    final IconData icon;
    final String title;
    final String subtitle;
    if (confirmed) {
      icon = Icons.check;
      title = 'Registration confirmed!';
      subtitle = 'You are registered for ${reg.eventTitle}.';
    } else if (reg.isDead) {
      icon = Icons.close;
      title = 'Registration closed';
      subtitle = reg.paymentStatus == 'refund_pending'
          ? 'This registration was cancelled. Your refund is pending.'
          : 'This registration was cancelled or its payment time ended.';
    } else {
      icon = Icons.hourglass_empty;
      title = 'Payment submitted';
      subtitle =
          'An organizer will check your transaction. You will be '
          'confirmed once it is approved.';
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              const SizedBox(height: 12),
              // ---- Badge, title, sentence ----
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: kNavy,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 32, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: kTextMain,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: kTextSub),
              ),
              const SizedBox(height: 20),

              // ---- The event, then the details ----
              EventSummaryCard(reg: reg),
              const SizedBox(height: 12),
              DetailsCard(
                rows: [
                  DetailRow(label: 'Role', value: reg.roleLabel),
                  DetailRow(label: 'Add-ons', value: reg.addOnsLabel),
                  DetailRow(label: 'Payment status', chip: reg.paymentLabel),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),

        // ---- Buttons ----
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: confirmed
                ? () => context.push('$_base/ticket')
                : () => context.go('/participant/my-events'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kAmber,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              confirmed ? 'View ticket' : 'Back to events',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        if (canCancel)
          TextButton(
            onPressed: () => context.push('$_base/cancel'),
            child: const Text(
              'Cancel registration',
              style: TextStyle(color: kDanger, fontWeight: FontWeight.bold),
            ),
          )
        else
          const SizedBox(height: 12),
      ],
    );
  }
}