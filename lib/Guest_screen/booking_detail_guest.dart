import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/date_time_utils.dart'; // Import date/time utilities

class BookingDetailGuestPage extends StatefulWidget {
  final String bookingId;
  final String userEmail;
  final String userRole;

  const BookingDetailGuestPage({
    super.key,
    required this.bookingId,
    required this.userEmail,
    required this.userRole,
  });

  @override
  State<BookingDetailGuestPage> createState() => _BookingDetailGuestPageState();
}

class _BookingDetailGuestPageState extends State<BookingDetailGuestPage> {
  Map<String, dynamic>? _bookingData;
  bool _isLoading = true;
  String? _errorMessage;
  String? _guestName; // Store guest name separately
  String? _roomFloor; // Store room floor separately
  String? _roomSize; // Store room size separately

  // For editing
  late TextEditingController _adultsController;
  late TextEditingController _childrenController;
  late List<Map<String, dynamic>> _selectedAddons;
  bool _isEditing = false;
  
  final Color primaryColor = const Color(0xFF2A585A); // Changed primary color
  final Color statusRed = const Color(0xFFB82E2E);
  final Color statusGreen = const Color(0xFF3D994C);
  final Color statusOrange = const Color(0xFFCBA474); // For pending

  @override
  void initState() {
    super.initState();
    _adultsController = TextEditingController();
    _childrenController = TextEditingController();
    _selectedAddons = []; // Initialize as empty list
    _fetchBookingDetails();
  }

  @override
  void dispose() {
    _adultsController.dispose();
    _childrenController.dispose();
    super.dispose();
  }

  Future<void> _fetchBookingDetails() async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final bookingData = docSnapshot.data() as Map<String, dynamic>;
        
        // Fetch guest name if not in booking (for old bookings)
        String? guestName = bookingData['guestName'] as String?;
        if (guestName == null || guestName == 'N/A') {
          try {
            final userEmail = bookingData['userEmail'] as String?;
            if (userEmail != null) {
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userEmail.toLowerCase())
                  .get();
              if (userDoc.exists) {
                guestName = userDoc.data()?['fullName'] ?? 'N/A';
              }
            }
          } catch (e) {
            print('Error fetching user name: $e');
          }
        }

        // Fetch room floor and size if not in booking (for old bookings)
        String? roomFloor = bookingData['roomFloor'] as String?;
        String? roomSize = bookingData['roomSize'] as String?;
        if ((roomFloor == null || roomFloor == 'N/A' || roomSize == null || roomSize == 'N/A')) {
          try {
            final roomName = bookingData['roomName'] as String?;
            if (roomName != null) {
              final roomsSnapshot = await FirebaseFirestore.instance
                  .collection('rooms')
                  .where('name', isEqualTo: roomName)
                  .limit(1)
                  .get();
              if (roomsSnapshot.docs.isNotEmpty) {
                final roomData = roomsSnapshot.docs.first.data();
                if (roomFloor == null || roomFloor == 'N/A') {
                  roomFloor = roomData['floor'] ?? 'N/A';
                }
                if (roomSize == null || roomSize == 'N/A') {
                  roomSize = roomData['roomArea'] ?? 'N/A';
                }
              }
            }
          } catch (e) {
            print('Error fetching room data: $e');
          }
        }

        if (!mounted) return;
        setState(() {
          _bookingData = bookingData;
          _guestName = guestName ?? 'N/A';
          _roomFloor = roomFloor ?? 'N/A';
          _roomSize = roomSize ?? 'N/A';
          
          _adultsController.text = (bookingData['numberOfAdults'] ?? 0).toString();
          _childrenController.text = (bookingData['numberOfChildren'] ?? 0).toString();
          _selectedAddons = List<Map<String, dynamic>>.from(bookingData['selectedAddons'] ?? []);

          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Booking not found.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error fetching details: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateBooking() async {
    if (_bookingData == null) return;

    setState(() => _isLoading = true);
    try {
      final updatedAdults = int.tryParse(_adultsController.text) ?? 0;
      final updatedChildren = int.tryParse(_childrenController.text) ?? 0;

      // Recalculate total amount if add-ons or guests change
      // (Simplified: assuming price calculation logic is in confirm_booking.dart and not directly here)
      // For a real app, you'd likely re-run price calculation server-side or duplicate the logic.
      // For now, we'll just update the guest and addon fields directly.

      await FirebaseFirestore.instance.collection('bookings').doc(widget.bookingId).update({
        'numberOfAdults': updatedAdults,
        'numberOfChildren': updatedChildren,
        'selectedAddons': _selectedAddons,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking updated successfully!')),
        );
        setState(() {
          _isEditing = false;
          _fetchBookingDetails(); // Re-fetch to update local state and display
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update booking: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(_errorMessage!)),
      );
    }

    if (_bookingData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Not Found')),
        body: const Center(child: Text('Booking data is missing.')),
      );
    }

    // Extract data
    final String guestName = _guestName ?? _bookingData!['guestName'] ?? 'N/A';
    final String guestEmail = _bookingData!['userEmail'] ?? 'N/A';
    final String bookingIdDisplay = widget.bookingId; // Or use a custom ID from _bookingData if available
    final String roomName = _bookingData!['roomName'] ?? 'N/A';
    final String roomImageUrl = _bookingData!['roomImageUrl'] ?? 'https://via.placeholder.com/200';
    final double roomPrice = _bookingData!['roomPrice'] as double? ?? 0.0;
    final String roomPriceUnit = _bookingData!['roomPriceUnit'] ?? 'night';
    final String roomFloor = _roomFloor ?? _bookingData!['roomFloor'] ?? 'N/A';
    final String roomCategory = _bookingData!['roomCategory'] ?? 'N/A';
    final String roomSize = _roomSize ?? _bookingData!['roomSize'] ?? 'N/A';
    final String checkInDateStr = _bookingData!['checkInDate'] ?? 'N/A';
    final String checkInTimeStr = _bookingData!['checkInTime'] ?? '00:00';
    final String checkOutDateStr = _bookingData!['checkOutDate'] ?? ''; // Get checkout date from Firestore
    final String checkOutTimeStr = _bookingData!['checkOutTime'] ?? '00:00';
    final int numberOfNights = _bookingData!['numberOfNights'] ?? 0;
    final int numberOfDays = _bookingData!['numberOfDays'] ?? 0;
    final int numberOfAdults = _bookingData!['numberOfAdults'] ?? 0;
    final int numberOfChildren = _bookingData!['numberOfChildren'] ?? 0;
    final double totalAmount = _bookingData!['totalAmount'] as double? ?? 0.0;
    final String status = _bookingData!['status'] ?? 'pending';
    final String? rejectionReason = _bookingData!['rejectionReason'];
    final Timestamp? bookingDate = _bookingData!['bookingDate'] is Timestamp ? _bookingData!['bookingDate'] as Timestamp : null;


    DateTime checkInDate = DateTime.now();
    try {
      checkInDate = DateTime.parse(checkInDateStr);
    } catch (_) {}
    final TimeOfDay checkInTime = parseTimeOfDay(checkInTimeStr);

    // Use saved checkout date from Firestore, or calculate as fallback for old bookings
    DateTime checkOutDate = checkInDate.add(Duration(days: numberOfNights + numberOfDays));
    if (checkOutDateStr.isNotEmpty) {
      try {
        checkOutDate = DateTime.parse(checkOutDateStr);
      } catch (_) {
        // If parsing fails, use the calculated date as fallback
      }
    }
    final TimeOfDay checkOutTime = parseTimeOfDay(checkOutTimeStr);

    final bool canEdit = status == 'pending';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.8),
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: primaryColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Booking Details', // Changed title
          style: TextStyle(color: Color(0xFF131516), fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          if (canEdit && !_isEditing)
            IconButton(
              icon: Icon(Icons.edit, color: primaryColor, size: 20),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
          if (_isEditing)
            IconButton(
              icon: Icon(Icons.save, color: primaryColor, size: 20),
              onPressed: _updateBooking,
            ),
          if (_isEditing)
            IconButton(
              icon: Icon(Icons.cancel, color: Colors.red, size: 20),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _fetchBookingDetails(); // Revert changes
                });
              },
            ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor: primaryColor.withOpacity(0.1),
              child: Icon(Icons.chat_bubble_outline, color: primaryColor, size: 20),
            ),
          )
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              children: [
                _buildGuestProfile(guestName, guestEmail, bookingIdDisplay, bookingDate),
                _buildStayDetails(checkInDate, checkInTime, checkOutDate, checkOutTime, numberOfAdults, numberOfChildren, numberOfNights, numberOfDays, canEdit),
                _buildRoomChoice(roomName, roomImageUrl, roomFloor, roomCategory, roomSize, totalAmount, numberOfNights, numberOfDays, roomPrice, roomPriceUnit, _selectedAddons, canEdit), // Pass _selectedAddons
                _buildFinancialSummary(totalAmount, status, roomPrice, numberOfNights, numberOfDays, _selectedAddons, rejectionReason),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestProfile(String guestName, String guestEmail, String bookingIdDisplay, Timestamp? bookingDate) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(guestName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        const SizedBox(width: 8),
                        _buildBadge('MEMBER'), // Assuming all guests are members
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(guestEmail, style: const TextStyle(color: Color(0xFF6D797E), fontSize: 14)),
                  ],
                ),
              )
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Request ID: #$bookingIdDisplay', style: const TextStyle(color: Color(0xFF6D797E), fontSize: 12)),
              Text('Received: ${bookingDate != null ? DateFormat('MMM dd, yyyy HH:mm').format(bookingDate.toDate()) : 'N/A'}', style: const TextStyle(color: Color(0xFF6D797E), fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStayDetails(
    DateTime checkInDate, TimeOfDay checkInTime,
    DateTime checkOutDate, TimeOfDay checkOutTime,
    int numberOfAdults, int numberOfChildren,
    int numberOfNights, int numberOfDays,
    bool canEdit,
  ) {
    return _buildSectionCard(
      title: 'Stay Details',
      child: Column(
        children: [
          _buildInfoRow(
            Icons.calendar_today,
            'Check-in',
            '${DateFormat('EEE, MMM dd, yyyy').format(checkInDate)} at ${checkInTime.format(context)}',
            isEditable: false, // Cannot edit dates/times
          ),
          _buildInfoRow(
            Icons.event_busy,
            'Check-out',
            '${DateFormat('EEE, MMM dd, yyyy').format(checkOutDate)} at ${checkOutTime.format(context)}',
            hasBorder: true,
            isEditable: false, // Cannot edit dates/times
          ),
          _buildEditableInfoRow(
            icon: Icons.group,
            label: 'Guests',
            value: '$numberOfAdults Adults, $numberOfChildren Children',
            canEdit: canEdit,
            isEditing: _isEditing,
            controller1: _adultsController,
            label1: 'Adults',
            controller2: _childrenController,
            label2: 'Children',
            hasBorder: true,
          ),
          _buildInfoRow(
            Icons.nights_stay,
            'Duration',
            '$numberOfNights Nights, $numberOfDays Day(s)',
            hasBorder: true,
            isEditable: false, // Cannot edit duration
          ),
        ],
      ),
    );
  }

  Widget _buildRoomChoice(String roomName, String roomImageUrl, String roomFloor, String roomCategory, String roomSize, double totalAmount, int numberOfNights, int numberOfDays, double roomPrice, String roomPriceUnit, List<dynamic> selectedAddons, bool canEdit) {
    return _buildSectionCard(
      title: 'Selected Room',
      trailing: _buildBadge(roomCategory.toUpperCase(), isSmall: true),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              roomImageUrl,
              width: 96,
              height: 96,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 96,
                height: 96,
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
                Text(roomCategory.toUpperCase(), style: TextStyle(color: primaryColor.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                Text(roomName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                Text('Floor $roomFloor • Size: $roomSize', style: const TextStyle(color: Color(0xFF6D797E), fontSize: 13)),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    text: '₱${totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 18, fontFamily: 'Manrope'),
                    children: [
                      TextSpan(text: ' TOTAL ($numberOfNights NIGHTS, $numberOfDays DAY(S))', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.normal, color: Color(0xFF6D797E))),
                    ],
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFinancialSummary(double totalAmount, String status, double roomPrice, int numberOfNights, int numberOfDays, List<dynamic> selectedAddons, String? rejectionReason) {
    final double baseRoomPrice = roomPrice / 2; // Price per unit
    final int totalUnits = (numberOfNights * 2) + numberOfDays;
    final double calculatedRoomPrice = baseRoomPrice * totalUnits;
    final double calculatedAddonsPrice = selectedAddons.fold(0.0, (sum, addon) => sum + (addon['price'] as double? ?? 0.0));
    final double subtotal = calculatedRoomPrice + calculatedAddonsPrice;
    final double taxAmount = subtotal * 0.12; // Assuming 12% tax

    Color statusColor;
    String statusText;
    switch (status) {
      case 'pending':
        statusColor = statusOrange;
        statusText = 'PENDING';
        break;
      case 'approved':
        statusColor = statusGreen;
        statusText = 'APPROVED';
        break;
      case 'rejected':
        statusColor = statusRed;
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

    return _buildSectionCard(
      title: 'Financial Summary',
      trailing: Row(
        children: [
          Container(height: 6, width: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(statusText, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900)),
        ],
      ),
      child: Column(
        children: [
          _buildPriceRow('Room Charge ($numberOfNights nights, $numberOfDays day(s))', '₱${calculatedRoomPrice.toStringAsFixed(2)}'),
          if (selectedAddons.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...selectedAddons.map((addon) => _buildPriceRow('${addon['title']} Add-on', '₱${(addon['price'] as double? ?? 0.0).toStringAsFixed(2)}')).toList(),
          ],
          const SizedBox(height: 12),
          _buildPriceRow('Subtotal', '₱${subtotal.toStringAsFixed(2)}'),
          const SizedBox(height: 12),
          _buildPriceRow('Taxes & Fees (12%)', '₱${taxAmount.toStringAsFixed(2)}'),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: Colors.grey)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text('₱${totalAmount.toStringAsFixed(2)}', style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 20)),
            ],
          ),
          if (rejectionReason != null && status == 'rejected') ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Reason for Rejection: $rejectionReason', style: TextStyle(color: statusRed, fontSize: 13, fontStyle: FontStyle.italic)),
            ),
          ],
        ],
      ),
    );
  }

  // Helper Widgets
  Widget _buildSectionCard({required String title, required Widget child, Widget? trailing}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: primaryColor.withOpacity(0.05), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title.toUpperCase(), style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                if (trailing != null) trailing,
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool hasBorder = false, bool isEditable = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: hasBorder ? Border(top: BorderSide(color: Colors.grey.shade50)) : null),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryColor.withOpacity(0.6), size: 18),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(color: Color(0xFF6D797E), fontSize: 14)),
            ],
          ),
          if (isEditable && _isEditing)
            // Editable text field (e.g., for add-ons, if they become editable in future)
            SizedBox(width: 150, child: TextField(controller: TextEditingController(text: value), textAlign: TextAlign.right, decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero)))
          else
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildEditableInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool canEdit,
    required bool isEditing,
    TextEditingController? controller1,
    String? label1,
    TextEditingController? controller2,
    String? label2,
    bool hasBorder = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: hasBorder ? Border(top: BorderSide(color: Colors.grey.shade50)) : null),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryColor.withOpacity(0.6), size: 18),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(color: Color(0xFF6D797E), fontSize: 14)),
            ],
          ),
          if (canEdit && isEditing) 
            Row(
              children: [
                SizedBox(
                  width: 50,
                  child: TextField(
                    controller: controller1,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      labelText: label1,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 50,
                  child: TextField(
                    controller: controller2,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      labelText: label2,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            )
          else
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String price) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF6D797E), fontSize: 14)),
        Text(price, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }

  Widget _buildBadge(String text, {bool isSmall = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: isSmall ? 2 : 4),
      decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: primaryColor, fontSize: isSmall ? 9 : 10, fontWeight: FontWeight.w900)),
    );
  }
}
