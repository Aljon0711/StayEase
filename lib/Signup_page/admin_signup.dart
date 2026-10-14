import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/email_otp_service.dart';
import '../services/user_service.dart';
import 'otp.dart';

class AdminSignUp extends StatelessWidget {
  const AdminSignUp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // FORCE LIGHT THEME HERE
      themeMode: ThemeMode.light, 
      
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFAFAFA), // background-light
        primaryColor: const Color(0xFF24748F), // primary
        textTheme: GoogleFonts.manropeTextTheme(),
      ),
      
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF22262A), // background-dark
        textTheme: GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme),
      ),
      
      home: const AdminSignUpPage(),
    );
  }
}

class AdminSignUpPage extends StatefulWidget {
  const AdminSignUpPage({super.key});

  @override
  State<AdminSignUpPage> createState() => _AdminSignUpPageState();
}

class _AdminSignUpPageState extends State<AdminSignUpPage> {
  String? selectedDepartment;
  final Color primaryColor = const Color(0xFF24748F);

  final _fullNameCtrl = TextEditingController();
  final _employeeIdCtrl = TextEditingController();
  final _workEmailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _employeeIdCtrl.dispose();
    _workEmailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This will now default to light based on the MaterialApp setting
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        // Use color based on the actual theme state
        backgroundColor: isDark 
            ? const Color(0xFF22262A).withOpacity(0.8) 
            : const Color(0xFFFAFAFA).withOpacity(0.8),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: primaryColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Staff Registration',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF121617),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        // Adding the bottom border for the "ios-blur" nav effect
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: isDark ? Colors.grey[800] : Colors.grey[200],
            height: 1.0,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),
                      const Text(
                        'Join Admin Portal',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF121617),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please enter your professional details to request administrative credentials.',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF4A5559),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      _buildTextField('Full Name', 'Enter full name', Icons.person_outline, isDark, controller: _fullNameCtrl),
                      const SizedBox(height: 20),
                      _buildTextField('Employee ID', 'e.g., EMP-12345', Icons.badge_outlined, isDark, controller: _employeeIdCtrl),
                      const SizedBox(height: 20),
                      _buildTextField('Work Email', 'name@hotelbrand.com', Icons.mail_outline, isDark, controller: _workEmailCtrl),
                      const SizedBox(height: 20),
                      _buildTextField('Password', 'Create a secure password', Icons.lock_outline, isDark, controller: _passwordCtrl, isPassword: true),
                      const SizedBox(height: 20),
                      _buildDropdown(isDark),
                      
                      const SizedBox(height: 32),
                      
                      // Submit Button with Shadow
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () => _requestAccessAndSendOtp(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0, // Elevation handled by shadow container
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _isLoading ? 'Sending OTP...' : 'Request Admin Access',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.admin_panel_settings, size: 20),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Info Box
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: primaryColor.withOpacity(0.1)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, color: primaryColor, size: 20),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Your request will be reviewed by the system administrator. Access is granted only to verified hotel employees.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF4A5559), height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Branding Footer
          _buildAestheticFooter(isDark),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String hint,
    IconData icon,
    bool isDark, {
    TextEditingController? controller,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Color(0xFF121617))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF677C83)),
            suffixIcon: Icon(icon, color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDDE2E4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('DEPARTMENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Color(0xFF121617))),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDDE2E4)),
            ),
          ),
          hint: const Text('Select Department', style: TextStyle(color: Color(0xFF677C83))),
          items: ['Management', 'Front Desk', 'Housekeeping'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => selectedDepartment = v),
        ),
      ],
    );
  }

  Widget _buildAestheticFooter(bool isDark) {
    return Opacity(
      opacity: 0.5,
      child: Stack(
        children: [
          Container(
            height: 100,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage('https://images.unsplash.com/photo-1551882547-ff43c63efe81?q=80&w=2070'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [isDark ? const Color(0xFF22262A) : const Color(0xFFFAFAFA), Colors.transparent],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _requestAccessAndSendOtp(BuildContext context) async {
    final fullName = _fullNameCtrl.text.trim();
    final employeeId = _employeeIdCtrl.text.trim();
    final email = _workEmailCtrl.text.trim();
    final dept = selectedDepartment?.trim();
    final password = _passwordCtrl.text;

    if (fullName.isEmpty || employeeId.isEmpty || email.isEmpty || password.isEmpty || dept == null || dept.isEmpty) {
      _showSnack('Please complete all fields including password.');
      return;
    }

    if (password.length < 6) {
      _showSnack('Password must be at least 6 characters.');
      return;
    }

    final passwordHash = UserService.hashPassword(password);

    setState(() => _isLoading = true);
    try {
      // Create OTP record for email (sending email needs backend; OTP is stored in Firestore).
      await EmailOtpService().createOtpForEmail(email: email);

      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpPage(
            userEmail: email,
            role: 'employee',
            fullName: fullName,
            phone: null,
            employeeId: employeeId,
            department: dept,
            passwordHash: passwordHash,
          ),
        ),
      );
    } catch (e) {
      _showSnack('Request failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}