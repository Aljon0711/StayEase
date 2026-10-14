import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // For Firestore
import 'package:intl/intl.dart'; // For date formatting
import 'dart:async'; // Required for StreamSubscription
import '../../utils/date_time_utils.dart'; // Import date/time utilities
import 'rooms.dart';
import 'calendar.dart';
import 'bookings.dart';
import 'settings.dart';
import 'profile.dart';

class AdminDashboardPage extends StatefulWidget {
  final String userEmail;
  final String userRole;
  const AdminDashboardPage({super.key, required this.userEmail, required this.userRole});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int currentIndex = 0; // 0 for Home tab
  final Color primaryColor = const Color(0xFF226277);

  List<Map<String, dynamic>> _notifications = [];
  StreamSubscription<QuerySnapshot>? _notificationListener; // For real-time updates

  // Dashboard metrics state
  double _totalRevenue = 0.0;
  int _totalBookings = 0;
  int _pendingBookings = 0;
  int _totalRooms = 0;
  int _occupiedRooms = 0;
  int _checkInsToday = 0;
  int _checkOutsToday = 0;
  List<Map<String, dynamic>> _recentActivities = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _listenToNotifications(); // Start listening for notifications
    _generateCompanyNotifications(); // Periodically check and generate company notifications
  }

  @override
  void dispose() {
    _notificationListener?.cancel(); // Cancel the subscription
    super.dispose();
  }

  // New: Function to listen to notifications for company
  void _listenToNotifications() {
    _notificationListener = FirebaseFirestore.instance
        .collection('notifications')
        .where('userRole', isEqualTo: widget.userRole) // Assuming notifications have a userRole field
        .where('isRead', isEqualTo: false)
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

  Future<void> _generateCompanyNotifications() async {
    // This function will run periodically or on app start to generate notifications
    // for new reservations and guest cancellations.

    // Fetch all bookings
    final allBookingsSnapshot = await FirebaseFirestore.instance.collection('bookings').get();

    for (var bookingDoc in allBookingsSnapshot.docs) {
      final bookingData = bookingDoc.data();
      final bookingId = bookingDoc.id;
      final currentStatus = bookingData['status'];
      final userEmail = bookingData['userEmail'] ?? 'Unknown Guest';
      final roomName = bookingData['roomName'] ?? 'Unknown Room';

      // 1. Check for New Reservations (status == 'pending')
      if (currentStatus == 'pending') {
        // Check for existing unread 'new_reservation' notification for this booking
        final existingNewReservationNotification = await FirebaseFirestore.instance
            .collection('notifications')
            .where('bookingId', isEqualTo: bookingId)
            .where('type', isEqualTo: 'new_reservation')
            .where('isRead', isEqualTo: false)
            .limit(1)
            .get();

        if (existingNewReservationNotification.docs.isEmpty) {
          // If no unread notification exists for this new reservation, create one
          await FirebaseFirestore.instance.collection('notifications').add({
            'userEmail': userEmail,
            'bookingId': bookingId,
            'type': 'new_reservation',
            'title': 'New Booking Request!',
            'message': 'A new booking request for room "$roomName" has been placed by $userEmail (ID: ${bookingId.substring(0, 6)}).',
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'userRole': widget.userRole, // Mark for company role
          });
        }
      }

      // 2. Check for Guest Cancellation (status == 'cancelled')
      if (currentStatus == 'cancelled') {
        // Check for existing unread 'cancellation' notification for this booking
        final existingCancellationNotification = await FirebaseFirestore.instance
            .collection('notifications')
            .where('bookingId', isEqualTo: bookingId)
            .where('type', isEqualTo: 'cancellation')
            .where('isRead', isEqualTo: false)
            .limit(1)
            .get();

        if (existingCancellationNotification.docs.isEmpty) {
          // If no unread notification exists for this cancellation, create one
          await FirebaseFirestore.instance.collection('notifications').add({
            'userEmail': userEmail,
            'bookingId': bookingId,
            'type': 'cancellation',
            'title': 'Booking Cancelled!',
            'message': 'A booking for room "$roomName" by $userEmail (ID: ${bookingId.substring(0, 6)}) has been cancelled.',
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'userRole': widget.userRole, // Mark for company role
          });
        }
      }
    }

    // Schedule periodic check (e.g., every 15 minutes)
    Future.delayed(const Duration(minutes: 15), _generateCompanyNotifications);
  }

  // New: Function to show company notifications
  void _showCompanyNotifications() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Company Notifications"),
          content: _notifications.isEmpty
              ? const Text("No new notifications.")
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(notification['title'] ?? 'No Title'),
                          subtitle: Text(notification['message'] ?? 'No Message'),
                          trailing: IconButton(
                            icon: const Icon(Icons.check_circle_outline),
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
              child: const Text("Close"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }


  Future<void> _fetchDashboardData() async {
    if (!mounted) return;

    setState(() {
      _totalRevenue = 0.0;
      _totalBookings = 0;
      _pendingBookings = 0;
      _totalRooms = 0;
      _occupiedRooms = 0;
      _checkInsToday = 0;
      _checkOutsToday = 0;
      _recentActivities = [];
      _errorMessage = null;
    });

    try {
      // Fetch Total Rooms
      final roomsSnapshot = await FirebaseFirestore.instance.collection('rooms').get();
      _totalRooms = roomsSnapshot.docs.length;

      // Fetch Bookings Data
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .orderBy('bookingDate', descending: true) // For recent activities
          .limit(10) // Limit recent activities
          .get();

      double revenue = 0.0;
      int totalBookingsCount = 0;
      int pendingBookingsCount = 0;
      int occupiedRoomsCount = 0;
      int checkIns = 0;
      int checkOuts = 0;
      List<Map<String, dynamic>> activities = [];

      final now = DateTime.now();

      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? 'pending';
        final totalAmount = data['totalAmount'] as double? ?? 0.0;
        final checkInDateStr = data['checkInDate'] as String?;
        final checkInTimeStr = data['checkInTime'] as String?;
        final checkOutDateStr = data['checkOutDate'] as String?;
        final checkOutTimeStr = data['checkOutTime'] as String?;

        // Calculate revenue and booking counts for confirmed bookings
        if (status == 'approved') {
          revenue += totalAmount;
          totalBookingsCount++;
        } else if (status == 'pending') {
          pendingBookingsCount++;
        }

        // Check-ins and Check-outs for today, and occupied rooms
        if (checkInDateStr != null && checkInTimeStr != null && checkOutDateStr != null && checkOutTimeStr != null) {
          try {
            final checkInDate = DateTime.parse(checkInDateStr);
            final checkInTime = parseTimeOfDay(checkInTimeStr);
            final checkOutDate = DateTime.parse(checkOutDateStr);
            final checkOutTime = parseTimeOfDay(checkOutTimeStr);

            final bookingCheckInDateTime = DateTime(checkInDate.year, checkInDate.month, checkInDate.day, checkInTime.hour, checkInTime.minute);
            final bookingCheckOutDateTime = DateTime(checkOutDate.year, checkOutDate.month, checkOutDate.day, checkOutTime.hour, checkOutTime.minute);

            // Count check-ins only if the current date and time have passed the booking's check-in date and time
            if (now.year == bookingCheckInDateTime.year && now.month == bookingCheckInDateTime.month && now.day == bookingCheckInDateTime.day && now.isAfter(bookingCheckInDateTime)) {
              checkIns++;
            }
            // Count check-outs only if the current date and time have passed the booking's check-out date and time
            if (now.year == bookingCheckOutDateTime.year && now.month == bookingCheckOutDateTime.month && now.day == bookingCheckOutDateTime.day && now.isAfter(bookingCheckOutDateTime)) {
              checkOuts++;
            }

            // Occupied rooms logic: A room is occupied if the current time is between check-in and check-out times
            if (status == 'approved' || status == 'pending') {
              if (now.isAfter(bookingCheckInDateTime) && now.isBefore(bookingCheckOutDateTime)) {
                occupiedRoomsCount++;
              }
            }
          } catch (e) {
            print('Error parsing date or time in dashboard data: $e');
          }
        }

        // Add to recent activities
        final roomName = data['roomName'] ?? 'N/A';
        final userEmail = data['userEmail'] ?? 'Guest';
        final activityType = status == 'pending' ? 'New Booking' :
                             status == 'approved' ? 'Booking Confirmed' :
                             status == 'rejected' ? 'Booking Rejected' :
                             status == 'cancelled' ? 'Booking Cancelled' : 'Activity';
        
        IconData activityIcon = Icons.info;
        Color activityColor = Colors.grey;

        if (status == 'pending') {
          activityIcon = Icons.hourglass_empty;
          activityColor = Colors.orange;
        } else if (status == 'approved') {
          activityIcon = Icons.check_circle;
          activityColor = Colors.green;
        } else if (status == 'rejected') {
          activityIcon = Icons.block;
          activityColor = Colors.red;
        } else if (status == 'cancelled') {
          activityIcon = Icons.cancel;
          activityColor = Colors.red;
        }

        final rawBookingDate = data['bookingDate'];
        DateTime bookingDateTime;
        if (rawBookingDate is Timestamp) {
          bookingDateTime = rawBookingDate.toDate();
        } else if (rawBookingDate is String) {
          bookingDateTime = DateTime.tryParse(rawBookingDate) ?? DateTime.now();
        } else {
          bookingDateTime = DateTime.now();
        }

        activities.add({
          'icon': activityIcon,
          'title': '$activityType: $userEmail',
          'sub': 'Room: $roomName',
          'time': DateFormat('jm').format(bookingDateTime),
          'color': activityColor,
        });
      }

      if (!mounted) return;
      setState(() {
        _totalRevenue = revenue;
        _totalBookings = totalBookingsCount;
        _pendingBookings = pendingBookingsCount;
        _occupiedRooms = occupiedRoomsCount;
        _checkInsToday = checkIns;
        _checkOutsToday = checkOuts;
        _recentActivities = activities;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error fetching dashboard data: $e';
      });
      print('Error fetching dashboard data: $e');
    }
  }

  // Helper Widgets
  Widget _buildHeaderButton(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      width: 40,
      height: 40,
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFDDE2E4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)],
      ),
      child: Icon(icon, color: const Color(0xFF121617), size: 22),
      ),
    );
  }

  Widget _buildNotificationButton() {
    return GestureDetector(
      onTap: _showCompanyNotifications, // Handle notification tap
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFDDE2E4)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)],
        ),
        child: Stack(
          children: [
            const Center(child: Icon(Icons.notifications_none, color: Colors.black, size: 22)),
            if (_notifications.isNotEmpty)
              Positioned(
                right: 5,
                top: 5,
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
    );
  }

  Widget _buildRevenueCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Revenue', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                    child: const Text('+12.5%', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
              const SizedBox(height: 8),
              Text('₱${_totalRevenue.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('Calculated from $_totalBookings stays this month', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallMetric(String title, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE2E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF687C82), fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              Icon(icon, color: iconColor, size: 16),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildProgressMetric(String title, String value, double progress) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE2E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF687C82), fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFFF1F3F4),
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            borderRadius: BorderRadius.circular(10),
            minHeight: 6,
          )
        ],
      ),
    );
  }

  Widget _buildActionSquare(IconData icon, String label, Color color) {
    return Container(
      width: 105,
      height: 105,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE2E4)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {required bool hasViewAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        if (hasViewAll)
          Text('View All', style: TextStyle(color: primaryColor, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActivityList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE2E4)),
      ),
      child: Column(
        children: _recentActivities.asMap().entries.map((entry) {
          final index = entry.key;
          final activity = entry.value;
          return _buildActivityTile(
            activity['icon'],
            activity['title'],
            activity['sub'],
            activity['time'],
            activity['color'],
            isLast: index == _recentActivities.length - 1,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActivityTile(IconData icon, String title, String sub, String time, Color color, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFDDE2E4))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)),
                    Text(time, style: const TextStyle(color: Color(0xFF687C82), fontSize: 10, fontWeight: FontWeight.w600)),
                  ],
                ),
                Text(sub, style: const TextStyle(color: Color(0xFF687C82), fontSize: 12)),
              ],
            ),
          )
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

  Widget _buildBottomNav() {
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
              // Already on Home, no navigation needed
            },
            child: _navItem(Icons.dashboard, 'Home', true),
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
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileSettingsPage(userEmail: widget.userEmail, userRole: widget.userRole)),
              );
            },
            child: _navItem(Icons.person, 'Profile', false),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(_errorMessage!)),
      );
    }
    if (_totalRooms == 0 && _totalBookings == 0 && _recentActivities.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. Sticky App Bar with Profile
              SliverAppBar(
                pinned: true,
                floating: true,
                backgroundColor: (theme.appBarTheme.backgroundColor ??
                        const Color(0xFFF9FAFA))
                    .withOpacity(0.8),
                elevation: 0,
                centerTitle: false,
                titleSpacing: 16,
                leadingWidth: 0,
                leading: const SizedBox.shrink(),
                title: Row(
                  children: [
                    const CircleAvatar(
                      radius: 20,
                      backgroundImage: NetworkImage('https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcR2seVe2iItIpKYKuYr_q6lIZp7OpGjescb7zWrpvM6tw&s'),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PROPERTY ADMIN', 
                          style: TextStyle(color: primaryColor.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                        const Text('Overview', 
                          style: TextStyle(color: Color(0xFF121617), fontSize: 20, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ],
                ),
                actions: [
                  _buildNotificationButton(), // Notification bell with badge
                  _buildHeaderButton(Icons.search), // Search button
                  const SizedBox(width: 16),
                ],
              ),

              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // 2. Metrics Bento Grid
                    _buildRevenueCard(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildSmallMetric('Bookings', '$_totalBookings', Icons.trending_up, Colors.green)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildProgressMetric('Pending', '$_pendingBookings', _totalBookings > 0 ? _pendingBookings / _totalBookings : 0.0)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildSmallMetric('Check-ins', '$_checkInsToday', Icons.login, primaryColor)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildSmallMetric('Check-outs', '$_checkOutsToday', Icons.logout, Colors.orange)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildSmallMetric('Total Rooms', '$_totalRooms', Icons.bed, Colors.blue)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildSmallMetric('Occupied Rooms', '$_occupiedRooms', Icons.person_off, Colors.red)),
                      ],
                    ),

                    // 3. Quick Actions
                    const SizedBox(height: 32),
                    _buildSectionHeader('Quick Actions', hasViewAll: true),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => InventoryPage(userEmail: widget.userEmail, userRole: widget.userRole)));
                          },
                          child: _buildActionSquare(Icons.bed_outlined, 'Rooms', Colors.blue),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => CalendarPage(userEmail: widget.userEmail, userRole: widget.userRole)));
                          },
                          child: _buildActionSquare(Icons.waves, 'Calendar', Colors.cyan), // Changed label to Calendar
                        ),
                      ],
                    ),

                    // 4. Recent Activity
                    const SizedBox(height: 32),
                    _buildSectionHeader('Recent Activity', hasViewAll: false),
                    const SizedBox(height: 12),
                    _buildActivityList(),
                    const SizedBox(height: 100), // Space for Nav
                  ]),
                ),
              ),
            ],
          ),

          // 5. Fixed Bottom Navigation
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildBottomNav(),
          ),
        ],
      ),
    );
  }
}