import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth

import 'home.dart';
import 'rooms.dart';
import 'calendar.dart';
import 'bookings.dart';
import 'settings.dart';
import 'edit_profile.dart'; // Import the new edit profile page
import 'package:provider/provider.dart';
import 'package:stay_ease_hotel_reservation_app/utils/theme_notifier.dart';

class ProfileSettingsPage extends StatefulWidget {
  final String userEmail;
  final String userRole;

  const ProfileSettingsPage({super.key, required this.userEmail, required this.userRole});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  int currentIndex = 4; // 4 for Profile tab
  final Color primaryColor = const Color(0xFF2A585A);
  final Color accentColor = const Color(0xFFCBA474);
  final Color bgLight = const Color(0xFFF6F2EF);

  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.userEmail).get();
      if (doc.exists) {
        setState(() {
          _userData = doc.data();
        });
      }
    } catch (e) {
      _showSnack('Failed to load profile data.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. Sticky Navigation Bar
              SliverAppBar(
                pinned: true,
                backgroundColor:
                    (theme.appBarTheme.backgroundColor ?? bgLight)
                        .withOpacity(0.8),
                elevation: 0,
                automaticallyImplyLeading: false,
                title: const Text('Settings', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                centerTitle: true,
              ),

              // 2. Profile Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      _buildAvatar(),
                      const SizedBox(height: 16),
                      _isLoading
                          ? const CircularProgressIndicator()
                          : Text(_userData?['fullName'] ?? 'N/A', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // 3. Navigation Groups
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildSectionHeader('Account Essentials'),
                    _buildGroupedCard([
                      _buildSettingsTile(
                        Icons.person_outline,
                        'Personal Details',
                        '${_userData?['fullName'] ?? 'N/A'}, ${_userData?['email'] ?? 'N/A'}${widget.userRole == 'employee'
                                ? ', Employee ID: ${_userData?['employeeId'] ?? 'N/A'}, Dept: ${_userData?['department'] ?? 'N/A'}'
                                : ', Phone: ${_userData?['phone'] ?? 'N/A'}'}',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CompanyEditProfilePage(
                                userEmail: widget.userEmail,
                                userRole: widget.userRole,
                              ),
                            ),
                          ).then((_) => _fetchUserData()); // Refresh data when returning
                        },
                      ),
                    ]),
                    
                    const SizedBox(height: 24),
                    _buildSectionHeader('Preferences'),
                    _buildGroupedCard([
                      Consumer<ThemeNotifier>(
                        builder: (context, themeNotifier, child) {
                          return _buildSettingsToggle(
                            Icons.dark_mode_outlined,
                            'Dark Mode',
                            themeNotifier.themeMode == ThemeMode.dark,
                            onChanged: (value) {
                              themeNotifier.toggleTheme(value);
                            },
                            isLast: true,
                          );
                        },
                      ),
                    ]),

                    const SizedBox(height: 24),

                    const SizedBox(height: 32),
                    _buildLogoutButton(),
                    
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('VERSION 2.4.1 (2024)', 
                          style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 100), // Spacing for Bottom Nav
                  ]),
                ),
              ),
            ],
          ),

        ],
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildAvatar() {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: accentColor, width: 2.5)),
          child: const CircleAvatar(
            radius: 52,
            backgroundImage: NetworkImage('https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcR2seVe2iItIpKYKuYr_q6lIZp7OpGjescb7zWrpvM6tw&s'),
          ),
        ),
        Positioned(
          bottom: 4,
          right: 4,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
            child: const Icon(Icons.edit, color: Colors.white, size: 14),
          ),
        )
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(title.toUpperCase(), 
        style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
    );
  }

  Widget _buildGroupedCard(List<Widget> children) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color cardColor =
        isDark ? const Color(0xFF1E2226) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String? subtitle, {bool isLast = false, String? trailingText, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap, // Use the onTap callback
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: isLast ? null : Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: primaryColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  if (subtitle != null) Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            ),
            if (trailingText != null) Text(trailingText, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsToggle(IconData icon, String title, bool value, {bool isLast = false, ValueChanged<bool>? onChanged}) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color textColor = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: primaryColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor))),
          Switch.adaptive(
            value: value,
            activeColor: primaryColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _showLogoutConfirmation(context), // Call confirmation modal
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isDark ? const Color(0xFF1E2226) : Colors.white,
          foregroundColor: Colors.red,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
      ),
    );
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button for close
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Confirm Logout', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Dismiss alert dialog
              },
            ),
            TextButton(
              child: Text('Logout', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
              onPressed: () async {
                Navigator.of(dialogContext).pop(); // Dismiss alert dialog
                await FirebaseAuth.instance.signOut(); // Sign out from Firebase
                if (mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false); // Navigate to login page
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color navBg = theme.bottomNavigationBarTheme.backgroundColor ??
        (isDark ? const Color(0xFF22262A) : Colors.white);
    final Color borderColor =
        isDark ? Colors.grey[800]! : const Color(0xFFDDE2E4);

    return Container(
      height: 90,
      padding: const EdgeInsets.only(bottom: 24, left: 32, right: 32),
      decoration: BoxDecoration(
        color: navBg,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AdminDashboardPage(userEmail: widget.userEmail, userRole: widget.userRole)),
              );
            },
            child: _navItem(Icons.dashboard, 'Home', false),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => InventoryPage(userEmail: widget.userEmail, userRole: widget.userRole)),
              );
            },
            child: _navItem(Icons.bed_outlined, 'Rooms', false),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CalendarPage(userEmail: widget.userEmail, userRole: widget.userRole)),
              );
            },
            child: _navItem(Icons.calendar_today, 'Calendar', false),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PendingRequestsPage(userEmail: widget.userEmail, userRole: widget.userRole)),
              );
            },
            child: _navItem(Icons.confirmation_number, 'Booking', false),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PropertyDetailsPage(userEmail: widget.userEmail, userRole: widget.userRole)),
              );
            },
            child: _navItem(Icons.settings, 'Settings', false),
          ),
          _navItem(Icons.person, 'Profile', true),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color inactiveColor = isDark ? Colors.grey[400]! : const Color(0xFF687C82);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: active ? primaryColor : inactiveColor, size: 26),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: active ? primaryColor : inactiveColor, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}