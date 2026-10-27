import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth.dart';
import '../theme/gratideo_theme.dart';

enum _AuthMode { signIn, register, reset }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.auth});
  final AuthService auth;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  _AuthMode _mode = _AuthMode.signIn;
  bool _showPassword = false;
  bool _showConfirm = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _email.text = widget.auth.email;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _changeMode(_AuthMode mode) {
    if (_busy) return;
    setState(() {
      _mode = mode;
      _formKey = GlobalKey<FormState>();
      _password.clear();
      _confirmPassword.clear();
      _showPassword = false;
      _showConfirm = false;
    });
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Enter your email address.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').isEmpty) return 'Enter your password.';
    if (_mode == _AuthMode.register && value!.length < 8) {
      return 'Use at least 8 characters.';
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false) || _busy) return;
    setState(() => _busy = true);
    try {
      if (_mode == _AuthMode.reset) {
        await widget.auth.requestPasswordReset(_email.text.trim());
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Check your inbox'),
              content: const Text(
                'If this email has an account, password reset instructions are on their way.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else if (_mode == _AuthMode.register) {
        await widget.auth.register(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
        );
      } else {
        await widget.auth.signIn(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Something went wrong. Please try again.'),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.g;
    return Scaffold(
      backgroundColor: g.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            if (wide) {
              return Row(
                children: [
                  Expanded(
                    flex: 11,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: _HeroPanel(colors: g, wide: true),
                    ),
                  ),
                  Expanded(
                    flex: 9,
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 510),
                          child: _formPanel(g, wide: true),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                children: [
                  _HeroPanel(colors: g, wide: false),
                  _formPanel(g, wide: false),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _formPanel(GColors g, {required bool wide}) {
    final isRegister = _mode == _AuthMode.register;
    final isReset = _mode == _AuthMode.reset;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        wide ? 42 : 24,
        wide ? 54 : 30,
        wide ? 42 : 24,
        40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 20, height: 2, color: g.gold),
              const SizedBox(width: 9),
              Text(
                'A QUIETER WAY TO BEGIN',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                  color: g.goldText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            isReset
                ? 'Find your way back.'
                : isRegister
                ? 'Make space for grace.'
                : 'Welcome back.',
            style: context.display.copyWith(
              fontSize: wide ? 35 : 32,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            isReset
                ? 'Enter the email address you used to create your account.'
                : isRegister
                ? 'A simple place for prayer, gratitude, and the moments in between.'
                : 'Your daily rhythm is right where you left it.',
            style: context.body.copyWith(color: g.muted),
          ),
          const SizedBox(height: 26),
          if (isReset)
            TextButton.icon(
              onPressed: () => _changeMode(_AuthMode.signIn),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back to sign in'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
            )
          else
            _ModeSwitch(mode: _mode, onChanged: _changeMode, colors: g),
          const SizedBox(height: 25),
          Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isRegister) ...[
                  _fieldLabel('YOUR NAME'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(
                      hintText: 'How should we address you?',
                      prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                    ),
                    validator: (value) => (value ?? '').trim().length < 2
                        ? 'Enter your name.'
                        : null,
                  ),
                  const SizedBox(height: 17),
                ],
                _fieldLabel('EMAIL ADDRESS'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: isReset
                      ? TextInputAction.done
                      : TextInputAction.next,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    hintText: 'you@example.com',
                    prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                  ),
                  validator: _validateEmail,
                  onFieldSubmitted: isReset ? (_) => _submit() : null,
                ),
                if (!isReset) ...[
                  const SizedBox(height: 17),
                  _fieldLabel('PASSWORD'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _password,
                    obscureText: !_showPassword,
                    textInputAction: isRegister
                        ? TextInputAction.next
                        : TextInputAction.done,
                    autofillHints: [
                      isRegister
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    decoration: InputDecoration(
                      hintText: isRegister
                          ? 'At least 8 characters'
                          : 'Enter your password',
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        size: 20,
                      ),
                      suffixIcon: IconButton(
                        tooltip: _showPassword
                            ? 'Hide password'
                            : 'Show password',
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                        ),
                      ),
                    ),
                    validator: _validatePassword,
                    onFieldSubmitted: isRegister ? null : (_) => _submit(),
                  ),
                  if (isRegister) ...[
                    const SizedBox(height: 17),
                    _fieldLabel('CONFIRM PASSWORD'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _confirmPassword,
                      obscureText: !_showConfirm,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        hintText: 'Enter your password again',
                        prefixIcon: const Icon(
                          Icons.verified_user_outlined,
                          size: 20,
                        ),
                        suffixIcon: IconButton(
                          tooltip: _showConfirm
                              ? 'Hide password'
                              : 'Show password',
                          onPressed: () =>
                              setState(() => _showConfirm = !_showConfirm),
                          icon: Icon(
                            _showConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if ((value ?? '').isEmpty) {
                          return 'Confirm your password.';
                        }
                        if (value != _password.text) {
                          return 'Passwords do not match.';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ] else ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _changeMode(_AuthMode.reset),
                        child: const Text('Forgot password?'),
                      ),
                    ),
                  ],
                ],
                SizedBox(height: isRegister || isReset ? 26 : 12),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                g.onPrimary,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isReset
                                    ? 'Reset password'
                                    : isRegister
                                    ? 'Create account'
                                    : 'Sign in',
                              ),
                              const SizedBox(width: 10),
                              const Icon(Icons.arrow_forward_rounded, size: 19),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          if (!isReset) ...[
            const SizedBox(height: 22),
            Center(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.center,
                children: [
                  Text(
                    isRegister
                        ? 'Already have an account?'
                        : 'New to Gratideo?',
                    style: context.small.copyWith(fontSize: 13),
                  ),
                  TextButton(
                    onPressed: () => _changeMode(
                      isRegister ? _AuthMode.signIn : _AuthMode.register,
                    ),
                    child: Text(isRegister ? 'Sign in' : 'Create an account'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, color: g.goldText, size: 17),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Your prayers, gratitude, and journal stay on this device.',
                  style: context.small.copyWith(height: 1.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) =>
      Text(text, style: context.label.copyWith(fontSize: 10));
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({
    required this.mode,
    required this.onChanged,
    required this.colors,
  });
  final _AuthMode mode;
  final ValueChanged<_AuthMode> onChanged;
  final GColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.isNight ? colors.surface : const Color(0xFFF0E9DA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _item(context, _AuthMode.signIn, 'Sign in'),
          _item(context, _AuthMode.register, 'Create account'),
        ],
      ),
    );
  }

  Widget _item(BuildContext context, _AuthMode value, String label) {
    final selected = mode == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? colors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected && !colors.isNight
                ? [
                    BoxShadow(
                      color: colors.ink.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? colors.ink : colors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.colors, required this.wide});
  final GColors colors;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final background = colors.isNight
        ? const Color(0xFF1A2030)
        : const Color(0xFF1B2640);
    return Container(
      height: wide ? double.infinity : 270,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: wide
            ? BorderRadius.circular(24)
            : const BorderRadius.vertical(bottom: Radius.circular(28)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [background, const Color(0xFF31415A)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _HaloPainter(colors.gold)),
          ),
          Positioned(
            top: wide ? 34 : 24,
            left: wide ? 36 : 24,
            child: Row(
              children: [
                Container(
                  width: 35,
                  height: 35,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: colors.gold.withValues(alpha: 0.75),
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    Icons.wb_sunny_outlined,
                    size: 20,
                    color: colors.gold,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'gratideo',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                    color: const Color(0xFFF9F4E9),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: wide ? 38 : 26,
            right: wide ? 60 : 54,
            bottom: wide ? 60 : 31,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A DAILY RHYTHM WITH GOD',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: colors.gold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Begin with what\nmatters most.',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: wide ? 46 : 30,
                    height: 1.1,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.7,
                    color: const Color(0xFFF9F4E9),
                  ),
                ),
                if (wide) ...[
                  const SizedBox(height: 16),
                  Text(
                    'A little space to pray, give thanks, and hear the Word every day.',
                    style: GoogleFonts.dmSans(
                      color: const Color(0xFFD4D7DD),
                      fontSize: 15,
                      height: 1.55,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HaloPainter extends CustomPainter {
  const _HaloPainter(this.gold);
  final Color gold;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width * (size.width > 600 ? 0.80 : 0.86),
      size.height * 0.36,
    );
    for (var i = 0; i < 5; i++) {
      final radius =
          (size.width > 600 ? 74.0 : 45.0) +
          i * (size.width > 600 ? 43.0 : 31.0);
      final paint = Paint()
        ..color = gold.withValues(alpha: i == 0 ? 0.42 : 0.24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = i == 0 ? 1.5 : 1;
      canvas.drawCircle(center, radius, paint);
    }
    final dot = Paint()..color = gold.withValues(alpha: 0.9);
    canvas.drawCircle(center, 4, dot);
  }

  @override
  bool shouldRepaint(covariant _HaloPainter oldDelegate) =>
      oldDelegate.gold != gold;
}
