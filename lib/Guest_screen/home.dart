import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; // Required for StreamSubscription
import 'dart:convert';
import 'search.dart';
import 'profile.dart';
import 'bookings.dart';
import 'room_detail.dart'; // Updated to RoomDetailLoaderPage
import 'favorites.dart';
import '../../utils/date_time_utils.dart'; // Import date/time utilities


class HomeExploreScreen extends StatefulWidget {
  final String userEmail;
  final String userRole;
  const HomeExploreScreen({super.key, required this.userEmail, required this.userRole});

  @override
  State<HomeExploreScreen> createState() => _HomeExploreScreenState();
}

class _HomeExploreScreenState extends State<HomeExploreScreen> {
  int currentIndex = 0;
  String _userName = 'User'; // Default value
  String _selectedCategory = 'rooms'; // Default to rooms
  List<Map<String, dynamic>> _notifications = [];
  StreamSubscription<QuerySnapshot>? _notificationListener; // For real-time updates

  @override
  void initState() {
    super.initState();
    _fetchUserName();
    _listenToNotifications(); // Start listening for notifications
    _generateBookingNotifications(); // Periodically check and generate notifications
  }

  @override
  void dispose() {
    _notificationListener?.cancel(); // Cancel the subscription
    super.dispose();
  }

  // New: Function to listen to notifications
  void _listenToNotifications() {
    _notificationListener = FirebaseFirestore.instance
        .collection('notifications')
        .where('userEmail', isEqualTo: widget.userEmail)
        .where('isRead', isEqualTo: false)
        .where('userRole', isEqualTo: 'guest') // Filter for guest notifications
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _notifications = snapshot.docs.map((doc) => {
                'id': doc.id,
                ...doc.data(),
              }).toList();
        });
      }
    });
  }

  Future<void> _generateBookingNotifications() async {
    // This function will run periodically or on app start to generate notifications
    // for booking status changes and check-in reminders.
    // To avoid redundant notifications, we'll check if a similar unread notification already exists.

    // Fetch all bookings for the current user
    final userBookingsSnapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('userEmail', isEqualTo: widget.userEmail)
        .get();

    for (var bookingDoc in userBookingsSnapshot.docs) {
      final bookingData = bookingDoc.data();
      final bookingId = bookingDoc.id;
      final currentStatus = bookingData['status'];
      final dynamic checkInDateRaw = bookingData['checkInDate'];
      DateTime checkInDate;

      if (checkInDateRaw is Timestamp) {
        checkInDate = checkInDateRaw.toDate();
      } else if (checkInDateRaw is String) {
        checkInDate = DateTime.tryParse(checkInDateRaw) ?? DateTime.now();
      }
      else {
        checkInDate = DateTime.now(); // Default to now if type is unknown or null
      }

      final checkInTimeStr = bookingData['checkInTime'] as String;
      final checkInTime = parseTimeOfDay(checkInTimeStr);

      final checkInDateTime = DateTime(
        checkInDate.year,
        checkInDate.month,
        checkInDate.day,
        checkInTime.hour,
        checkInTime.minute,
      );

      // 1. Check for Booking Status Changes
      // Query for existing unread status change notifications for this booking
      final existingStatusNotification = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userEmail', isEqualTo: widget.userEmail)
          .where('bookingId', isEqualTo: bookingId)
          .where('type', isEqualTo: 'status_change')
          .where('status', isEqualTo: currentStatus)
          .where('isRead', isEqualTo: false)
          .where('userRole', isEqualTo: 'guest') // Filter for guest notifications
          .limit(1)
          .get();

      // Only notify for 'approved' or 'rejected' status changes for guests
      if ((currentStatus == 'approved' || currentStatus == 'rejected') &&
          existingStatusNotification.docs.isEmpty) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userEmail': widget.userEmail,
          'bookingId': bookingId,
          'type': 'status_change',
          'title': 'Booking Status Update!',
          'message': 'Your booking (ID: ${bookingId.substring(0, 6)}) status has changed to $currentStatus.',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'status': currentStatus,
          'userRole': 'guest', // Add userRole field
        });
      }

      // 2. Check for 5-hour Check-in Reminder
      final now = DateTime.now();
      final timeUntilCheckIn = checkInDateTime.difference(now);
      const fiveHours = Duration(hours: 5);

      // Only remind if check-in is within 5 hours and in the future
      if (timeUntilCheckIn > Duration.zero && timeUntilCheckIn <= fiveHours) {
        // Query for existing unread check-in reminder for this booking
        final existingReminderNotification = await FirebaseFirestore.instance
            .collection('notifications')
            .where('userEmail', isEqualTo: widget.userEmail)
            .where('bookingId', isEqualTo: bookingId)
            .where('type', isEqualTo: 'checkin_reminder')
            .where('isRead', isEqualTo: false)
            .limit(1)
            .get();

        if (existingReminderNotification.docs.isEmpty) {
          // If no unread reminder exists, create one
          await FirebaseFirestore.instance.collection('notifications').add({
            'userEmail': widget.userEmail,
            'bookingId': bookingId,
            'type': 'checkin_reminder',
            'title': 'Upcoming Check-in Reminder!',
            'message': 'Your check-in for booking (ID: ${bookingId.substring(0, 6)}) is at ${checkInTime.format(context)} today!',
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'userRole': 'guest', // Add userRole field
          });
        }
      }
    }

    // Schedule periodic check (e.g., every 15 minutes)
    Future.delayed(const Duration(minutes: 15), _generateBookingNotifications);
  }

  // New: Function to show guest notifications
  void _showGuestNotifications() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final bool isDarkMode = Theme.of(dialogContext).brightness == Brightness.dark;
        final Color textColor = isDarkMode ? Colors.white : Colors.black;
        final Color cardColor = isDarkMode ? const Color(0xFF22262A) : Colors.white;

        return AlertDialog(
          backgroundColor: cardColor,
          title: Text("Notifications", style: TextStyle(color: textColor)),
          content: _notifications.isEmpty
              ? Text("No new notifications.", style: TextStyle(color: textColor))
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      return Card(
                        color: isDarkMode ? Colors.grey[800] : Colors.white,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(notification['title'] ?? 'No Title', style: TextStyle(color: textColor)),
                          subtitle: Text(notification['message'] ?? 'No Message', style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey)),
                          trailing: IconButton(
                            icon: Icon(Icons.check_circle_outline, color: isDarkMode ? Colors.white70 : Colors.black54),
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection('notifications')
                                  .doc(notification['id'])
                                  .update({'isRead': true});
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
          actions: <Widget>[
            TextButton(
              child: Text("Close", style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.blue)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }



  Future<void> _fetchUserName() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.userEmail).get();
      if (doc.exists) {
        setState(() {
          _userName = doc.data()?['fullName'] ?? 'User';
        });
      }
    } catch (e) {
      print('Error fetching user name: $e'); // For debugging
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    final Color greyTextColor = isDarkMode ? Colors.grey[400]! : Colors.grey;
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color cardColor = isDarkMode ? const Color(0xFF22262A) : Colors.white;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(isDarkMode, textColor, primaryColor),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeadline(isDarkMode, textColor, primaryColor),
            _buildSearchCard(isDarkMode, textColor, primaryColor, cardColor),
            _buildCategories(isDarkMode, primaryColor),
            _buildFeaturedHeader(isDarkMode, textColor),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection(_selectedCategory).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: textColor)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No featured stays found.', style: TextStyle(color: textColor)));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    return _buildFeaturedCard(
                      image: data['imageUrl'] ?? "https://via.placeholder.com/200",
                      title: data['name'] ?? "No Title",
                      subtitle: data['description'] ?? data['details'] ?? "No Description",
                      price: "₱${data['price'] ?? '0.00'} / ${data['priceUnit'] ?? 'night'}",
                      type: _selectedCategory,
                      itemId: doc.id,
                      isDarkMode: isDarkMode,
                      textColor: textColor,
                      primaryColor: primaryColor,
                      cardColor: cardColor,
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(isDarkMode, primaryColor, greyTextColor),
    );
  }

  AppBar _buildAppBar(bool isDarkMode, Color textColor, Color primaryColor) {
    return AppBar(
      elevation: 0,
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: isDarkMode ? Colors.white12 : Colors.transparent,
            backgroundImage: const NetworkImage(
              "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcR2seVe2iItIpKYKuYr_q6lIZp7OpGjescb7zWrpvM6tw&s",
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Welcome Back",
                  style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.grey)),
              Text(_userName,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
            ],
          )
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: _showGuestNotifications, // Handle notification tap
            child: Stack(
              children: [
                CircleAvatar(
                  backgroundColor: isDarkMode ? Colors.white12 : Colors.white,
                  child: Icon(Icons.notifications, color: isDarkMode ? Colors.white : Colors.black),
                ),
                if (_notifications.isNotEmpty)
                  Positioned(
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${_notifications.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildHeadline(bool isDarkMode, Color textColor, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: textColor, fontSize: 32),
          children: [
            const TextSpan(text: "Find your peaceful\n"),
            TextSpan(
              text: "escape",
              style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: isDarkMode ? primaryColor.withOpacity(0.8) : primaryColor,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchCard(bool isDarkMode, Color textColor, Color primaryColor, Color cardColor) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: isDarkMode ? 0 : 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('companyProfile').doc('hotelDetails').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _infoRow(Icons.location_on, "Location", "Loading...", isDarkMode, textColor, primaryColor);
                  }
                  if (snapshot.hasError) {
                    return _infoRow(Icons.location_on, "Location", "Error", isDarkMode, textColor, primaryColor);
                  }
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    final location = data['location'] ?? "Malay, Aklan, Philippines";
                    return _infoRow(Icons.location_on, "Location", location, isDarkMode, textColor, primaryColor);
                  }
                  return _infoRow(Icons.location_on, "Location", "Malay, Aklan, Philippines", isDarkMode, textColor, primaryColor);
                },
              ),
              Divider(color: isDarkMode ? Colors.white38 : Colors.grey),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SearchResultsPage(userEmail: widget.userEmail, userRole: widget.userRole)),
                  );
                },
                icon: const Icon(Icons.search, color: Colors.white),
                label: const Text("Search Stays", style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, bool isDarkMode, Color textColor, Color primaryColor) {
    return Row(
      children: [
        Icon(icon, color: primaryColor),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(),
              style: TextStyle(fontSize: 10, color: isDarkMode ? Colors.grey[400] : Colors.grey)),
          Text(value,
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
        ])
      ],
    );
  }

  Widget _buildCategories(bool isDarkMode, Color primaryColor) {
    final categories = [
      {"label": "Rooms", "icon": Icons.bed, "type": "rooms"},
      {"label": "Pools", "icon": Icons.pool, "type": "pools"},
    ];

    return SizedBox(
      height: 60,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          return ActionChip(
            avatar: Icon(categories[i]['icon'] as IconData, color: _selectedCategory == categories[i]['type'] ? Colors.white : (isDarkMode ? Colors.white70 : Colors.black54)),
            label: Text(
              categories[i]['label'] as String,
              style: TextStyle(color: _selectedCategory == categories[i]['type'] ? Colors.white : (isDarkMode ? Colors.white70 : Colors.black54)),
            ),
            backgroundColor:
                _selectedCategory == categories[i]['type'] ? primaryColor : (isDarkMode ? Colors.grey[800] : Colors.grey[200]),
            onPressed: () {
              setState(() {
                _selectedCategory = categories[i]['type'] as String;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildFeaturedHeader(bool isDarkMode, Color textColor) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Featured Stays",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildImageWidget(String imageUrl) {
    if (imageUrl.startsWith('data:image')) {
      // It's a base64 string
      final String base64String = imageUrl.split(',').last;
      return Image.memory(
        base64Decode(base64String),
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.network(
            "https://via.placeholder.com/200", // Placeholder if base64 fails
            height: 200,
            fit: BoxFit.cover,
          );
        },
      );
    } else {
      // Assume it's a network URL
      return Image.network(
        imageUrl,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.network(
            "https://via.placeholder.com/200", // Placeholder if network fails
            height: 200,
            fit: BoxFit.cover,
          );
        },
      );
    }
  }

  Widget _buildFeaturedCard({
    required String image,
    required String title,
    required String subtitle,
    required String price,
    required String type,
    required String itemId,
    required bool isDarkMode,
    required Color textColor,
    required Color primaryColor,
    required Color cardColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: isDarkMode ? 0 : 4,
        child: Column(
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: _buildImageWidget(image),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(title,
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                        // Removed star rating display
                      ]),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey)),
                  const SizedBox(height: 12),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(price,
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                        TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RoomDetailLoaderPage(
                                    itemId: itemId,
                                    itemType: type,
                                    userEmail: widget.userEmail,
                                    userRole: widget.userRole,
                                  ),
                                ),
                              );
                            },
                            child: Text("View Details", style: TextStyle(color: primaryColor)))
                      ])
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(bool isDarkMode, Color primaryColor, Color greyTextColor) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (i) {
        setState(() => currentIndex = i);
        if (i == 1) {
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
        } else if (i == 4) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProfileSettingsPage(userEmail: widget.userEmail, userRole: widget.userRole)),
          );
        }
      },
      selectedItemColor: Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
      unselectedItemColor: Theme.of(context).bottomNavigationBarTheme.unselectedItemColor,
      backgroundColor: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Explore"),
        BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
        BottomNavigationBarItem(
            icon: Icon(Icons.confirmation_number), label: "Bookings"),
        BottomNavigationBarItem(icon: Icon(Icons.favorite_border), label: "Favorites"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
      ],
    );
  }
}
