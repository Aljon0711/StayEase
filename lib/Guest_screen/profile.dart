import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth

import 'home.dart';
import 'search.dart';
import 'bookings.dart';
import 'edit_profile.dart'; // Import the new edit profile page
import 'favorites.dart';
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
      // Handle error fetching user data
      _showSnack('Failed to load profile data.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.themeMode == ThemeMode.dark;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    final Color iconColor = isDarkMode ? Colors.white : primaryColor;
    final Color cardColor = isDarkMode ? const Color(0xFF22262A) : Colors.white;
    final Color borderColor = isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. Sticky Navigation Bar
              SliverAppBar(
                pinned: true,
                backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
                elevation: 0,
                automaticallyImplyLeading: false,
                title: Text('Settings', style: TextStyle(color: Theme.of(context).appBarTheme.titleTextStyle?.color, fontSize: 18, fontWeight: FontWeight.bold)),
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
                      Text(_userData?['fullName'] ?? 'User', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: textColor)),
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
                      '${_userData?['fullName'] ?? 'N/A'}, ${_userData?['email'] ?? 'N/A'}, ${_userData?['phone'] ?? 'N/A'}',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GuestEditProfilePage(
                              userEmail: widget.userEmail,
                              userRole: widget.userRole,
                            ),
                          ),
                        ).then((_) => _fetchUserData()); // Refresh data when returning
                      },
                        isDarkMode: isDarkMode, textColor: textColor, iconColor: iconColor, borderColor: borderColor, cardColor: cardColor
                    ),
                    ], cardColor: cardColor, borderColor: borderColor),
                    
                    const SizedBox(height: 24),
                    _buildSectionHeader('Preferences'),
                    _buildGroupedCard([
                      _buildSettingsToggle(
                        Icons.dark_mode_outlined,
                        'Dark Mode',
                        isDarkMode,
                        isLast: true,
                        onChanged: (newValue) {
                          themeNotifier.toggleTheme(newValue);
                        },
                        isDarkMode: isDarkMode, textColor: textColor, iconColor: iconColor, borderColor: borderColor, cardColor: cardColor
                      ),
                    ], cardColor: cardColor, borderColor: borderColor),

                    const SizedBox(height: 24),

                    const SizedBox(height: 32),
                    _buildLogoutButton(isDarkMode: isDarkMode, textColor: textColor, primaryColor: primaryColor),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('VERSION 2.4.1 (2024)', 
                          style: TextStyle(color: isDarkMode ? Colors.grey[500] : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
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
      bottomNavigationBar: _buildBottomNav(context, isDarkMode, textColor, iconColor, primaryColor, accentColor),
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
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(title.toUpperCase(), 
        style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
    );
  }

  Widget _buildGroupedCard(List<Widget> children, {required Color cardColor, required Color borderColor}) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String? subtitle, {bool isLast = false, String? trailingText, VoidCallback? onTap, required bool isDarkMode, required Color textColor, required Color iconColor, required Color borderColor, required Color cardColor}) {
    return InkWell(
      onTap: onTap, // Use the onTap callback
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: isLast ? null : Border(bottom: BorderSide(color: borderColor)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
                  if (subtitle != null) Text(subtitle, style: TextStyle(color: isDarkMode ? Colors.grey[500] : Colors.grey[500], fontSize: 12)),
                ],
              ),
            ),
            if (trailingText != null) Text(trailingText, style: TextStyle(color: isDarkMode ? Colors.grey[500] : Colors.grey[500], fontSize: 12)),
            Icon(Icons.chevron_right, color: isDarkMode ? Colors.grey[500] : Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsToggle(IconData icon, String title, bool value, {bool isLast = false, ValueSetter<bool>? onChanged, required bool isDarkMode, required Color textColor, required Color iconColor, required Color borderColor, required Color cardColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor))),
          Switch.adaptive(
            value: value,
            activeColor: primaryColor,
            onChanged: onChanged, // Use the new onChanged callback
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton({required bool isDarkMode, required Color textColor, required Color primaryColor}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _showLogoutConfirmation(context, isDarkMode, textColor, primaryColor), // Call confirmation modal
        style: ElevatedButton.styleFrom(
          backgroundColor: isDarkMode ? const Color(0xFF2A585A).withOpacity(0.3) : Colors.white,
          foregroundColor: Colors.red,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text('Log Out', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: isDarkMode ? Colors.redAccent : Colors.red)),
      ),
    );
  }

  Future<void> _showLogoutConfirmation(BuildContext context, bool isDarkMode, Color textColor, Color primaryColor) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button for close
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF22262A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Confirm Logout', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          content: Text('Are you sure you want to log out?', style: TextStyle(color: textColor)),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey)),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Dismiss alert dialog
              },
            ),
            TextButton(
              child: Text('Logout', style: TextStyle(color: isDarkMode ? Colors.redAccent : accentColor, fontWeight: FontWeight.bold)),
              onPressed: () async {
                Navigator.of(dialogContext).pop(); // Dismiss alert dialog
                await FirebaseAuth.instance.signOut(); // Sign out from Firebase
                if (mounted) {
                  Provider.of<ThemeNotifier>(context, listen: false).setUserEmail(null); // Clear user email on logout
                  Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false); // Navigate to login page
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomNav(BuildContext context, bool isDarkMode, Color textColor, Color iconColor, Color primaryColor, Color accentColor) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (i) {
        setState(() => currentIndex = i);
        if (i == 0) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => HomeExploreScreen(userEmail: widget.userEmail, userRole: widget.userRole)),
          );
        } else if (i == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SearchResultsPage(userEmail: widget.userEmail, userRole: widget.userRole)),
          );
        } else if (i == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => BookingsDashboardPage(userEmail: widget.userEmail, userRole: widget.userRole)),
          );
        } else if (i == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => FavoritesPage(userEmail: widget.userEmail, userRole: widget.userRole)),
          );
        }
      },
      selectedItemColor: Theme.of(context).bottomNavigationBarTheme.selectedItemColor, // Use theme color
      unselectedItemColor: Theme.of(context).bottomNavigationBarTheme.unselectedItemColor, // Use theme color
      backgroundColor: Theme.of(context).bottomNavigationBarTheme.backgroundColor, // Use theme color
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Explore"),
        BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
        BottomNavigationBarItem(icon: Icon(Icons.confirmation_number), label: "Bookings"),
        BottomNavigationBarItem(icon: Icon(Icons.favorite_border), label: "Favorites"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
      ],
    );
  }
}