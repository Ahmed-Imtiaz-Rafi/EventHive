import 'package:event_hive/core/theme/app_theme.dart';
import 'package:event_hive/core/utils/ticket_saver.dart';
import 'package:event_hive/model/common/my_registration.dart';
import 'package:event_hive/provider/common/user_provider.dart';
import 'package:event_hive/provider/participant/registration_provider.dart';
import 'package:event_hive/widgets/common/app_header_bar.dart';
import 'package:event_hive/widgets/common/registration_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The student's ticket for a confirmed registration: the event, their
/// name, role, add-ons and payment status, which can be saved as a
/// picture.
///
/// The name is the username, because the database has no full-name
/// column. A registration that is not confirmed has no ticket yet.
class MyTicketScreen extends ConsumerStatefulWidget {
  /// UUID of the registration (`registration.registration_id`).
  final String registrationId;

  const MyTicketScreen({super.key, required this.registrationId});

  @override
  ConsumerState<MyTicketScreen> createState() => _MyTicketScreenState();
}

class _MyTicketScreenState extends ConsumerState<MyTicketScreen> {
  /// Marks the part of the screen that is saved as the picture.
  final _ticketKey = GlobalKey();

  /// True while the picture is being made; stops double taps.
  bool _busy = false;

  /// 'Tech Fest 2027' becomes 'tech-fest-2027', for the file name.
  String _slug(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  Future<void> _save(MyRegistration reg) async {
    final boundary =
        _ticketKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    setState(() => _busy = true);
    try {
      await saveTicketImage(
        boundary,
        fileName: 'ticket-${_slug(reg.eventTitle)}',
      );
      if (mounted) _message('Ticket saved');
    } catch (e) {
      debugPrint('Could not save the ticket: $e');
      if (mounted) _message('Could not save the ticket. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(registrationDetailsProvider(widget.registrationId));
    final name = ref
        .watch(currentUsernameProvider)
        .maybeWhen(data: (n) => n, orElse: () => '');

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppHeaderBar(
                title: 'My ticket',
                fallbackRoute:
                    '/participant/my-events/registration/${widget.registrationId}',
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
                    debugPrint('Failed to load ticket: $e');
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Could not load your ticket',
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
                    // Only a confirmed registration has a ticket.
                    if (reg.status != 'confirmed') {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'Your ticket is available once your registration '
                            'is confirmed.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: kTextSub),
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        Expanded(
                          child: ListView(
                            children: [
                              // Everything inside the boundary becomes the
                              // saved picture, so it has its own background.
                              RepaintBoundary(
                                key: _ticketKey,
                                child: Container(
                                  color: kBg,
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    children: [
                                      EventSummaryCard(
                                        reg: reg,
                                        chip: reg.statusLabel,
                                      ),
                                      const SizedBox(height: 12),
                                      DetailsCard(
                                        rows: [
                                          DetailRow(
                                            label: 'Name',
                                            value: name,
                                          ),
                                          DetailRow(
                                            label: 'Role',
                                            value: reg.roleLabel,
                                          ),
                                          DetailRow(
                                            label: 'Add-ons',
                                            value: reg.addOnsLabel,
                                          ),
                                          DetailRow(
                                            label: 'Payment status',
                                            chip: reg.paymentLabel,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _busy ? null : () => _save(reg),
                            icon: _busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.download_outlined),
                            label: const Text(
                              'Save to gallery',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kAmber,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: kAmber.withValues(
                                alpha: 0.5,
                              ),
                              disabledForegroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
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