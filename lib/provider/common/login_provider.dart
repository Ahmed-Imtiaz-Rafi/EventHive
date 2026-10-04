import 'package:flutter_riverpod/flutter_riverpod.dart';

class RoleNotifier extends Notifier<String> {
  @override
  String build() => 'Participant';

  void select(String role) => state = role;
}

final roleProvider = NotifierProvider<RoleNotifier, String>(RoleNotifier.new);

class ObscureNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final obscureProvider = NotifierProvider<ObscureNotifier, bool>(
  ObscureNotifier.new,
);
