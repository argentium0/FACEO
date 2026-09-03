import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';

/// Minimalist, dark-themed Login and Sign-Up screen adhering to FACEO design tokens.
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

  // FACEO Design Tokens (Strict Compliance)
  static const Color _bgPrimary = Color(0xFF1F1F1F);
  static const Color _surfaceCard = Color(0xFF313131);
  static const Color _accentLavender = Color(0xFFB7BEFE);
  static const Color _textPrimary = Color(0xFFFFFFFF);
  static const Color _textSecondary = Color(0x99FFFFFF);
  static const Color _textOnAccent = Color(0xFF1F1F1F);

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
        backgroundColor: _surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
        content: Text(
          message,
          style: GoogleFonts.poppins(
            color: isError ? const Color(0xFFFF95DD) : _accentLavender,
            fontSize: 14,
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
      // Navigation to Home screen will be triggered via auth state listener
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
      backgroundColor: _bgPrimary,
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
                  // App Branding Header
                  Text(
                    'FACEO',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSignUpMode ? 'Create your FACEO account' : 'Sign in to continue',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: _textSecondary,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Mode Switcher (Pill-style Toggle)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _surfaceCard,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (_isSignUpMode) {
                                setState(() {
                                  _isSignUpMode = false;
                                  _showResendVerification = false;
                                });
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !_isSignUpMode ? _accentLavender : Colors.transparent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Sign In',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: !_isSignUpMode ? _textOnAccent : _textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (!_isSignUpMode) {
                                setState(() {
                                  _isSignUpMode = true;
                                  _showResendVerification = false;
                                });
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _isSignUpMode ? _accentLavender : Colors.transparent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Sign Up',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _isSignUpMode ? _textOnAccent : _textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Display Name Field (Sign Up Mode Only)
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

                  // Email Field
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

                  // Password Field
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

                  // Resend Verification Affordance
                  if (_showResendVerification) ...[
                    GestureDetector(
                      onTap: _resendVerificationEmail,
                      child: Text(
                        'Didn\'t receive verification email? Tap to resend.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _accentLavender,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Primary Action Button (Periwinkle Pill)
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitEmailForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentLavender,
                      foregroundColor: _textOnAccent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      disabledBackgroundColor: _accentLavender.withValues(alpha: 0.5),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(_textOnAccent),
                            ),
                          )
                        : Text(
                            _isSignUpMode ? 'Create Account' : 'Sign In',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),

                  // Divider
                  Row(
                    children: [
                      const Expanded(child: Divider(color: _surfaceCard, thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _textSecondary,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(color: _surfaceCard, thickness: 1)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Google Sign-In Action Button (Flat Surface Pill)
                  OutlinedButton(
                    onPressed: _isGoogleLoading ? null : _handleGoogleSignIn,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _surfaceCard,
                      foregroundColor: _textPrimary,
                      side: BorderSide.none,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: _isGoogleLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(_textPrimary),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.g_mobiledata,
                                size: 24,
                                color: _textPrimary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Continue with Google',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: _textPrimary,
                                ),
                              ),
                            ],
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
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(
        color: _textPrimary,
        fontSize: 14,
      ),
      cursorColor: _accentLavender,
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.poppins(
          color: _textSecondary,
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, color: _textSecondary, size: 20),
        filled: true,
        fillColor: _surfaceCard,
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
          borderSide: const BorderSide(color: _accentLavender, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFFF95DD), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFFF95DD), width: 1.5),
        ),
        errorStyle: GoogleFonts.poppins(
          color: const Color(0xFFFF95DD),
          fontSize: 12,
        ),
      ),
    );
  }
}
