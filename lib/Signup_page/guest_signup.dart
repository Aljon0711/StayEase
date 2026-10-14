import 'dart:ui'; // Add this at the top
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/user_service.dart';
import '../services/email_otp_service.dart';
import 'otp.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GuestSignUpApp extends StatelessWidget {
  const GuestSignUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // You can toggle brightness here to see Dark Mode
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8F8F7),
        textTheme: GoogleFonts.epilogueTextTheme(),
      ),
      home: const SignUpPage(),
    );
  }
}

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    const Color primaryColor = Color(0xFF2D5349);
    const Color accentBronze = Color(0xFFB48C5B);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF22252A) : const Color(0xFFF8F8F7),
      body: Stack(
        children: [
          // Decorative Background Blurs
          Positioned(
            top: 100,
            left: -50,
            child: _buildBlurCircle(accentBronze.withOpacity(0.1), 150),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: _buildBlurCircle(primaryColor.withOpacity(0.1), 200),
          ),

          SafeArea(
            child: Column(
              children: [
                // 1. Top Navigation
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'Sign Up',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 48), // Spacer to balance the back button
                    ],
                  ),
                ),

                // 2. Progress Indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 8.0),
                  child: Container(
                    height: 4,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 0.33,
                      child: Container(
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        const Text(
                          'Welcome to Your Stay',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Enter your details to begin your personalized experience.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Form Container
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF2EFED),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                          ),
                          child: Column(
                            children: [
                              _buildInputField("Full Name", "e.g., Julianne Moore", Icons.person, isDark, controller: _fullNameCtrl),
                              const SizedBox(height: 20),
                              _buildInputField("Email Address", "name@example.com", Icons.mail_outline, isDark, controller: _emailCtrl),
                              const SizedBox(height: 20),
                              _buildInputField("Phone Number (Optional)", "+639123456789", Icons.call_outlined, isDark, controller: _phoneCtrl),
                              const SizedBox(height: 20),
                              _buildInputField("Password", "••••••••", Icons.lock_outline, isDark, isPassword: true, controller: _passwordCtrl),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Create Account Button
                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : () => _createAccountAndSendOtp(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 4,
                            ),
                            child: Text(
                              _isLoading ? 'Sending OTP...' : 'Create Account',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurCircle(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle, // Corrected: use the enum constant
      ),
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40), // Added actual blur effect
        child: Container(color: color),
      ),
    );
  }

  Widget _buildInputField(
    String label,
    String hint,
    IconData icon,
    bool isDark, {
    bool isPassword = false,
    TextEditingController? controller,
  }) {
    const Color primaryColor = Color(0xFF2D5349);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: isPassword,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF6E7C79), fontWeight: FontWeight.normal),
            prefixIcon: Icon(icon, color: const Color(0xFF6E7C79), size: 22),
            suffixIcon: isPassword ? const Icon(Icons.visibility_outlined, color: Color(0xFF6E7C79)) : null,
            filled: true,
            fillColor: isDark ? const Color(0xFF22252A) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFDFE2E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor.withOpacity(0.2), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _createAccountAndSendOtp(BuildContext context) async {
    final fullName = _fullNameCtrl.text.trim();
    final email = _emailCtrl.text.trim().toLowerCase();
    final phone = _phoneCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnack('Please enter your full name, email address, and password.');
      return;
    }

    // Prevent downgrading an existing employee/admin account to guest
    try {
      final existing =
          await FirebaseFirestore.instance.collection('users').doc(email).get();
      if (existing.exists) {
        final data = existing.data();
        final existingRole = data?['role'] as String?;
        if (existingRole == 'employee') {
          _showSnack(
              'This email is already registered as a staff/admin account. Please log in as admin or use a different email.');
          return;
        }
      }
    } catch (_) {
      // If check fails, we still continue; this is only a safety check.
    }

    // Basic email validation
    if (!email.contains('@') || !email.contains('.')) {
      _showSnack('Please enter a valid email address.');
      return;
    }

    if (password.length < 6) {
      _showSnack('Password must be at least 6 characters.');
      return;
    }

    final passwordHash = UserService.hashPassword(password);

    setState(() => _isLoading = true);
    try {
      // Create Email OTP record in Firestore
      await EmailOtpService().createOtpForEmail(email: email);

      // Navigate to OTP screen for email verification
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpPage(
              userEmail: email,
              role: 'guest',
              fullName: fullName,
              phone: phone.isEmpty ? null : phone,
              passwordHash: passwordHash,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Create account failed: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}