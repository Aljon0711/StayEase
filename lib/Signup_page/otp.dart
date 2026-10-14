import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/email_otp_service.dart';
import '../services/user_service.dart';

class OtpPage extends StatefulWidget { // Renamed from HotelOTPApp to OtpPage for consistency
  final String userEmail; // Renamed from email to userEmail
  final bool isForgotPassword; // New parameter
  final String? role; // "guest" | "employee"
  final String? fullName;
  final String? phone;
  final String? employeeId;
  final String? department;
  final String? passwordHash;

  const OtpPage({
    super.key,
    required this.userEmail, // Required now
    this.isForgotPassword = false, // Default to false
    this.role,
    this.fullName,
    this.phone,
    this.employeeId,
    this.department,
    this.passwordHash,
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final Color primaryColor = const Color(0xFF243D42);
  final Color accentGold = const Color(0xFFEBB04D);
  
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();
  List<String> otpValues = ["", "", "", "", "", ""];
  bool _isVerifying = false;
  static const int _otpTtlSeconds = 10 * 60;
  int _secondsRemaining = _otpTtlSeconds;
  Timer? _timer;

  String get _otp => _codeController.text;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_syncOtpValuesFromController);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.isForgotPassword
        ? 'We\'ve sent a 6-digit verification code to your email address to reset your password.'
        : 'We\'ve sent a 6-digit verification code to your registered email address for sign up.';

    final minutes = _secondsRemaining ~/ 60;
    final seconds = _secondsRemaining % 60;
    final timerText = _secondsRemaining > 0
        ? 'RESEND CODE IN ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
        : 'CODE EXPIRED';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new, color: primaryColor, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verify Your\nIdentity',
                    style: GoogleFonts.notoSerif(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 16,
                      color: primaryColor.withOpacity(0.7),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 30,
                    offset: const Offset(0, 8),
                  )
                ],
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (index) => _buildOtpDigit(index)),
                  ),
                  const SizedBox(height: 16),
                  Offstage(
                    offstage: true,
                    child: TextField(
                      controller: _codeController,
                      focusNode: _codeFocusNode,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.schedule, color: accentGold, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        timerText,
                        style: TextStyle(
                          color: accentGold,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: _isVerifying ? null : _verifyAndContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      minimumSize: const Size(double.infinity, 64),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 8,
                      shadowColor: primaryColor.withOpacity(0.2),
                    ),
                    child: const Text(
                      'Verify & Continue',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Container(
              height: 5,
              width: 120,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpDigit(int index) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).requestFocus(_codeFocusNode);
      },
      child: Container(
        width: 40,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: otpValues[index].isNotEmpty ? primaryColor : Colors.grey.shade200,
              width: 2,
            ),
          ),
        ),
        child: Text(
          otpValues[index],
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  void _syncOtpValuesFromController() {
    final text = _codeController.text;
    setState(() {
      for (var i = 0; i < 6; i++) {
        otpValues[i] = i < text.length ? text[i] : "";
      }
    });
  }

  void _startTimer() {
    _secondsRemaining = _otpTtlSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _verifyAndContinue() async {
    final code = _otp.trim();
    if (code.length != 6) {
      _showSnack('Please enter the 6-digit code.');
      return;
    }

    if (_secondsRemaining <= 0) {
      _showSnack('Code has expired. Please request a new OTP.');
      return;
    }

    setState(() => _isVerifying = true);
    try {
      if (widget.isForgotPassword) {
        // For Forgot Password flow, we don't create a new user or sign in with credential.
        // We just verify the OTP, and if successful, allow the user to set a new password.
        final ok = await EmailOtpService().verifyEmailOtp(email: widget.userEmail, code: code);
        if (!ok) {
          _showSnack('Invalid or expired code.');
          return;
        }
        if (!mounted) return;
        _showSnack('OTP Verified. You can now reset your password.');
        await _showNewPasswordDialog(); // Show dialog to set new password
      } else {
        // Original Sign Up flow logic
        final email = widget.userEmail;
        if (email.isEmpty) {
          throw Exception('Missing email.');
        }
        final ok = await EmailOtpService().verifyEmailOtp(email: email, code: code);
        if (!ok) {
          _showSnack('Invalid or expired code.');
          return;
        }

        if (!mounted) return;

        if (widget.role != null &&
            widget.fullName != null &&
            widget.passwordHash != null) {
          await UserService().upsertUser(
            role: widget.role!,
            fullName: widget.fullName!,
            passwordHash: widget.passwordHash!,
            email: email,
            phone: widget.phone,
            employeeId: widget.employeeId,
            department: widget.department,
          );
        }
      }

      if (!mounted) return;
      // For sign-up, pop to first. For forgot password, only pop after password update.
      if (!widget.isForgotPassword) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      }
     
    } catch (e) {
      if (!mounted) return;
      _showSnack('Verification failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _showNewPasswordDialog() async {
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();
    final _formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Set New Password'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New Password'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a new password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters long';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm New Password'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your new password';
                    }
                    if (value != newPasswordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Set Password'),
              onPressed: () async {
                if (_formKey.currentState?.validate() ?? false) {
                  final newPassword = newPasswordController.text;
                  try {
                    // Re-authenticate user if needed, or rely on the password reset token from Firebase
                    // For now, let's assume the user is authenticated via the password reset link already.
                    // This part might need further refinement based on Firebase setup (e.g., oobCode validation)
                    // If the user came from a password reset email link, they are already "signed in" with that intent.
                    // We can directly update the password here.
                    await UserService().upsertUser(
                      email: widget.userEmail,
                      passwordHash: UserService.hashPassword(newPassword),
                    );
                    Navigator.of(dialogContext).pop();
                    _showSnack('Password updated successfully!');
                     Navigator.of(context).popUntil((route) => route.isFirst); // Pop to login
                  } catch (e) {
                    _showSnack('Error updating password: ${e.toString()}');
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }


  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}
