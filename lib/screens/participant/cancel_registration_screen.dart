import 'package:event_hive/core/theme/app_theme.dart';
import 'package:event_hive/core/utils/price_format.dart';
import 'package:event_hive/model/common/my_registration.dart';
import 'package:event_hive/provider/participant/registration_provider.dart';
import 'package:event_hive/widgets/common/app_header_bar.dart';
import 'package:event_hive/widgets/common/registration_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Lets the student review a registration and cancel it.
///
/// The warning says only what the database does: a registration with
/// money already verified is marked "refund pending" and the organizers
/// return the money outside the app; one with nothing paid just releases
/// the spot. The database refuses to cancel while a payment is waiting
/// for review, for a closed registration, or after the event, so those
/// cases are explained here and the button is disabled.
class CancelRegistrationScreen extends ConsumerStatefulWidget {
  /// UUID of the registration (`registration.registration_id`).
  final String registrationId;

  const CancelRegistrationScreen({super.key, required this.registrationId});

  @override
  ConsumerState<CancelRegistrationScreen> createState() =>
      _CancelRegistrationScreenState();
}

class _CancelRegistrationScreenState
    extends ConsumerState<CancelRegistrationScreen> {
  /// True while cancelling; stops double taps.
  bool _busy = false;

  /// Why the database refused, shown above the buttons.
  String? _error;

  String get _base => '/participant/my-events/registration/${widget.registrationId}';

  /// Why this registration cannot be cancelled right now, or null if it
  /// can.
  String? _blockedReason(MyRegistration reg) {
    if (reg.isDead) return 'This registration is already closed.';
    if (reg.tab == RegistrationTab.past) {
      return 'This event has already taken place, so it can no longer be '
          'cancelled.';
    }
    if (reg.waitingCount > 0) {
      return 'A payment of yours is waiting for review. You can cancel once '
          'it has been reviewed.';
    }
    return null;
  }

  /// The sentence under the warning title, depending on whether money
  /// was paid.
  String _warningText(MyRegistration reg) {
    if (reg.paid > 0) {
      return 'This action cannot be undone. Your verified payment of '
          '${formatBdt(reg.paid)} will be marked for a refund, which the '
          'organizers handle outside the app.';
    }
    return 'This action cannot be undone. Your spot will be released.';
  }

  Future<void> _cancel() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref
          .read(registrationActionsProvider)
          .cancel(widget.registrationId);
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Registration cancelled')));
      context.go('/participant/my-events');

      // Every screen that shows this registration reloads.
      ref.invalidate(myRegistrationsProvider);
      ref.invalidate(registrationDetailsProvider(widget.registrationId));
      ref.invalidate(registrationBalanceProvider(widget.registrationId));
    } on RegistrationException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      debugPrint('Unexpected error while cancelling: $e');
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Back to the previous screen, or to the registration after a refresh.
  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(_base);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(registrationDetailsProvider(widget.registrationId));

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppHeaderBar(title: 'Cancel registration', fallbackRoute: _base),
              const SizedBox(height: 16),
              Expanded(
                child: request.when(
                  // ---- Loading ----
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),

                  // ---- Error ----
                  // Details go to the console; the user sees a generic message.
                  error: (e, _) {
                    debugPrint('Failed to load registration: $e');
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
                              registrationDetailsProvider(
                                widget.registrationId,
                              ),
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
                  data: (reg) {
                    final blocked = _blockedReason(reg);

                    return Column(
                      children: [
                        Expanded(
                          child: ListView(
                            children: [
                              // A red warning when cancelling is possible,
                              // a plain note when it is not.
                              if (blocked == null)
                                _WarningBanner(text: _warningText(reg))
                              else
                                _BlockedNote(text: blocked),
                              const SizedBox(height: 12),
                              EventSummaryCard(reg: reg),
                              const SizedBox(height: 12),
                              DetailsCard(
                                rows: [
                                  DetailRow(label: 'Role', value: reg.roleLabel),
                                  DetailRow(
                                    label: 'Add-ons',
                                    value: reg.addOnsLabel,
                                  ),
                                  DetailRow(
                                    label: 'Total paid',
                                    value: reg.paid > 0
                                        ? formatBdt(reg.paid)
                                        : 'Nothing yet',
                                  ),
                                ],
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  _error!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),

                        // ---- Buttons ----
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            // null = disabled while cancelling, or when
                            // the database would refuse.
                            onPressed: (blocked != null || _busy)
                                ? null
                                : _cancel,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kDanger,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: kDanger.withValues(
                                alpha: 0.4,
                              ),
                              disabledForegroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _busy
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Cancel registration',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton(
                            onPressed: _busy ? null : _back,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kTextMain,
                              side: const BorderSide(color: kNavy, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Back',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Red warning at the top: a title and what cancelling does.
class _WarningBanner extends StatelessWidget {
  final String text;
  const _WarningBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kDangerSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kDanger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 20, color: kDanger),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Are you sure you want to cancel your registration?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: kDanger,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: kDanger,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Neutral note shown when the registration cannot be cancelled.
class _BlockedNote extends StatelessWidget {
  final String text;
  const _BlockedNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kBorder,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: kTextMain),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: kTextMain),
            ),
          ),
        ],
      ),
    );
  }
}