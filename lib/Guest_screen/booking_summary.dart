import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import for date formatting
import 'bookings.dart';
import 'search.dart';

class ConfirmationPage extends StatelessWidget {
  final String userEmail;
  final String userRole;
  final String roomName;
  final String roomImageUrl;
  final double roomPrice;
  final String roomPriceUnit; // New field
  final String roomDescription; // New field
  final String roomArea; // New field
  final String roomCapacity; // New field
  final String roomBedType; // New field
  final List<String> roomAmenities; // New field
  final String roomFloor; // New field
  final String roomCategory; // New field
  final String roomSize; // New field
  final DateTime checkInDate;
  final int numberOfNights;
  final int numberOfDays;
  final int numberOfAdults;
  final int numberOfChildren;
  final List<Map<String, dynamic>> selectedAddons;
  final double totalAmount;
  final String roomLocation;

  const ConfirmationPage({
    super.key,
    required this.userEmail,
    required this.userRole,
    required this.roomName,
    required this.roomImageUrl,
    required this.roomPrice,
    required this.roomPriceUnit, // New field
    required this.roomDescription, // New field
    required this.roomArea, // New field
    required this.roomCapacity, // New field
    required this.roomBedType, // New field
    required this.roomAmenities, // New field
    required this.roomFloor, // New field
    required this.roomCategory, // New field
    required this.roomSize, // New field
    required this.checkInDate,
    required this.numberOfNights,
    required this.numberOfDays,
    required this.numberOfAdults,
    required this.numberOfChildren,
    required this.selectedAddons,
    required this.totalAmount,
    required this.roomLocation,
  });

  final Color primaryColor = const Color(0xFF2A585A);
  final Color accentGold = const Color(0xFFCBA474);
  final Color bgLight = const Color(0xFFF6F2EF);

  Widget _buildSectionHeader(String title, {String? trailing, bool withPadding = true}) {
    return Padding(
      padding: withPadding ? const EdgeInsets.only(left: 4, bottom: 12) : EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title.toUpperCase(), style: TextStyle(color: primaryColor.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          if (trailing != null) Text(trailing, style: TextStyle(color: accentGold, fontSize: 10, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Navigation
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF2A585A)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Confirmation',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2A585A),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => SearchResultsPage(userEmail: userEmail, userRole: userRole)),
                      );
                    },
                    child: Text(
                      'Done',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    // 2. Success Status
                    _buildSuccessHeader(),
                    const SizedBox(height: 32),
                    // 3. Booking Card
                    _buildBookingCard(),
                    const SizedBox(height: 24),
                    // 4. Location Hint
                    _buildLocationHint(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // 5. Actions (Pinned to bottom)
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: primaryColor.withOpacity(0.2)),
          ),
          child: Icon(Icons.check_circle_outline, color: primaryColor, size: 48),
        ),
        const SizedBox(height: 24),
        Text(
          'Reservation Confirmed',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: primaryColor,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(color: primaryColor.withOpacity(0.7), fontSize: 16, height: 1.5, fontFamily: 'Manrope'),
              children: [
                const TextSpan(text: 'Your stay at '),
                TextSpan(
                  text: roomName,
                  style: TextStyle(color: accentGold, fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: ' is confirmed. We look forward to hosting you.'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBookingCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 30,
            offset: const Offset(0, 10),
          )
        ],
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RESERVATION REFERENCE',
                    style: TextStyle(color: accentGold, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    roomName,
                    style: TextStyle(color: primaryColor, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  roomImageUrl,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              )
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(height: 1),
          ),
          _buildDetailRow(Icons.bed_outlined, 'ROOM TYPE', roomName),
          if (roomFloor != 'N/A') ...[
            const SizedBox(height: 20),
            _buildDetailRow(Icons.layers_outlined, 'FLOOR', roomFloor),
          ],
          if (roomCategory != 'N/A') ...[
            const SizedBox(height: 20),
            _buildDetailRow(Icons.category_outlined, 'CATEGORY', roomCategory),
          ],
          if (roomSize != 'N/A') ...[
            const SizedBox(height: 20),
            _buildDetailRow(Icons.square_foot, 'SIZE', roomSize),
          ],
          if (roomArea != 'N/A') ...[
            const SizedBox(height: 20),
            _buildDetailRow(Icons.straighten, 'ROOM AREA', '$roomArea sq ft'),
          ],
          if (roomCapacity != 'N/A') ...[
            const SizedBox(height: 20),
            _buildDetailRow(Icons.group_outlined, 'CAPACITY', '$roomCapacity Adults'),
          ],
          if (roomBedType != 'N/A') ...[
            const SizedBox(height: 20),
            _buildDetailRow(Icons.king_bed_outlined, 'BED TYPE', roomBedType),
          ],
          if (roomAmenities.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildDetailRow(Icons.wb_sunny_outlined, 'AMENITIES', roomAmenities.join(', ')),
          ],
          const SizedBox(height: 20),
          _buildDetailRow(
            Icons.calendar_today_outlined,
            'CHECK-IN & OUT',
            DateFormat('MMM dd, yyyy').format(checkInDate),
            extra: '$numberOfNights Nights, $numberOfDays Extra Day(s)',
          ),
          const SizedBox(height: 20),
          _buildDetailRow(Icons.group_outlined, 'GUESTS', '$numberOfAdults Adults, $numberOfChildren Children'),
          if (selectedAddons.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildSectionHeader('Enhanced Services', trailing: 'SELECTED', withPadding: false),
            ...selectedAddons.map((addon) => _buildDetailRow(addon['icon'], addon['title'], '₱${(addon['price'] as double).toStringAsFixed(2)}')).toList(),
          ],
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.only(top: 20),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: primaryColor.withOpacity(0.1), style: BorderStyle.none)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Price', style: TextStyle(color: primaryColor.withOpacity(0.7), fontWeight: FontWeight.w500)),
                Text('₱${totalAmount.toStringAsFixed(2)}', style: TextStyle(color: primaryColor, fontSize: 22, fontWeight: FontWeight.w900)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {String? extra}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: primaryColor.withOpacity(0.5), size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: primaryColor.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(color: primaryColor, fontWeight: FontWeight.w700, fontSize: 15)),
            if (extra != null)
              Text(extra, style: TextStyle(color: accentGold, fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        )
      ],
    );
  }

  Widget _buildLocationHint() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on, color: primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ADDRESS', style: TextStyle(color: primaryColor.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                Text(roomLocation, style: const TextStyle(color: Color(0xFF2A585A), fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRCfGwZ7XHERdn_3uv_Koh-cDCMV3WsXrGlhp-xKNyjKQ&s',
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 48,
                  height: 48,
                  color: primaryColor.withOpacity(0.08),
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 48,
                  height: 48,
                  color: primaryColor.withOpacity(0.08),
                  alignment: Alignment.center,
                  child: Icon(Icons.location_on, color: primaryColor.withOpacity(0.6), size: 24),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => BookingsDashboardPage(userEmail: userEmail, userRole: userRole)),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                shadowColor: primaryColor.withOpacity(0.4),
              ),
              child: const Text('View My Bookings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.event),
              label: const Text('Add to Calendar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: BorderSide(color: primaryColor.withOpacity(0.1), width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          RichText(
            text: TextSpan(
              style: TextStyle(color: primaryColor.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w600),
              children: [
                const TextSpan(text: 'Need help? '),
                TextSpan(
                  text: 'Contact Guest Services',
                  style: TextStyle(color: accentGold, decoration: TextDecoration.underline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}