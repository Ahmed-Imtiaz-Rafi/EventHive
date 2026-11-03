import 'package:event_hive/core/theme/app_theme.dart';
import 'package:event_hive/core/utils/event_date_time_format.dart';
import 'package:event_hive/core/utils/price_format.dart';
import 'package:event_hive/model/common/payment_account.dart';
import 'package:event_hive/model/common/registration_balance.dart';
import 'package:event_hive/provider/common/user_provider.dart';
import 'package:event_hive/provider/participant/registration_provider.dart';
import 'package:event_hive/screens/participant/registration_status_view.dart';
import 'package:event_hive/widgets/common/app_header_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The screen for one registration: it pays it, or shows where it stands.
///
/// What it shows depends on the registration's state, read from the
/// database through [registrationBalanceProvider]:
///  - payable (pending, in time, nothing waiting): the amount, the club's
///    receiving accounts, and a box to report the payment;
///  - anything else (confirmed or free, a payment waiting for review,
///    cancelled or past its payment window): [RegistrationStatusView].
///
/// Payment is manual: the participant pays in bKash or Nagad outside the
/// app, then enters the transaction ID here. An organizer checks it
/// against the account statement and approves it.
class PaymentScreen extends ConsumerWidget {
  /// UUID of the registration (`registration.registration_id`).
  final String registrationId;

  const PaymentScreen({super.key, required this.registrationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(registrationBalanceProvider(registrationId));

    // The title follows the state: paying, or just looking.
    final title = request.maybeWhen(
      data: (b) => _isPayable(b) ? 'Payment' : 'Registration status',
      orElse: () => 'Payment',
    );

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppHeaderBar(
                title: title,
                // Registrations are listed on My events.
                fallbackRoute: '/participant/my-events',
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
                              registrationBalanceProvider(registrationId),
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
                  data: (balance) => _BalanceView(balance: balance),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// True while the participant can still pay: the registration is pending,
/// inside its payment window, with no payment waiting for review.
bool _isPayable(RegistrationBalance b) =>
    b.status == 'pending' && !b.isExpired && b.waitingCount == 0;

/// Picks what to show for the registration's current state.
class _BalanceView extends StatelessWidget {
  final RegistrationBalance balance;
  const _BalanceView({required this.balance});

  @override
  Widget build(BuildContext context) {
    if (_isPayable(balance)) return _PayView(balance: balance);
    return RegistrationStatusView(balance: balance);
  }
}

// ------------------------------------------------------------------
// Pay view
// ------------------------------------------------------------------

/// The payment form: amount, accounts to choose from, and the Pay button.
///
/// It is a [ConsumerStatefulWidget] because it needs providers and also
/// remembers one thing locally: which account is selected.
class _PayView extends ConsumerStatefulWidget {
  final RegistrationBalance balance;
  const _PayView({required this.balance});

  @override
  ConsumerState<_PayView> createState() => _PayViewState();
}

class _PayViewState extends ConsumerState<_PayView> {
  /// The account the participant has chosen, or null before any choice.
  /// Nothing is preselected: choosing decides where the money is sent,
  /// so it should be a deliberate tap.
  PaymentAccount? _selected;

  /// Opens the box for [account]. When it closes, the registration is
  /// reloaded: a submitted payment changes what the screen shows.
  Future<void> _openBox(PaymentAccount account) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _PaymentBox(
        registrationId: widget.balance.registrationId,
        account: account,
        amount: widget.balance.remaining,
      ),
    );

    if (!mounted) return;
    ref.invalidate(registrationBalanceProvider(widget.balance.registrationId));
    // My events shows the new state too.
    ref.invalidate(myRegistrationsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final balance = widget.balance;
    final accounts = ref.watch(paymentAccountsProvider(balance.eventId));
    // Watched only to start loading the student ID early; the payment box
    // uses it to fill in the reference.
    ref.watch(currentStudentIdProvider);

    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              const _SecureNote(),
              const SizedBox(height: 12),
              _DeadlineNote(balance: balance),
              const SizedBox(height: 20),
              const Text(
                'Payment method',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: kTextMain,
                ),
              ),
              const SizedBox(height: 10),
              accounts.when(
                // ---- Loading ----
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),

                // ---- Error ----
                error: (e, _) {
                  debugPrint('Failed to load payment accounts: $e');
                  return Column(
                    children: [
                      const Text(
                        'Could not load payment methods',
                        style: TextStyle(color: kTextSub),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(
                          paymentAccountsProvider(balance.eventId),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kNavy,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  );
                },

                // ---- Data ----
                data: (list) {
                  if (list.isEmpty) {
                    return const Text(
                      'Payment is not set up for this event yet. '
                      'Please contact the organizers.',
                      style: TextStyle(color: kTextSub),
                    );
                  }

                  // When a provider has two accounts (send money and
                  // payment), show which is which on the cards.
                  final providerCount = <String, int>{};
                  for (final a in list) {
                    providerCount[a.provider] =
                        (providerCount[a.provider] ?? 0) + 1;
                  }

                  return Column(
                    children: [
                      for (final account in list) ...[
                        _MethodCard(
                          account: account,
                          showKind: (providerCount[account.provider] ?? 0) > 1,
                          selected: _selected?.accountId == account.accountId,
                          onTap: () => setState(() => _selected = account),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),

        // ---- Fixed bottom: amount and Pay ----
        const Divider(color: kBorder),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              // Part of the money may already be verified.
              balance.paid > 0 ? 'Remaining' : 'Total',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: kTextMain,
              ),
            ),
            Text(
              formatBdt(balance.remaining),
              style: const TextStyle(
                fontSize: 20,
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
            // null = disabled until an account is chosen.
            onPressed: _selected == null ? null : () => _openBox(_selected!),
            style: ElevatedButton.styleFrom(
              backgroundColor: kAmber,
              foregroundColor: Colors.white,
              disabledBackgroundColor: kAmber.withValues(alpha: 0.5),
              disabledForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'Pay ${formatBdt(balance.remaining)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        TextButton(
          onPressed: () => context.push(
            '/participant/my-events/registration/'
            '${balance.registrationId}/cancel',
          ),
          child: const Text(
            'Cancel registration',
            style: TextStyle(color: kDanger, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

/// Reassuring note at the top of the screen.
class _SecureNote extends StatelessWidget {
  const _SecureNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kBorder,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline, size: 18, color: kTextSub),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure payment',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: kTextMain,
                  ),
                ),
                Text(
                  'Your information is safe with us.',
                  style: TextStyle(fontSize: 12, color: kTextSub),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tells the participant how long their seat is held, and how much has
/// already been verified when they are paying in parts.
class _DeadlineNote extends StatelessWidget {
  final RegistrationBalance balance;
  const _DeadlineNote({required this.balance});

  @override
  Widget build(BuildContext context) {
    final expires = balance.expiresAt;
    final lines = <String>[
      if (expires != null)
        'Pay before ${formatEventDate(expires)} · ${formatEventTime(expires)} '
            'or your spot is released.',
      if (balance.paid > 0)
        'Verified so far: ${formatBdt(balance.paid)} of '
            '${formatBdt(balance.total)}.',
    ];
    if (lines.isEmpty) return const SizedBox.shrink();

    return Text(
      lines.join('\n'),
      style: const TextStyle(fontSize: 13, height: 1.4, color: kTextSub),
    );
  }
}

/// One selectable receiving account: icon, provider name and a radio
/// dot. The selected card gets a navy border and a filled dot.
class _MethodCard extends StatelessWidget {
  final PaymentAccount account;

  /// Shows "Send money" or "Payment" under the name, to tell two
  /// accounts of the same provider apart.
  final bool showKind;
  final bool selected;
  final VoidCallback onTap;

  const _MethodCard({
    required this.account,
    required this.showKind,
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(16),
            // Same width in both states, so the card never shifts.
            border: Border.all(color: selected ? kNavy : kBorder, width: 1.5),
          ),
          child: Row(
            children: [
              const Icon(Icons.smartphone_outlined, size: 20, color: kTextMain),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.providerName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: kTextMain,
                      ),
                    ),
                    if (showKind)
                      Text(
                        account.kindName,
                        style: const TextStyle(fontSize: 12, color: kTextSub),
                      ),
                  ],
                ),
              ),
              _RadioDot(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round selection marker: an empty ring, or a ring with a filled
/// center when selected.
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
// Payment box
// ------------------------------------------------------------------

/// The box that opens when the participant taps Pay.
///
/// It shows where to send the money (the account number, whether to use
/// "Send money" or "Payment", and the club's instructions), then asks for
/// the reference (the student ID) and the transaction ID. Confirm sends
/// the payment to the database; if the database refuses it (for example
/// the transaction ID was used before) the reason is shown in the box and
/// the participant can correct it.
class _PaymentBox extends ConsumerStatefulWidget {
  final String registrationId;
  final PaymentAccount account;

  /// How much the participant should pay now (BDT).
  final double amount;

  const _PaymentBox({
    required this.registrationId,
    required this.account,
    required this.amount,
  });

  @override
  ConsumerState<_PaymentBox> createState() => _PaymentBoxState();
}

class _PaymentBoxState extends ConsumerState<_PaymentBox> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _refCtrl;
  final _trxCtrl = TextEditingController();

  /// True while the payment is being sent; stops double taps and closing.
  bool _busy = false;

  /// Why the database refused the payment, shown inside the box.
  String? _error;

  @override
  void initState() {
    super.initState();
    // The reference is the student ID. Fill it in from the profile when
    // it has loaded, so the participant only has to check it.
    final studentId = ref
        .read(currentStudentIdProvider)
        .maybeWhen(data: (id) => id, orElse: () => null);
    _refCtrl = TextEditingController(text: studentId ?? '');
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    _trxCtrl.dispose();
    super.dispose();
  }

  /// Validates both fields, sends the payment and, if the database
  /// accepts it, closes the box.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref
          .read(registrationActionsProvider)
          .submitPayment(
            registrationId: widget.registrationId,
            accountId: widget.account.accountId,
            transactionId: _trxCtrl.text,
            reference: _refCtrl.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on RegistrationException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      debugPrint('Unexpected error while submitting payment: $e');
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Copies the account number so it can be pasted into the banking app.
  Future<void> _copyNumber() async {
    await Clipboard.setData(ClipboardData(text: widget.account.number));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Number copied')));
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final instructions = account.instructions?.trim();

    // While the payment is being sent the box cannot be closed.
    return PopScope(
      canPop: !_busy,
      child: Dialog(
        backgroundColor: kSurface,
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          // Scrolls when the keyboard takes space, instead of overflowing.
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---- Title and close ----
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          account.providerName,
                          style: const TextStyle(
                            fontFamily: 'serif',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: kTextMain,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: kTextMain),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ---- Where to send the money ----
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: kBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${account.providerName} number',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: kTextSub,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                account.number,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: kTextMain,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Amount: ${formatBdt(widget.amount)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: kTextSub,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _copyNumber,
                          icon: const Icon(
                            Icons.copy_outlined,
                            size: 20,
                            color: kTextMain,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // "Send money" or "Payment": how to pay this number.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: kNavy,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      account.kindName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  // The club's own guide, when it wrote one.
                  if (instructions != null && instructions.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      instructions,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: kTextSub,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // ---- Reference: the student ID ----
                  const Text(
                    'Reference (your student ID)',
                    style: TextStyle(fontSize: 12, color: kTextSub),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _refCtrl,
                    enabled: !_busy,
                    decoration: const InputDecoration(hintText: 'Student ID'),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Enter your student ID'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // ---- Transaction ID ----
                  const Text(
                    'Transaction ID',
                    style: TextStyle(fontSize: 12, color: kTextSub),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _trxCtrl,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.characters,
                    // Letters and numbers only.
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    ],
                    decoration: const InputDecoration(
                      hintText: 'e.g. 8N7A6D5E4C',
                    ),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'Enter the transaction ID';
                      // Same rule as the database: 6 to 30 letters/numbers.
                      if (!RegExp(r'^[A-Za-z0-9]{6,30}$').hasMatch(value)) {
                        return 'Use 6 to 30 letters and numbers';
                      }
                      return null;
                    },
                  ),

                  // Why the database refused the payment, if it did.
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
                  const SizedBox(height: 20),

                  // ---- Confirm ----
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kNavy,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: kNavy,
                        disabledForegroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
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
                              'Confirm',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
