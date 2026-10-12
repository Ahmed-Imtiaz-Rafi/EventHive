import 'package:event_hive/core/theme/app_theme.dart';
import 'package:event_hive/provider/common/login_provider.dart';
import 'package:event_hive/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Login screen shared by every role (participant / organizer).
/// Flow:
/// 1. User enters email + password and taps **Log In**.
/// 2. We authenticate with Supabase, then look up which roles the account
///    holds (`user_role` table) and whether an organizer application is
///    still pending (`organizer_requests` table).
/// 3. 0 or 1 option  -> navigate straight to that role's home.
///    2+ options     -> show a "Continue as" chip picker; the user picks
///                      one and taps **Continue**.
///
/// A [ConsumerStatefulWidget] that combines a Flutter [StatefulWidget] with Riverpod.
/// 
/// **Why used here:**
/// - **Local State & Controllers:** Required because this widget manages local state 
///   (forms, loading flags, role options) or UI controllers (e.g., text controllers) 
///   alongside Riverpod (such as using `obscureProvider` for the password toggle).
/// - **Global State Access:** Provides seamless access to the [ref] object across lifecycle 
///   methods like [initState] and throughout the state class without passing [BuildContext].

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // ------------------------------------------------------------------
  // State
  // ------------------------------------------------------------------

  /// Key used to validate the email/password fields together.
  final _formKey = GlobalKey<FormState>();

  /// Controllers that hold the text typed in each field.
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  /// True while login / role lookup is in progress (disables the button
  /// and fields, shows a spinner).
  bool _loading = false;

  // Each entry is one thing the picker can show: a real held role
  // ('participant', 'organizer'), or the special 'pending' entry for
  // an organizer application still awaiting approval. label is what's
  // shown on the chip; target is what gets passed to goToRoleHome.
  List<_RoleOption> _options = [];

  /// The `target` of the chip currently selected in the picker.
  /// Null until the picker is shown.
  String? _selectedTarget;

  /// Controllers must be disposed manually to avoid memory leaks.
  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Step 1: authenticate + fetch this user's real roles.
  // Does NOT navigate yet if the person holds more than one role —
  // in that case we reveal the chip picker and wait for them to pick.
  // ------------------------------------------------------------------
  
  /// Validates the form, signs in with Supabase, loads the user's roles
  /// and pending organizer request, then either navigates or reveals the
  /// role picker. All errors are shown as a generic snackbar (details go
  /// to the debug console only, so internals aren't leaked to the user).

  Future<void> _login() async {
    // Stop here if email/password validators fail.
    if (!_formKey.currentState!.validate()) return;

    // Reset any previous picker state and show the loading indicator.
    setState(() {
      _loading = true;
      _options = [];
      _selectedTarget = null;
    });

    try {
      // Authenticate. Throws AuthException on wrong credentials.
      final authResponse = await Supabase.instance.client.auth
          .signInWithPassword(
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text,
          );

      final userId = authResponse.user?.id;
      if (userId == null) {
        throw const AuthException('Login failed. Please try again.');
      }

      // 1. What roles does this user actually hold?
      final roleRows = await Supabase.instance.client
          .from('user_role')
          .select('role')
          .eq('user_id', userId);

      final roles = (roleRows as List)
          .map((row) => row['role'] as String)
          .toList();

      // 2. Do they also have a pending organizer application?
      //    (True even when they already hold 'participant' — that's
      //    the exact case this fix is for: granted participant
      //    immediately, organizer still awaiting approval.)
      //    maybeSingle() returns null when there is no matching row.
      final pendingRequest = await Supabase.instance.client
          .from('organizer_requests')
          .select('request_id')
          .eq('user_id', userId)
          .eq('status', 'pending')
          .maybeSingle();

      // The widget may have been closed while we were awaiting; using
      // `context` after that would crash, so bail out.      
      if (!mounted) return;

      // Build the list of choices: one per real role, plus a
      // "Pending" entry if an organizer application is waiting.
      final options = <_RoleOption>[
        for (final r in roles) _RoleOption(label: _capitalize(r), target: r),
        if (pendingRequest != null)
          const _RoleOption(label: 'Organizer (Pending)', target: 'pending'),
      ];

      if (options.isEmpty) {
        // Genuinely nothing — no role, no pending request. Shouldn't
        // normally happen given the signup trigger, but handled
        // defensively rather than silently doing nothing.
        goToRoleHome(context, 'pending');
        return;
      }

      if (options.length == 1) {
        // Nothing to choose between — go straight in.
        goToRoleHome(context, options.first.target);
        return;
      }

      // More than one real option (e.g. Participant + Organizer, or
      // Participant + Organizer (Pending)) — let them choose.
      // The first option is pre-selected for convenience.      
      setState(() {
        _options = options;
        _selectedTarget = options.first.target;
      });
    } on PostgrestException catch (e) {
      // Database/query error (e.g. table or RLS problem).
      debugPrint('Postgrest error during login: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again.'),
          ),
        );
      }
    } catch (e) {
      // Anything else, including AuthException (wrong password, etc.).
      debugPrint('Unexpected error during login: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again.'),
          ),
        );
      }
    } finally {
      // Always stop the spinner, success or failure.
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Called by the **Continue** button once the picker is visible.
  void _continueWithSelectedRole() {
    if (_selectedTarget == null) return;
    goToRoleHome(context, _selectedTarget!);
  }

  /// 'participant' -> 'Participant'. Used for chip labels.
  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // ------------------------------------------------------------------
  // Step 2: only reached when the picker was shown — the person has
  // now chosen which of their real roles to continue as.
  // ------------------------------------------------------------------

  // ------------------------------------------------------------------
  // UI helpers
  // ------------------------------------------------------------------

  /// Shared look for the text fields: white filled rounded box, grey
  /// hint, leading [icon], optional [suffix] (e.g. the eye button),
  /// and an amber border when focused.
  InputDecoration _decoration(String hint, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.grey),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kAmber, width: 1.5),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------
  
  @override
  Widget build(BuildContext context) {
    // Rebuilds whenever the password-visibility toggle changes.
    final obscure = ref.watch(obscureProvider);

    // Picker is only meaningful when there is more than one choice.
    final showRolePicker = _options.length > 1;

    return Scaffold(
      backgroundColor: kBg,
      // Scrollable so the keyboard never overflows the screen.
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ---- Navy header banner ("Welcome back, / Log In") ----
            // Top padding includes the status-bar height so text isn't
            // hidden behind the notch.
            Container(
              width: double.infinity,
              color: kNavy,
              padding: EdgeInsets.fromLTRB(
                24,
                MediaQuery.of(context).padding.top + 24,
                24,
                24,
              ),
              child: Center(
                // maxWidth keeps the layout tidy on tablets / web.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Welcome back,',
                        style: TextStyle(color: Colors.white70, fontSize: 15),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Log In',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ---- Form area ----
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Discover Events',
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: kNavy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Sign in to browse and join events',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 28),

                        // Email field. Locked while loading, and once
                        // the picker appears (credentials are already
                        // verified, so editing them would be misleading).
                        TextFormField(
                          controller: _emailCtrl,
                          enabled: !_loading && !showRolePicker,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _decoration(
                            'Email',
                            Icons.email_outlined,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Enter your email';
                            }
                            // Basic shape check: something@something.something
                            if (!RegExp(
                              r'^[^@]+@[^@]+\.[^@]+$',
                            ).hasMatch(v.trim())) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password field with show/hide eye button.
                        // Visibility state lives in obscureProvider.
                        TextFormField(
                          controller: _passCtrl,
                          enabled: !_loading && !showRolePicker,
                          obscureText: obscure,
                          decoration: _decoration(
                            'Password',
                            Icons.lock_outline,
                            suffix: IconButton(
                              icon: Icon(
                                obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.grey,
                              ),
                              onPressed: () =>
                                  ref.read(obscureProvider.notifier).toggle(),
                            ),
                          ),
                          validator: (v) => (v == null || v.length < 6)
                              ? 'At least 6 characters'
                              : null,
                        ),

                        // ----------------------------------------------
                        // Role picker — only appears AFTER a successful
                        // login reveals more than one real role on the
                        // account. Never shown up front, never a guess.
                        // ----------------------------------------------
                        if (showRolePicker) ...[
                          const SizedBox(height: 24),
                          const Text(
                            'Continue as',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: kNavy,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // One ChoiceChip per option; only one can be
                          // selected at a time (tracked by _selectedTarget).
                          Wrap(
                            spacing: 8,
                            children: _options.map((opt) {
                              final selected = _selectedTarget == opt.target;
                              return ChoiceChip(
                                label: Text(opt.label),
                                selected: selected,
                                onSelected: (_) => setState(
                                  () => _selectedTarget = opt.target,
                                ),
                                selectedColor: kAmber,
                                backgroundColor: Colors.white,
                                showCheckmark: false,
                                labelStyle: TextStyle(
                                  color: selected ? Colors.white : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                                side: BorderSide(
                                  color: selected
                                      ? kAmber
                                      : Colors.grey.shade300,
                                ),
                              );
                            }).toList(),
                          ),
                        ],

                        const SizedBox(height: 32),

                        // Main action button. Does double duty:
                        // - picker hidden -> "Log In"   -> _login
                        // - picker shown  -> "Continue" -> _continueWithSelectedRole
                        // null onPressed while loading disables it; the
                        // disabled colors are set equal to the normal ones
                        // so it doesn't turn grey during loading.
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _loading
                                ? null
                                : (showRolePicker
                                      ? _continueWithSelectedRole
                                      : _login),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kNavy,
                              disabledBackgroundColor: kNavy,
                              foregroundColor: Colors.white,
                              disabledForegroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    showRolePicker ? 'Continue' : 'Log In',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Link to the registration screen. `push` (not
                        // `go`) keeps Login in the stack so Back returns here.
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account?",
                              style: TextStyle(color: Colors.grey),
                            ),
                            TextButton(
                              onPressed: () => context.push('/register'),
                              child: const Text(
                                'Sign Up',
                                style: TextStyle(
                                  color: kAmber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One entry in the "Continue as" picker.
class _RoleOption {
  /// Text shown on the chip, e.g. 'Participant' or 'Organizer (Pending)'.
  final String label;

  /// Value passed to `goToRoleHome` when chosen.
  final String target; // 'participant' | 'organizer' | 'pending'
  const _RoleOption({required this.label, required this.target});
}
