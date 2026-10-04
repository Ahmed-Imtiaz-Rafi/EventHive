import 'package:event_hive/widgets/common/hoverable_text_widget.dart';
import 'package:event_hive/widgets/common/role_card_widget.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  UserRole _role = UserRole.participant;
  bool _hidePass = true;
  bool _hideConfirm = true;
  bool _agreed = false;
  bool _loading = false;

  bool get _canSubmit => _agreed && !_loading;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final desiredUsername = _nameCtrl.text.trim();

      final exists = await Supabase.instance.client.rpc(
        'username_exists',
        params: {'check_username': desiredUsername},
      );

      if (exists == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('That username is already taken.')),
          );
        }
        return;
      }

      final roleString = _role == UserRole.organizer
          ? 'organizer'
          : 'participant';

      final response = await Supabase.instance.client.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        data: {'username': _nameCtrl.text.trim(), 'role': roleString},
      );

      final identities = response.user?.identities;
      if (identities != null && identities.isEmpty) {
        // signUp "succeeded" but created nothing — email already registered
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This email is already registered. Try logging in instead.',
              ),
            ),
          );
        }
        return; // do NOT navigate to /login
      }

      if (mounted) {
        context.go('/login');
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      debugPrint('Unexpected error during signup: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'That username may already be taken, or something went wrong. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ── Navy header ────────────────────────────────────────────────
          _NavyHeader(),

          // ── Scrollable cream body ──────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeading(),
                    const SizedBox(height: 28),
                    _buildForm(),
                    const SizedBox(height: 24),
                    _buildRoleSection(),
                    const SizedBox(height: 28),
                    _buildTerms(),
                    const SizedBox(height: 28),
                    _buildSubmitButton(),
                    const SizedBox(height: 20),
                    _buildSignInLink(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeading() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create Account',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: kTextMain,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Join EventHive and start discovering\nand managing events.',
          style: TextStyle(fontSize: 14, color: kTextSub, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _field(
            ctrl: _nameCtrl,
            hint: 'Username',
            icon: Icons.person_outline_rounded,
            action: TextInputAction.next,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Username is required';
              if (v.trim().length < 2) return 'At least 2 characters';
              return null;
            },
          ),
          const SizedBox(height: 14),
          _field(
            ctrl: _emailCtrl,
            hint: 'Email',
            icon: Icons.mail_outline_rounded,
            keyboard: TextInputType.emailAddress,
            action: TextInputAction.next,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim())) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          _field(
            ctrl: _passCtrl,
            hint: 'Password',
            icon: Icons.lock_outline_rounded,
            obscure: _hidePass,
            action: TextInputAction.next,
            toggle: () => setState(() => _hidePass = !_hidePass),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 8) return 'At least 8 characters';
              if (!RegExp(r'(?=.*[A-Za-z])(?=.*\d)').hasMatch(v)) {
                return 'Include a letter and a number';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          _field(
            ctrl: _confirmCtrl,
            hint: 'Confirm Password',
            icon: Icons.lock_outline_rounded,
            obscure: _hideConfirm,
            action: TextInputAction.done,
            toggle: () => setState(() => _hideConfirm = !_hideConfirm),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please confirm your password';
              if (v != _passCtrl.text) return 'Passwords do not match';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboard,
    TextInputAction? action,
    VoidCallback? toggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboard,
      textInputAction: action,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: const TextStyle(fontSize: 15, color: kTextMain),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: kTextSub),
        suffixIcon: toggle != null
            ? IconButton(
                onPressed: toggle,
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: kTextSub,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildRoleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Register as',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: kTextMain,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: UserRole.values
              .map(
                (role) => Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: RoleChip(
                    role: role,
                    selected: _role == role,
                    onTap: () => setState(() => _role = role),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildTerms() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _agreed,
            onChanged: (v) => setState(() => _agreed = v ?? false),
            activeColor: kNavy,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            side: const BorderSide(color: kBorder, width: 1.5),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: const TextStyle(
                fontSize: 13,
                color: kTextSub,
                height: 1.5,
              ),
              children: [
                const TextSpan(text: 'I agree to the '),
                TextSpan(
                  text: 'Terms & Conditions',
                  style: const TextStyle(
                    color: kNavy,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: kNavy,
                  ),
                  recognizer: TapGestureRecognizer()..onTap = () {},
                ),
                const TextSpan(text: ' and '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: const TextStyle(
                    color: kNavy,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: kNavy,
                  ),
                  recognizer: TapGestureRecognizer()..onTap = () {},
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _canSubmit ? 1.0 : 0.5,
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _canSubmit ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: kNavy,
            disabledBackgroundColor: kNavy,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 0,
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
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
              : const Text('Create Account'),
        ),
      ),
    );
  }

  Widget _buildSignInLink() {
    return Center(
      child: Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 14, color: kTextSub),
          children: [
            const TextSpan(text: 'Already have an account? '),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: HoverableText(
                text: 'Sign in',
                style: const TextStyle(
                  fontSize: 14,
                  color: kNavy,
                  fontWeight: FontWeight.w700,
                ),
                onTap: () => context.go('/login'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Navy Header ──────────────────────────────────────────────────────────────

class _NavyHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      color: kNavy,
      padding: EdgeInsets.fromLTRB(24, top + 14, 24, 16),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Welcome to',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white60,
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'EventHive',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 3),
          Text(
            'Manage. Join. Experience.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white54,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
