import 'package:flutter/material.dart';
import '../../app/theme/design_tokens.dart';
import '../../services/auth_service.dart';

/// Minimalist, dark-themed Login and Sign-Up screen adhering strictly to FACEO design tokens.
class LoginScreen extends StatefulWidget {
  final AuthService? authService;

  const LoginScreen({
    super.key,
    this.authService,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final AuthService _authService;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();

  bool _isSignUpMode = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _showResendVerification = false;
  String? _lastUnverifiedEmail;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: DesignTokens.cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
        content: Text(
          message,
          style: DesignTokens.bodyMedium.copyWith(
            color: isError ? DesignTokens.accentNeonPink : DesignTokens.accentPeriwinkle,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Future<void> _submitEmailForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _showResendVerification = false;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final displayName = _displayNameController.text.trim();

    final AuthResult result = _isSignUpMode
        ? await _authService.signUpWithEmailAndPassword(
            email: email,
            password: password,
            displayName: displayName.isNotEmpty ? displayName : null,
          )
        : await _authService.signInWithEmailAndPassword(
            email: email,
            password: password,
          );

    setState(() {
      _isLoading = false;
    });

    if (result.isSuccess) {
      _showSnackBar('Welcome to FACEO!', isError: false);
    } else {
      if (result.errorCode == 'email-not-verified') {
        setState(() {
          _showResendVerification = true;
          _lastUnverifiedEmail = email;
        });
      }
      _showSnackBar(result.errorMessage, isError: true);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isGoogleLoading = true;
    });

    final AuthResult result = await _authService.signInWithGoogle();

    setState(() {
      _isGoogleLoading = false;
    });

    if (result.isSuccess) {
      _showSnackBar('Google Sign-In successful!', isError: false);
    } else {
      if (result.errorCode != 'google-sign-in-cancelled') {
        _showSnackBar(result.errorMessage, isError: true);
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_lastUnverifiedEmail == null) return;
    final AuthResult result = await _authService.sendEmailVerification();
    if (result.isSuccess) {
      _showSnackBar('Verification email re-sent to $_lastUnverifiedEmail', isError: false);
    } else {
      _showSnackBar(result.errorMessage, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.bgDeepBlack,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'FACEO',
                    textAlign: TextAlign.center,
                    style: DesignTokens.displayLarge.copyWith(
                      letterSpacing: 2.0,
                      fontSize: 36,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSignUpMode ? 'Create your FACEO account' : 'Sign in to continue',
                    textAlign: TextAlign.center,
                    style: DesignTokens.bodyMedium.copyWith(
                      color: DesignTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Mode Switcher (Pill-style Toggle)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: DesignTokens.cardSurface,
                      borderRadius: DesignTokens.radiusPill,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            label: 'Sign In Mode',
                            button: true,
                            selected: !_isSignUpMode,
                            child: InkWell(
                              onTap: () {
                                if (_isSignUpMode) {
                                  setState(() {
                                    _isSignUpMode = false;
                                    _showResendVerification = false;
                                  });
                                }
                              },
                              borderRadius: DesignTokens.radiusPill,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: !_isSignUpMode ? DesignTokens.accentPeriwinkle : Colors.transparent,
                                  borderRadius: DesignTokens.radiusPill,
                                ),
                                child: Text(
                                  'Sign In',
                                  textAlign: TextAlign.center,
                                  style: DesignTokens.buttonTextDark.copyWith(
                                    color: !_isSignUpMode ? DesignTokens.textDark : DesignTokens.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Semantics(
                            label: 'Sign Up Mode',
                            button: true,
                            selected: _isSignUpMode,
                            child: InkWell(
                              onTap: () {
                                if (!_isSignUpMode) {
                                  setState(() {
                                    _isSignUpMode = true;
                                    _showResendVerification = false;
                                  });
                                }
                              },
                              borderRadius: DesignTokens.radiusPill,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _isSignUpMode ? DesignTokens.accentPeriwinkle : Colors.transparent,
                                  borderRadius: DesignTokens.radiusPill,
                                ),
                                child: Text(
                                  'Sign Up',
                                  textAlign: TextAlign.center,
                                  style: DesignTokens.buttonTextDark.copyWith(
                                    color: _isSignUpMode ? DesignTokens.textDark : DesignTokens.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  if (_isSignUpMode) ...[
                    _buildTextField(
                      controller: _displayNameController,
                      hintText: 'Display Name',
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (_isSignUpMode && (value == null || value.trim().isEmpty)) {
                          return 'Please enter your display name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  _buildTextField(
                    controller: _emailController,
                    hintText: 'Email address',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _passwordController,
                    hintText: 'Password',
                    icon: Icons.lock_outline,
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (_isSignUpMode && value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  if (_showResendVerification) ...[
                    Semantics(
                      label: 'Resend Verification Email',
                      button: true,
                      child: InkWell(
                        onTap: _resendVerificationEmail,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Didn\'t receive verification email? Tap to resend.',
                            textAlign: TextAlign.center,
                            style: DesignTokens.caption.copyWith(
                              color: DesignTokens.accentPeriwinkle,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  Semantics(
                    label: _isSignUpMode ? 'Create Account' : 'Sign In',
                    button: true,
                    enabled: !_isLoading,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitEmailForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DesignTokens.accentPeriwinkle,
                        foregroundColor: DesignTokens.textDark,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const StadiumBorder(),
                        disabledBackgroundColor: DesignTokens.accentPeriwinkle.withValues(alpha: 0.5),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(DesignTokens.textDark),
                              ),
                            )
                          : Text(
                              _isSignUpMode ? 'Create Account' : 'Sign In',
                              style: DesignTokens.buttonTextDark,
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      const Expanded(child: Divider(color: DesignTokens.cardSurface, thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: DesignTokens.caption.copyWith(color: DesignTokens.textSecondary),
                        ),
                      ),
                      const Expanded(child: Divider(color: DesignTokens.cardSurface, thickness: 1)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Semantics(
                    label: 'Continue with Google Sign-In',
                    button: true,
                    enabled: !_isGoogleLoading,
                    child: OutlinedButton(
                      onPressed: _isGoogleLoading ? null : _handleGoogleSignIn,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: DesignTokens.cardSurface,
                        foregroundColor: DesignTokens.textLight,
                        side: BorderSide.none,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const StadiumBorder(),
                      ),
                      child: _isGoogleLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(DesignTokens.textLight),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.g_mobiledata,
                                  size: 24,
                                  color: DesignTokens.textLight,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Continue with Google',
                                  style: DesignTokens.buttonTextLight,
                                ),
                              ],
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Semantics(
      label: hintText,
      textField: true,
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: DesignTokens.bodyMedium,
        cursorColor: DesignTokens.accentPeriwinkle,
        validator: validator,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: DesignTokens.bodySecondary,
          prefixIcon: Icon(icon, color: DesignTokens.textSecondary, size: 20),
          filled: true,
          fillColor: DesignTokens.cardSurface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: DesignTokens.accentPeriwinkle, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: DesignTokens.accentNeonPink, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: DesignTokens.accentNeonPink, width: 1.5),
          ),
          errorStyle: DesignTokens.caption.copyWith(color: DesignTokens.accentNeonPink),
        ),
      ),
    );
  }
}
