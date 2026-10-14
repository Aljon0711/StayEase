import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import for Firestore
import 'package:intl/intl.dart'; // Import for date formatting
import 'home.dart';
import 'search.dart';
import 'profile.dart';
import 'favorites.dart';
import 'booking_detail_guest.dart'; // Import the new detail page
import '../../utils/date_time_utils.dart'; // Import date/time utilities

class BookingsDashboardPage extends StatefulWidget {
  final String userEmail;
  final String userRole;
  const BookingsDashboardPage({super.key, required this.userEmail, required this.userRole});

  @override
  State<BookingsDashboardPage> createState() => _BookingsDashboardPageState();
}

class _BookingsDashboardPageState extends State<BookingsDashboardPage> {
  int _selectedTab = 0; // 0 for Active, 1 for Past
  int currentIndex = 2; // 2 for Bookings tab
  final Color primaryColor = const Color(0xFF2A585A);
  final Color accentGold = const Color(0xFFCBA474);
  final Color bgLight = const Color(0xFFF6F2EF);

  @override
  void initState() {
    super.initState();
  }

  Future<void> _updateBookingStatus(String bookingId, String newStatus, {String? reason}) async {
    try {
      await FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({
        'status': newStatus,
        'lastUpdated': FieldValue.serverTimestamp(),
        if (reason != null) 'statusReason': reason,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking $newStatus successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update booking status: $e')),
        );
      }
    }
  }

  Future<void> _showCancelReasonDialog(String bookingId) async {
    String? reason;
    await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Provide Reason'),
          content: TextField(
            onChanged: (value) {
              reason = value;
            },
            decoration: const InputDecoration(hintText: "Reason (optional)"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Back'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            ElevatedButton(
              child: const Text('Confirm'),
              onPressed: () {
                Navigator.pop(context, reason);
              },
            ),
          ],
        );
      },
    ).then((value) {
      if (value != null) {
        _updateBookingStatus(bookingId, 'cancelled', reason: value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Top App Bar
          SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFFF6F2EF).withOpacity(0.8),
            elevation: 0,
            automaticallyImplyLeading: false,
            actions: [
              _buildRoundIconButton(Icons.notifications_none),
              const SizedBox(width: 8),
            ],
            title: const Text(
              'My Bookings',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            centerTitle: true,
          ),

          // 2. Segmented Control
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: _buildSegmentedControl(),
            ),
          ),

          // 3. Booking List (Active/Past)
          // NOTE: We intentionally avoid orderBy in the Firestore query to remove composite index requirements.
          //       Sorting is done client-side by checkInDate instead.
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('bookings')
                .where('userEmail', isEqualTo: widget.userEmail)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return SliverToBoxAdapter(child: Center(child: Text('Error: ${snapshot.error}')));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const SliverToBoxAdapter(child: Center(child: Text('No bookings found.')));
              }

              final allBookings = snapshot.data!.docs.map((doc) {
                final bookingData = doc.data() as Map<String, dynamic>;
                final checkInDateStr = bookingData['checkInDate'] as String?;
                final checkInTimeStr = bookingData['checkInTime'] as String?;
                final checkOutDateStr = bookingData['checkOutDate'] as String?;
                final checkOutTimeStr = bookingData['checkOutTime'] as String?;

                // Fallback to calculate if not present (for old bookings)
                DateTime checkInDate = checkInDateStr != null ? DateTime.parse(checkInDateStr) : DateTime.now();
                TimeOfDay checkInTime = parseTimeOfDay(checkInTimeStr ?? '00:00');

                DateTime calculatedCheckOutDate = calculateCheckOutDate(checkInDate, checkInTime, bookingData['numberOfNights'] ?? 0, bookingData['numberOfDays'] ?? 0); // Helper to calculate
// TimeOfDay calculatedCheckOutTime = calculateCheckOutTime(checkInDate, checkInTime, bookingData['numberOfNights'] ?? 0, bookingData['numberOfDays'] ?? 0); // Helper to calculate

                DateTime finalCheckOutDateTime = calculatedCheckOutDate; // Default to calculated
                if (checkOutDateStr != null && checkOutTimeStr != null) {
                  try {
                    final tempDate = DateTime.parse(checkOutDateStr);
                    final tempTime = parseTimeOfDay(checkOutTimeStr);
                    finalCheckOutDateTime = DateTime(tempDate.year, tempDate.month, tempDate.day, tempTime.hour, tempTime.minute);
                  } catch (e) {
                    print('Error parsing stored checkOutDate/Time: $e');
                  }
                }

                return {
                  'id': doc.id,
                  'finalCheckOutDateTime': finalCheckOutDateTime, // Use for sorting and filtering
                  ...bookingData,
                };
              }).toList();

              // Sort bookings by checkInDate ascending on the client side
              allBookings.sort((a, b) {
                final aDateStr = a['checkInDate'] as String?;
                final bDateStr = b['checkInDate'] as String?;
                if (aDateStr == null && bDateStr == null) return 0;
                if (aDateStr == null) return 1;
                if (bDateStr == null) return -1;
                try {
                  final aDate = DateTime.parse(aDateStr);
                  final bDate = DateTime.parse(bDateStr);
                  return aDate.compareTo(bDate);
                } catch (_) {
                  return 0;
                }
              });
              final now = DateTime.now();

              // Filter bookings based on selected tab
              final filteredBookings = allBookings.where((booking) {
                final finalCheckOutDateTime = booking['finalCheckOutDateTime'] as DateTime;

                if (_selectedTab == 0) { // Active Bookings
                  return finalCheckOutDateTime.isAfter(now) || finalCheckOutDateTime.isAtSameMomentAs(now);
                } else { // Past Bookings
                  return finalCheckOutDateTime.isBefore(now);
                }
              }).toList();

              if (filteredBookings.isEmpty) {
                return SliverToBoxAdapter(child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text('No ${_selectedTab == 0 ? 'active' : 'past'} bookings found.'),
                  ),
                ));
              }
              
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final booking = filteredBookings[index];
                    final checkInDateStr = booking['checkInDate'] as String?;
                    final checkInTimeStr = booking['checkInTime'] as String?;

                    DateTime checkInDate = DateTime.now();
                    if (checkInDateStr != null) {
                      try {
                        checkInDate = DateTime.parse(checkInDateStr);
                      } catch (e) {
                        print('Error parsing checkInDate: $e');
                      }
                    }
                    TimeOfDay checkInTime = parseTimeOfDay(checkInTimeStr ?? '00:00');

                    DateTime finalCheckOutDateTime = booking['finalCheckOutDateTime'] as DateTime;

                    return _buildBookingItem(
                      imageUrl: booking['roomImageUrl'] ?? '',
                      roomName: booking['roomName'] ?? 'N/A',
                      dates: '${DateFormat('MMM dd, yyyy').format(checkInDate)} at ${checkInTime.format(context)} - ${DateFormat('MMM dd, yyyy').format(finalCheckOutDateTime)} at ${TimeOfDay.fromDateTime(finalCheckOutDateTime).format(context)}',
                      guests: '${booking['numberOfAdults'] ?? 0} Adults, ${booking['numberOfChildren'] ?? 0} Children',
                      totalPrice: (booking['totalAmount'] as double? ?? 0.0).toStringAsFixed(2),
                      bookingId: booking['id'],
                      status: booking['status'] ?? 'pending',
                      isBookingActive: _selectedTab == 0, // Pass whether it's an active booking
                      statusReason: booking['statusReason'] as String?, // Pass status reason
                    );
                  },
                  childCount: filteredBookings.length,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)), // Space for bottom nav
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildRoundIconButton(IconData icon) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
      ),
      child: Icon(icon, color: Colors.black, size: 20),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          _buildTabItem('Active', 0),
          _buildTabItem('Past', 1),
        ],
      ),
    );
  }

  Widget _buildTabItem(String label, int index) {
    bool isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF6D7D7E),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookingItem({
    required String imageUrl,
    required String roomName,
    required String dates,
    required String guests,
    required String totalPrice,
    required String bookingId,
    required String status,
    required bool isBookingActive,
    String? statusReason,
  }) {
    Color statusColor;
    String statusText;
    switch (status) {
      case 'pending':
        statusColor = accentGold; // Use accent gold for pending
        statusText = 'PENDING';
        break;
      case 'approved':
        statusColor = primaryColor;
        statusText = 'CONFIRMED'; // Display as CONFIRMED for guests
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'REJECTED';
        break;
      case 'cancelled':
        statusColor = Colors.grey;
        statusText = 'CANCELLED';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'UNKNOWN';
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookingDetailGuestPage(
              bookingId: bookingId,
              userEmail: widget.userEmail,
              userRole: widget.userRole,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        roomName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dates,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        guests,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  '₱$totalPrice',
                  style: TextStyle(color: primaryColor, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if ((status == 'cancelled' || status == 'rejected') && statusReason != null && statusReason.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Reason: $statusReason',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  statusText,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                if (isBookingActive && status == 'pending') // Only show cancel for active and pending bookings
                  SizedBox(
                    height: 30, // Adjust height as needed
                    child: OutlinedButton(
                      onPressed: () => _showCancelReasonDialog(bookingId),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red, width: 1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 10), // Adjust padding
                      ),
                      child: const Text('Cancel Booking', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
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
      selectedItemColor: primaryColor,
      unselectedItemColor: Colors.grey,
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