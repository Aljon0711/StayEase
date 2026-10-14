import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import for FirebaseAuth
import 'package:provider/provider.dart'; // New import
import 'package:stay_ease_hotel_reservation_app/utils/theme_notifier.dart'; // New import

import 'Guest_screen/home.dart';
import 'Company_screen/home.dart';
import 'Signup_page/guest_signup.dart';
import 'Signup_page/admin_signup.dart';
import 'Signup_page/otp.dart'; // Import otp.dart
import 'firebase_options.dart';
import 'services/user_service.dart';
import 'services/email_otp_service.dart'; // Import EmailOtpService


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    ChangeNotifierProvider<ThemeNotifier>(
      create: (_) => ThemeNotifier(ThemeMode.light), // Default to light theme
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: themeNotifier.themeMode, // Use theme from ThemeNotifier
      theme: ThemeData(
        brightness: Brightness.light,
        textTheme: GoogleFonts.manropeTextTheme(),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF395660),
          surface: Color(0xFFF8F7F7),
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F2EF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF6F2EF),
          iconTheme: IconThemeData(color: Color(0xFF131515)),
          titleTextStyle: TextStyle(color: Color(0xFF131515), fontSize: 20, fontWeight: FontWeight.bold),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF395660),
          unselectedItemColor: Colors.grey,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        textTheme: GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF395660),
          surface: Color(0xFF22262A),
        ),
        scaffoldBackgroundColor: const Color(0xFF131515),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF131515),
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF22262A),
          selectedItemColor: Color(0xFFCBA474),
          unselectedItemColor: Colors.grey,
        ),
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    const Color primaryColor = Color(0xFF395660);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Background Image with Overlay
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage('https://images.unsplash.com/photo-1566073771259-6a8506099945?q=80&w=2070'), // Placeholder for lobby
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(
            color: isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.2),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(color: Colors.transparent),
          ),

          // 2. Main Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: primaryColor.withOpacity(isDark ? 0.2 : 0.1),
                      child: const Icon(Icons.apartment, color: primaryColor, size: 36),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Welcome Back',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF131515),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Unified Reservation Portal',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : const Color.fromARGB(255, 255, 255, 255),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Glass Card
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: isDark 
                                ? const Color(0xFF22262A).withOpacity(0.92) 
                                : Colors.white.withOpacity(0.92),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInputField(context, "Email Address", "your@email.com", isDark, controller: _emailCtrl),
                              const SizedBox(height: 20),
                              _buildInputField(context, "Password", "Enter your password", isDark, isPassword: true, controller: _passwordCtrl),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => _showForgotPasswordDialog(context, isDark, primaryColor),
                                  child: const Text(
                                    'Forgot password?',
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _signIn,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 4,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _isLoading ? 'Signing In...' : 'Sign In',
                                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward, color: Colors.white),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Navigation Footer
                    Row(
                      children: [
                        Expanded(child: Divider(color: primaryColor.withOpacity(0.2))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text("REGISTER", style: TextStyle(color: isDark ? Colors.grey[400] : const Color.fromARGB(255, 255, 255, 255), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ),
                        Expanded(child: Divider(color: primaryColor.withOpacity(0.2))),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const SignUpPage()),
                              );
                            },
                            child: _buildFooterButton(Icons.person_add, "New Guest", isDark, primaryColor),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const AdminSignUpPage()),
                              );
                            },
                            child: _buildFooterButton(Icons.admin_panel_settings, "Admin Portal", isDark, primaryColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'STAYEASE  © 2024',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 2,
                        color: isDark ? Colors.grey[500] : const Color.fromARGB(255, 255, 255, 255),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(BuildContext context, String label, String hint, bool isDark, {bool isPassword = false, TextEditingController? controller}) {
    const Color primaryColor = Color(0xFF395660);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: isDark ? Colors.grey[300] : const Color(0xFF131515))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF6F787B)),
            filled: true,
            fillColor: isDark ? Colors.grey[800]!.withOpacity(0.5) : Colors.white.withOpacity(0.5),
            contentPadding: const EdgeInsets.all(16),
            suffixIcon: isPassword ? const Icon(Icons.visibility, color: Color(0xFF6F787B)) : null,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? Colors.grey[700]! : const Color(0xFFDFE1E2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: primaryColor.withOpacity(0.5), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterButton(IconData icon, String label, bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: primaryColor),
          const SizedBox(height: 8),
          Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF131515))),
        ],
      ),
    );
  }

  Future<void> _signIn() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnack('Please enter email and password.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(email).get();
      if (!doc.exists) {
        _showSnack('Account not found.');
        return;
      }

      final data = doc.data();
      final storedHash = data?['passwordHash'] as String?;
      final inputHash = UserService.hashPassword(password);

      if (storedHash == null || storedHash != inputHash) {
        _showSnack('Invalid email or password.');
        return;
      }

      if (!mounted) return;

      // Derive role, with safety fix: if record looks like an employee (has employeeId/department)
      // but role is still 'guest', automatically correct it to 'employee'.
      String? userRole = data?['role'] as String?;
      final hasEmployeeFields =
          (data?['employeeId'] != null && (data?['employeeId'] as String).trim().isNotEmpty) ||
          (data?['department'] != null && (data?['department'] as String).trim().isNotEmpty);
      if (userRole == 'guest' && hasEmployeeFields) {
        userRole = 'employee';
        // Best-effort fix in Firestore; ignore errors here.
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(email)
              .set({'role': 'employee'}, SetOptions(merge: true));
        } catch (_) {}
      }

      final userEmail = email; // email is already lowercased and trimmed

      // Set user email in ThemeNotifier after successful login
      Provider.of<ThemeNotifier>(context, listen: false).setUserEmail(userEmail);

      if (userRole == 'employee') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdminDashboardPage(
              userEmail: userEmail,
              userRole: userRole!,
            ),
          ),
        );
      } else if (userRole == 'guest') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HomeExploreScreen(
              userEmail: userEmail,
              userRole: userRole!,
            ),
          ),
        );
      } else {
        // Default navigation or error if role is not defined
        _showSnack('User role not recognized.');
      }
    } catch (e) {
      _showSnack('Sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _showForgotPasswordDialog(BuildContext context, bool isDark, Color primaryColor) async {
    final TextEditingController emailController = TextEditingController();
    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF22262A) : Colors.white,
          title: Text(
            'Forgot Password',
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF131515)),
          ),
          content: TextField(
            controller: emailController,
            decoration: InputDecoration(
              hintText: 'Enter your email',
              hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: isDark ? Colors.grey[700]! : const Color(0xFFDFE1E2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: primaryColor.withOpacity(0.5), width: 2),
              ),
            ),
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF131515)),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.red)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reset Password'),
              onPressed: () async {
                final email = emailController.text.trim().toLowerCase();
                if (email.isEmpty) {
                  _showSnack('Please enter your email.');
                  return;
                }
                try {
                  await EmailOtpService().createOtpForEmail(email: email);
                  Navigator.of(dialogContext).pop();
                  _showSnack('OTP sent to your email. Check your inbox.');
                  // Navigate to OTP page for verification.
                   Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => OtpPage(userEmail: email, isForgotPassword: true)),
                  );
                } on FirebaseAuthException catch (e) {
                  // This is not for FirebaseAuth, so this catch block is not directly relevant for OTP sending.
                  _showSnack('Error sending OTP: ${e.message}');
                } catch (e) {
                  _showSnack('An unexpected error occurred.');
                }
              },
            ),
          ],
        );
      },
    );
  }
}
