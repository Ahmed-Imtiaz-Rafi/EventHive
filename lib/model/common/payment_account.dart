/// A receiving account (bKash or Nagad number) of a club, where
/// participants send their payment. One row of `payment_accounts` joined
/// to its `payment_methods` row. Managed by admins.
class PaymentAccount {
  /// Primary key; `submit_payment` needs it to say which account was used.
  final int accountId;

  /// The number to pay, 11 digits.
  final String number;

  /// Guide shown to the student, e.g. "Use Send Money, write your student
  /// ID in the reference box". Null when the admin left it out.
  final String? instructions;

  /// 'bkash' or 'nagad'.
  final String provider;

  /// 'send_money' or 'payment'.
  final String kind;

  const PaymentAccount({
    required this.accountId,
    required this.number,
    required this.instructions,
    required this.provider,
    required this.kind,
  });

  /// 'bKash', 'Nagad', or the provider name capitalized for any other.
  String get providerName {
    switch (provider.toLowerCase()) {
      case 'bkash':
        return 'bKash';
      case 'nagad':
        return 'Nagad';
      default:
        return provider.isEmpty
            ? provider
            : '${provider[0].toUpperCase()}${provider.substring(1)}';
    }
  }

  /// 'Send money' or 'Payment': how the number should be paid.
  String get kindName {
    switch (kind) {
      case 'send_money':
        return 'Send money';
      case 'payment':
        return 'Payment';
      default:
        return kind;
    }
  }

  /// Builds a [PaymentAccount] from one `payment_accounts` row with its
  /// `payment_methods` row embedded.
  factory PaymentAccount.fromMap(Map<String, dynamic> map) {
    final method = map['payment_methods'] as Map<String, dynamic>;
    return PaymentAccount(
      accountId: map['account_id'] as int,
      number: map['account_number'] as String,
      instructions: map['instructions'] as String?,
      provider: method['provider'] as String,
      kind: method['kind'] as String,
    );
  }
}