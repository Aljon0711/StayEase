import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import for Firestore
import 'package:intl/intl.dart'; // Import for date formatting
import 'home.dart';
import 'rooms.dart';
import 'calendar.dart';
import 'settings.dart';
import 'profile.dart';
import 'request_detail.dart';

class PendingRequestsPage extends StatefulWidget {
  final String userEmail;
  final String userRole;
  const PendingRequestsPage({super.key, required this.userEmail, required this.userRole});

  @override
  State<PendingRequestsPage> createState() => _PendingRequestsPageState();
}

class _PendingRequestsPageState extends State<PendingRequestsPage> {
  int currentIndex = 3; // 3 for Booking tab
  final Color primaryColor = const Color(0xFF2D8684);
  
  String _selectedStatusFilter = 'all'; // 'all', 'pending', 'confirmed', 'cancelled'
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor:
            (theme.appBarTheme.backgroundColor ?? const Color(0xFFFAFAF9))
                .withOpacity(0.8),
        elevation: 0,
        scrolledUnderElevation: 1,
        automaticallyImplyLeading: false,
        title: const Text(
          'Booking Requests',
          style: TextStyle(
            color: Color(0xFF101818),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                _buildHeaderIconButton(Icons.notifications_none),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    height: 10,
                    width: 10,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .orderBy('bookingDate', descending: true) // Order by creation time
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No booking requests found.'));
          }

          final allBookings = snapshot.data!.docs.map((doc) {
            return {
              'id': doc.id,
              ...doc.data() as Map<String, dynamic>,
            };
          }).toList();
          
          // Apply filters and search query
          final filteredBookings = allBookings.where((booking) {
            final userName = (booking['userEmail'] as String? ?? '').toLowerCase();
            final roomName = (booking['roomName'] as String? ?? '').toLowerCase();
            final status = (booking['status'] as String? ?? '').toLowerCase();
            
            final matchesSearch = _searchQuery.isEmpty ||
                                  userName.contains(_searchQuery.toLowerCase()) ||
                                  roomName.contains(_searchQuery.toLowerCase());

            final matchesStatusFilter = _selectedStatusFilter == 'all' ||
                                        status == _selectedStatusFilter;
            
            return matchesSearch && matchesStatusFilter;
          }).toList();

          final pendingCount = filteredBookings.where((booking) => booking['status'] == 'pending').length;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildSearchField(),
                const SizedBox(height: 24),
                _buildFilterChips(),
                const SizedBox(height: 32),
                _buildSummaryHeader(pendingCount), // Pass pending count
                const SizedBox(height: 16),
                if (filteredBookings.isEmpty)
                  const Center(child: Text('No matching booking requests found.'))
                else
                  ...filteredBookings.map((booking) {
                    final checkInDate = (booking['checkInDate'] as String).substring(0, 10);
                    final numberOfNights = booking['numberOfNights'] as int;
                    final numberOfDays = booking['numberOfDays'] as int;
                    final checkOutDate = DateFormat('MMM dd')
                        .format(DateTime.parse(checkInDate).add(Duration(days: numberOfNights + numberOfDays)));
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: _buildBookingCard(
                        name: booking['userEmail'] ?? 'N/A', // Assuming userEmail is the name
                        room: booking['roomName'] ?? 'N/A',
                        roomCategory: booking['roomCategory'] ?? 'N/A', // Pass category
                        price: (booking['totalAmount'] as double).toStringAsFixed(2),
                        dates: '${DateFormat('MMM dd').format(DateTime.parse(checkInDate))} - $checkOutDate',
                        guests: '${booking['numberOfAdults'] ?? 0} Adults, ${booking['numberOfChildren'] ?? 0} Children',
                        status: booking['status'] ?? 'pending',
                        bookingId: booking['id'] as String,
                        statusReason: booking['statusReason'] as String?, // Pass status reason
                        onViewDetail: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BookingDetailPage(
                                bookingId: booking['id'] as String,
                                userEmail: widget.userEmail,
                                userRole: widget.userRole,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(),
                const SizedBox(height: 100), // Space for bottom nav
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeaderIconButton(IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: const Color(0xFF101818), size: 20),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      decoration: InputDecoration(
        hintText: 'Search guest names or room...',
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        prefixIcon: Icon(Icons.search, color: primaryColor),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _buildFilterChips() {
    final List<String> statuses = ['all', 'pending', 'approved', 'cancelled', 'rejected'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: statuses.map((status) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _chip(status, isActive: _selectedStatusFilter == status.toLowerCase(), onTap: () {
              setState(() {
                _selectedStatusFilter = status.toLowerCase();
              });
            }),
          );
        }).toList(),
      ),
    );
  }

  Widget _chip(String label, {bool isActive = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(50),
          border: isActive ? null : Border.all(color: Colors.grey.shade100),
          boxShadow: isActive
              ? [BoxShadow(color: primaryColor.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))]
              : null,
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey.shade600,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader(int pendingCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$pendingCount PENDING REQUESTS',
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'Last updated ${DateFormat('jm').format(DateTime.now())}', // Dynamic update time
            style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        )
      ],
    );
  }

  Widget _buildBookingCard({
    required String name,
    required String room,
    required String roomCategory,
    required String price,
    required String dates,
    required String guests,
    required String status,
    required String bookingId,
    String? statusReason,
    VoidCallback? onViewDetail,
  }) {
    Color statusColor = Colors.grey;
    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        break;
      case 'approved':
        statusColor = Colors.green;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        break;
      case 'rejected':
        statusColor = Colors.red; // Use red for rejected status
        break;
      default:
        statusColor = Colors.grey;
    }

    IconData roomIcon = Icons.king_bed;
    if (roomCategory.toLowerCase() == 'pool') {
      roomIcon = Icons.pool;
    }

    return Opacity(
      opacity: status == 'cancelled' ? 0.6 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(roomIcon, size: 14, color: primaryColor),
                        const SizedBox(width: 4),
                        Text(room, style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    )
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₱$price', style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 18)),
                    const Text('TOTAL STAY', style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.w800)),
                  ],
                )
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0xFFF5F5F4)),
            ),
            Row(
              children: [
                _infoTile(Icons.calendar_today, 'DATES', dates),
                const SizedBox(width: 24),
                _infoTile(Icons.group, 'GUESTS', guests),
              ],
            ),
            if ((status == 'cancelled' || status == 'rejected') && statusReason != null && statusReason.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Text(
                  'Reason: $statusReason',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic),
                ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(
                  width: 120, // Adjust width as needed
                  child: ElevatedButton.icon(
                    onPressed: onViewDetail,
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('View Detail'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: primaryColor.withOpacity(0.3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12), // Adjust padding
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: const Color(0xFFF5F5F4), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: Colors.grey),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.w800)),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ],
        )
      ],
    );
  }

  Widget _buildBottomNav() {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 90,
      padding: const EdgeInsets.only(bottom: 24, left: 32, right: 32),
      decoration: BoxDecoration(
        color: theme.bottomNavigationBarTheme.backgroundColor ??
            (isDark ? const Color(0xFF22262A) : Colors.white),
        border: Border(
            top: BorderSide(
                color:
                    isDark ? Colors.grey[800]! : const Color(0xFFDDE2E4))),
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
          _navItem(Icons.confirmation_number, 'Booking', true),
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