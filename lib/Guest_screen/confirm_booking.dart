import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import for Firestore
import 'booking_summary.dart';
import 'package:intl/intl.dart'; // Import for date formatting

class CheckoutPage extends StatefulWidget {
  final String userEmail;
  final String userRole;
  final String roomName;
  final String roomImageUrl;
  final double roomPrice;
  final String roomPriceUnit;
  final String roomDescription;
  final String roomArea;
  final String roomCapacity;
  final String roomBedType;
  final List<String> roomAmenities;
  final String roomLocation;
  final String roomFloor; // New field
  final String roomCategory; // New field
  final String roomSize; // New field

  const CheckoutPage({
    super.key,
    required this.userEmail,
    required this.userRole,
    required this.roomName,
    required this.roomImageUrl,
    required this.roomPrice,
    required this.roomPriceUnit,
    required this.roomDescription,
    required this.roomArea,
    required this.roomCapacity,
    required this.roomBedType,
    required this.roomAmenities,
    required this.roomLocation,
    required this.roomFloor,
    required this.roomCategory,
    required this.roomSize,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final Color primaryColor = const Color(0xFF2A585A);
  final Color brassColor = const Color(0xFFCBA474);
  final Color bgLight = const Color(0xFFF6F2EF);

  DateTime? _checkInDate;
  TimeOfDay? _selectedCheckInTime; // New: To store selected check-in time
  int _numberOfNights = 1;
  int _numberOfDays = 0; // Represents extra days beyond nights
  int _numberOfAdults = 2; // Default
  int _numberOfChildren = 0; // Default
  final List<Map<String, dynamic>> _selectedAddons = [];

  // Define available addons with their prices
  final List<Map<String, dynamic>> _availableAddons = [
    {'title': 'Private Pool', 'sub': '4-hour reservation', 'price': 645.00, 'icon': Icons.pool, 'isSelected': false},
    {'title': 'Spa Package', 'sub': 'Full body detox', 'price': 1200.00, 'icon': Icons.spa, 'isSelected': false},
    {'title': 'Champagne', 'sub': 'Moët & Chandon', 'price': 885.00, 'icon': Icons.local_bar, 'isSelected': false},
    // Add more addons as needed
  ];

  String? _roomId; // Store room ID for checking availability
  bool _availableForDay = true;
  bool _availableForNight = true;
  Set<String> _maintenanceDates = {}; // Store maintenance dates as strings

  @override
  void initState() {
    super.initState();
    _checkInDate = DateTime.now(); // Set initial check-in date to today
    _selectedCheckInTime = TimeOfDay.now(); // Initialize with current time
    _fetchRoomData();
    _fetchMaintenanceDates();
  }

  Future<void> _fetchMaintenanceDates() async {
    if (_roomId == null) {
      // Wait a bit for room ID to be fetched
      await Future.delayed(const Duration(milliseconds: 500));
      if (_roomId == null) return;
    }

    try {
      final remindersSnapshot = await FirebaseFirestore.instance
          .collection('reminders')
          .where('type', isEqualTo: 'maintenance')
          .where('roomId', isEqualTo: _roomId)
          .get();

      final maintenanceDates = <String>{};
      for (var reminderDoc in remindersSnapshot.docs) {
        final reminder = reminderDoc.data();
        final reminderDate = reminder['date'] as Timestamp?;
        if (reminderDate != null) {
          final dateStr = DateFormat('yyyy-MM-dd').format(reminderDate.toDate());
          maintenanceDates.add(dateStr);
        }
      }
      
      setState(() {
        _maintenanceDates = maintenanceDates;
      });
    } catch (e) {
      print('Error fetching maintenance dates: $e');
    }
  }

  Future<void> _fetchRoomData() async {
    try {
      // Find the room by name to get its ID and availability settings
      final roomsSnapshot = await FirebaseFirestore.instance
          .collection('rooms')
          .where('name', isEqualTo: widget.roomName)
          .limit(1)
          .get();

      if (roomsSnapshot.docs.isNotEmpty) {
        final roomData = roomsSnapshot.docs.first.data();
        final roomId = roomsSnapshot.docs.first.id;
        setState(() {
          _roomId = roomId;
          _availableForDay = roomData['availableForDay'] as bool? ?? true;
          _availableForNight = roomData['availableForNight'] as bool? ?? true;
        });
        
        // Fetch maintenance dates after getting room ID
        await _fetchMaintenanceDates();
      }
    } catch (e) {
      print('Error fetching room data: $e');
    }
  }

  Future<Map<String, bool>> _checkDateAvailability(DateTime date) async {
    // Returns {isDayOccupied: bool, isNightOccupied: bool}
    bool isDayOccupied = false;
    bool isNightOccupied = false;

    if (_roomId == null || widget.roomName.isEmpty) {
      return {'isDayOccupied': false, 'isNightOccupied': false};
    }

    try {
      // Check bookings for this room on this date
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('roomName', isEqualTo: widget.roomName)
          .where('status', isNotEqualTo: 'cancelled')
          .get();

      for (var bookingDoc in bookingsSnapshot.docs) {
        final booking = bookingDoc.data();
        final checkInDateStr = booking['checkInDate'] as String?;

        if (checkInDateStr != null) {
          try {
            final checkInDate = DateTime.parse(checkInDateStr);
            final checkInTime = _parseTimeOfDay(booking['checkInTime'] as String? ?? '00:00');
            final checkOutDate = DateTime.parse(booking['checkOutDate'] as String? ?? checkInDateStr);
            final checkOutTime = _parseTimeOfDay(booking['checkOutTime'] as String? ?? '06:00');

            final bookedInDateTime = DateTime(checkInDate.year, checkInDate.month, checkInDate.day, checkInTime.hour, checkInTime.minute);
            final bookedOutDateTime = DateTime(checkOutDate.year, checkOutDate.month, checkOutDate.day, checkOutTime.hour, checkOutTime.minute);
            
            final selectedDateMidnight = DateTime(date.year, date.month, date.day);
            final selectedDateNextMidnight = selectedDateMidnight.add(const Duration(days: 1));

            // Check if the selected date (whole day) overlaps with the booking
            final isDateInRange = (selectedDateMidnight.isBefore(bookedOutDateTime) && selectedDateNextMidnight.isAfter(bookedInDateTime));
            
            if (isDateInRange) {
              // Determine if the current date is occupied for day (6 AM to 6 PM)
              // and night (6 PM to 6 AM the next day) based on booking times.

              // Day occupancy: overlaps with 6 AM to 6 PM of the 'date'
              final dayStart = selectedDateMidnight.add(const Duration(hours: 6));
              final dayEnd = selectedDateMidnight.add(const Duration(hours: 18));
              final isDayOccupiedByBooking = bookedInDateTime.isBefore(dayEnd) && bookedOutDateTime.isAfter(dayStart);

              // Night occupancy: overlaps with 6 PM of 'date' to 6 AM of 'date + 1 day'
              final nightStart = selectedDateMidnight.add(const Duration(hours: 18));
              final nightEnd = selectedDateNextMidnight.add(const Duration(hours: 6));
              final isNightOccupiedByBooking = bookedInDateTime.isBefore(nightEnd) && bookedOutDateTime.isAfter(nightStart);

              if (isDayOccupiedByBooking) {
                isDayOccupied = true;
              }
              if (isNightOccupiedByBooking) {
                isNightOccupied = true;
              }
            }
          } catch (e) {
            print('Error parsing booking date or time: $e');
          }
        }
      }
    } catch (e) {
      print('Error checking date availability: $e');
    }

    return {'isDayOccupied': isDayOccupied, 'isNightOccupied': isNightOccupied};
  }

  // Helper to calculate total booking units
  int get _totalBookingUnits {
    return (_numberOfNights * 2) + _numberOfDays;
  }

  // Calculate total room price based on half the roomPrice and booking units
  double get _calculatedRoomPrice {
    return (widget.roomPrice / 2) * _totalBookingUnits;
  }

  // Calculate total add-on price
  double get _calculatedAddonsPrice {
    return _selectedAddons.fold(0.0, (sum, addon) => sum + (addon['price'] as double));
  }

  // Calculate total price before tax
  double get _subtotalPrice {
    return _calculatedRoomPrice + _calculatedAddonsPrice;
  }

  // Calculate tax (12%)
  double get _taxAmount {
    return _subtotalPrice * 0.12;
  }

  // Calculate final total price
  double get _totalAmount {
    return _subtotalPrice + _taxAmount;
  }

  // New: Helper to calculate check-out date and time
  Map<String, dynamic> _calculateCheckOutDetails() {
    if (_checkInDate == null || _selectedCheckInTime == null) {
      return {'date': null, 'time': null};
    }

    DateTime checkInDateTime = DateTime(
      _checkInDate!.year,
      _checkInDate!.month,
      _checkInDate!.day,
      _selectedCheckInTime!.hour,
      _selectedCheckInTime!.minute,
    );

    DateTime finalCheckOutDateTime;

    if (_numberOfNights > 0) {
      // If nights are booked, checkout is always 6 AM after the last night.
      // The 'numberOfDays' indicates day-use within the total duration, not extending the checkout date.
      finalCheckOutDateTime = checkInDateTime.add(Duration(days: _numberOfNights));
      finalCheckOutDateTime = DateTime(
        finalCheckOutDateTime.year,
        finalCheckOutDateTime.month,
        finalCheckOutDateTime.day,
        6, // Default 6 AM checkout for night stays
        0,
      );
    } else if (_numberOfDays > 0) {
      // If only days are booked (0 nights), checkout is 6 PM on the last day.
      finalCheckOutDateTime = checkInDateTime.add(Duration(days: _numberOfDays - 1)); // -1 because the first day is 'today'
      finalCheckOutDateTime = DateTime(
        finalCheckOutDateTime.year,
        finalCheckOutDateTime.month,
        finalCheckOutDateTime.day,
        18, // 6 PM checkout for day-only bookings
        0,
      );
    } else {
      // Should not happen if validation prevents 0 nights and 0 days
      return {'date': null, 'time': null};
    }
    return {
      'date': finalCheckOutDateTime,
      'time': TimeOfDay.fromDateTime(finalCheckOutDateTime),
    };
  }

  Future<void> _selectCheckInDate(BuildContext context) async {
    DateTime initialDate = _checkInDate ?? DateTime.now();
    TimeOfDay initialTime = _selectedCheckInTime ?? TimeOfDay.now();

    // Ensure initialDate is not a maintenance date
    if (_maintenanceDates.contains(DateFormat('yyyy-MM-dd').format(initialDate))) {
      // Find the next available date
      DateTime nextAvailableDate = initialDate.add(const Duration(days: 1));
      while (_maintenanceDates.contains(DateFormat('yyyy-MM-dd').format(nextAvailableDate))) {
        nextAvailableDate = nextAvailableDate.add(const Duration(days: 1));
      }
      initialDate = nextAvailableDate;
    }

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      selectableDayPredicate: (DateTime date) {
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        return !_maintenanceDates.contains(dateStr);
      },
    );
    if (pickedDate != null && pickedDate != _checkInDate) {
      if (!mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: initialTime,
      );
      if (pickedTime != null) {
        setState(() {
          _checkInDate = pickedDate;
          _selectedCheckInTime = pickedTime;
          // Reset nights and days when date changes to re-check availability
          _numberOfNights = 1;
          _numberOfDays = 0;
        });
      }
    }
  }

  Future<void> _showNightsAndGuestsModal(BuildContext context) async {
    if (_checkInDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a check-in date first')),
      );
      return;
    }

    // Check availability for the selected date
    final availability = await _checkDateAvailability(_checkInDate!);
    final isDayOccupied = availability['isDayOccupied'] ?? false;
    final isNightOccupied = availability['isNightOccupied'] ?? false;

    // Reset invalid values based on availability
    int tempNights = _numberOfNights;
    int tempDays = _numberOfDays;
    
    // If current selection is invalid, reset to safe defaults
    if ((isNightOccupied || !_availableForNight) && tempNights > 0) {
      tempNights = 0;
    }
    if ((isDayOccupied || !_availableForDay) && tempDays > 0) {
      tempDays = 0;
    }
    
    // If both are 0, set nights to 1 if night is available, otherwise set days to 1 if day is available
    if (tempNights == 0 && tempDays == 0) {
      if (!isNightOccupied && _availableForNight) {
        tempNights = 1;
      } else if (!isDayOccupied && _availableForDay) {
        tempDays = 1;
      }
    }
    
    int tempAdults = _numberOfAdults;
    int tempChildren = _numberOfChildren;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Select Nights and Guests'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Night selection
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Nights:'),
                          if (isNightOccupied || !_availableForNight)
                            Text(
                              isNightOccupied ? 'Night is occupied' : 'Night not available',
                              style: const TextStyle(color: Colors.red, fontSize: 10),
                            ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: (isNightOccupied || !_availableForNight) ? null : () {
                              if (tempNights > 1) {
                                setModalState(() {
                                  tempNights--;
                                });
                              }
                            },
                          ),
                          Text('$tempNights'),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: (isNightOccupied || !_availableForNight) ? null : () {
                              setModalState(() {
                                tempNights++;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Day selection
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Extra Days (beyond nights):'),
                          if (isDayOccupied || !_availableForDay)
                            Text(
                              isDayOccupied ? 'Day is occupied' : 'Day not available',
                              style: const TextStyle(color: Colors.red, fontSize: 10),
                            ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: (isDayOccupied || !_availableForDay) ? null : () {
                              if (tempDays > 0) {
                                setModalState(() {
                                  tempDays--;
                                });
                              }
                            },
                          ),
                          Text('$tempDays'),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: (isDayOccupied || !_availableForDay) ? null : () {
                              setModalState(() {
                                tempDays++;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Adults:'),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () {
                              if (tempAdults > 1) {
                                setModalState(() {
                                  tempAdults--;
                                });
                              }
                            },
                          ),
                          Text('$tempAdults'),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () {
                              setModalState(() {
                                tempAdults++;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Children:'),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () {
                              if (tempChildren > 0) {
                                setModalState(() {
                                  tempChildren--;
                                });
                              }
                            },
                          ),
                          Text('$tempChildren'),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () {
                              setModalState(() {
                                tempChildren++;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Validate that user is not selecting occupied options
                    if (tempNights > 0 && (isNightOccupied || !_availableForNight)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isNightOccupied 
                            ? 'Night booking is not available for the selected date' 
                            : 'Night booking is not available for this room'),
                        ),
                      );
                      return;
                    }
                    if (tempDays > 0 && (isDayOccupied || !_availableForDay)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isDayOccupied 
                            ? 'Day booking is not available for the selected date' 
                            : 'Day booking is not available for this room'),
                        ),
                      );
                      return;
                    }
                    
                    // Validate that at least one night or day is selected
                    if (tempNights == 0 && tempDays == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select at least one night or one extra day'),
                        ),
                      );
                      return;
                    }
                    
                    setState(() {
                      _numberOfNights = tempNights;
                      _numberOfDays = tempDays;
                      _numberOfAdults = tempAdults;
                      _numberOfChildren = tempChildren;
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: bgLight.withOpacity(0.8),
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.white,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: const Text(
          'Checkout',
          style: TextStyle(color: Color(0xFF131616), fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildHeroCard(),
                const SizedBox(height: 32),
                _buildSectionHeader('Stay Details'),
                _buildStayDetailsCard(),
                const SizedBox(height: 32),
                _buildSectionHeader('Enhanced Services', trailing: 'OPTIONAL'),
                _buildAddonsList(),
                const SizedBox(height: 32),
                _buildSectionHeader('Price Breakdown'),
                _buildPriceBreakdown(),
                const SizedBox(height: 140), // Space for sticky footer
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildStickyFooter(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        image: DecorationImage(
          image: NetworkImage(widget.roomImageUrl),
          fit: BoxFit.cover,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: brassColor, borderRadius: BorderRadius.circular(4)),
                  child: const Text('PREMIUM SUITE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                Text(widget.roomName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('TOTAL PRICE', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                Text('₱${_totalAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title.toUpperCase(), style: TextStyle(color: primaryColor.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          if (trailing != null) Text(trailing, style: TextStyle(color: brassColor, fontSize: 10, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildStayDetailsCard() {
    String formattedCheckInDateTime = _checkInDate != null && _selectedCheckInTime != null
        ? '${DateFormat('MMM dd, yyyy').format(_checkInDate!)} at ${_selectedCheckInTime!.format(context)}'
        : 'Select Date and Time';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _selectCheckInDate(context),
            child: _buildStayItem(Icons.calendar_today, 'Check-in Date', formattedCheckInDateTime),
          ),
          const Divider(height: 1, indent: 64),
          GestureDetector(
            onTap: () => _showNightsAndGuestsModal(context),
            child: _buildStayItem(Icons.group_outlined, 'Guests & Duration', '$_numberOfAdults Adults, $_numberOfChildren Children, $_numberOfNights Nights, $_numberOfDays Extra Day(s)'),
          ),
        ],
      ),
    );
  }

  Widget _buildStayItem(IconData icon, String title, String sub) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: primaryColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(sub, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              ],
            ),
          ),
          Icon(Icons.edit_outlined, color: primaryColor, size: 20),
        ],
      ),
    );
  }

  Widget _buildAddonsList() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _availableAddons.map((addon) {
          final bool isSelected = _selectedAddons.any((selected) => selected['title'] == addon['title']);
          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedAddons.removeWhere((selected) => selected['title'] == addon['title']);
                } else {
                  _selectedAddons.add(addon);
                }
              });
            },
            child: _buildAddonCard(
              addon['title'],
              addon['sub'],
              '₱${(addon['price'] as double).toStringAsFixed(2)}',
              addon['icon'],
              isSelected: isSelected,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAddonCard(String title, String sub, String price, IconData icon, {required bool isSelected}) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected ? primaryColor.withOpacity(0.02) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSelected ? primaryColor.withOpacity(0.2) : Colors.transparent, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: isSelected ? primaryColor : brassColor),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('+$price', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Icon(isSelected ? Icons.check_circle : Icons.add_circle, color: isSelected ? primaryColor : brassColor, size: 20),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPriceBreakdown() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _priceRow('${widget.roomName} ($_numberOfNights nights, $_numberOfDays extra day(s))', '₱${(widget.roomPrice / 2).toStringAsFixed(2)} x $_totalBookingUnits units = ₱${_calculatedRoomPrice.toStringAsFixed(2)}'),
          if (_selectedAddons.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._selectedAddons.map((addon) => _priceRow('${addon['title']} Add-on', '₱${(addon['price'] as double).toStringAsFixed(2)}')).toList(),
          ],
          const SizedBox(height: 12),
          _priceRow('Subtotal', '₱${_subtotalPrice.toStringAsFixed(2)}'),
          const SizedBox(height: 12),
          _priceRow('Tourism Tax & VAT (12%)', '₱${_taxAmount.toStringAsFixed(2)}'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Divider(height: 1, color: Color(0xFFE5E7EB)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('₱${_totalAmount.toStringAsFixed(2)}', style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 20)),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'By clicking "Confirm Reservation", you agree to our Terms of Service and Cancellation Policy.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 10),
          )
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Future<void> _confirmReservation() async {
    try {
      // Fetch user's full name from users collection
      String guestName = 'N/A';
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userEmail.toLowerCase())
            .get();
        if (userDoc.exists) {
          guestName = userDoc.data()?['fullName'] ?? 'N/A';
        }
      } catch (e) {
        print('Error fetching user name: $e');
      }

      // Gather all booking data
      final bookingData = {
        'userEmail': widget.userEmail,
        'userRole': widget.userRole,
        'guestName': guestName, // Save guest's full name
        'roomName': widget.roomName,
        'roomImageUrl': widget.roomImageUrl,
        'roomPrice': widget.roomPrice,
        'roomPriceUnit': widget.roomPriceUnit,
        'roomDescription': widget.roomDescription,
        'roomArea': widget.roomArea,
        'roomCapacity': widget.roomCapacity,
        'roomBedType': widget.roomBedType,
        'roomAmenities': widget.roomAmenities,
        'roomLocation': widget.roomLocation,
        'checkInDate': _checkInDate?.toIso8601String(), // Store as ISO 8601 string
        'checkInTime': _selectedCheckInTime?.format(context), // Store check-in time
        'numberOfNights': _numberOfNights,
        'numberOfDays': _numberOfDays,
        'checkOutDate': _calculateCheckOutDetails()['date']?.toIso8601String(), // Store calculated check-out date
        'checkOutTime': _calculateCheckOutDetails()['time']?.format(context), // Store calculated check-out time
        'numberOfAdults': _numberOfAdults,
        'numberOfChildren': _numberOfChildren,
        'selectedAddons': _selectedAddons.map((addon) => {
          'title': addon['title'],
          'sub': addon['sub'],
          'price': addon['price'],
        }).toList(),
        'calculatedRoomPrice': _calculatedRoomPrice,
        'calculatedAddonsPrice': _calculatedAddonsPrice,
        'subtotalPrice': _subtotalPrice,
        'taxAmount': _taxAmount,
        'totalAmount': _totalAmount,
        'bookingDate': DateTime.now().toIso8601String(), // Timestamp of booking
        'status': 'pending', // Default status for new bookings
        'roomCategory': widget.roomCategory, // Save room category
        'roomFloor': widget.roomFloor, // Save room floor
        'roomSize': widget.roomSize, // Save room size
      };

      // Save to Firestore
      await FirebaseFirestore.instance.collection('bookings').add(bookingData);

      // Show success message and navigate to confirmation page
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reservation confirmed successfully!')),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConfirmationPage(
            userEmail: widget.userEmail,
            userRole: widget.userRole,
            roomName: widget.roomName,
            roomImageUrl: widget.roomImageUrl,
            roomPrice: widget.roomPrice,
            roomPriceUnit: widget.roomPriceUnit, // New field
            roomDescription: widget.roomDescription, // New field
            roomArea: widget.roomArea, // New field
            roomCapacity: widget.roomCapacity, // New field
            roomBedType: widget.roomBedType, // New field
            roomAmenities: widget.roomAmenities, // New field
            roomFloor: widget.roomFloor, // Pass from widget
            roomCategory: widget.roomCategory, // Pass from widget
            roomSize: widget.roomSize, // Pass from widget
            checkInDate: _checkInDate!,
            numberOfNights: _numberOfNights,
            numberOfDays: _numberOfDays,
            numberOfAdults: _numberOfAdults,
            numberOfChildren: _numberOfChildren,
            selectedAddons: _selectedAddons,
            totalAmount: _totalAmount,
            roomLocation: widget.roomLocation,
          ),
        ),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error confirming reservation: $e')),
      );
    }
  }

  // New: Helper to parse TimeOfDay from string
  TimeOfDay _parseTimeOfDay(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1].split(' ')[0]); // Handle AM/PM if present
    return TimeOfDay(hour: hour, minute: minute);
  }

  Widget _buildStickyFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TOTAL PRICE', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
              Text('₱${_totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  _confirmReservation(); // Call the new function
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 5,
                  shadowColor: primaryColor.withOpacity(0.4),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Confirm Reservation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}