import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math'; // Import for max function
import 'home.dart';
import 'rooms.dart';
import 'bookings.dart';
import '../../utils/date_time_utils.dart'; // Import date/time utilities
import 'settings.dart';
import 'profile.dart';

class CalendarPage extends StatefulWidget {
  final String userEmail;
  final String userRole;
  const CalendarPage({super.key, required this.userEmail, required this.userRole});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> with WidgetsBindingObserver {
  final Color primaryColor = const Color(0xFF0C5F54);
  final Color bookingRoom = const Color(0xFFCC8573);
  final Color bookingPool = const Color(0xFFA3CCA3);
  final Color bookingMaint = const Color(0xFFF0D599);

  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime.now();
  bool _isMonthView = true;
  final TextEditingController _searchController = TextEditingController();
  
  // Data
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _reminders = [];
  List<Map<String, dynamic>> _rooms = [];
  bool _hasLoaded = false;
  DateTime? _lastLoadTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _checkAndUpdateRoomStatuses(); // Check on init
    // Set up periodic check for room status updates
    Future.delayed(const Duration(seconds: 1), () {
      _checkAndUpdateRoomStatuses();
    });
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
      _checkAndUpdateRoomStatuses();
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only reload once when dependencies change
    if (!_hasLoaded) {
      _hasLoaded = true;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    if (!mounted) return;

    try {
      // Load bookings
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('status', isNotEqualTo: 'cancelled')
          .get();

      if (!mounted) return;

      _bookings = bookingsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      // Load reminders
      final remindersSnapshot = await FirebaseFirestore.instance
          .collection('reminders')
          .get();

      if (!mounted) return;

      _reminders = remindersSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      // Load rooms
      final roomsSnapshot = await FirebaseFirestore.instance
          .collection('rooms')
          .get();

      if (!mounted) return;

      _rooms = roomsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _lastLoadTime = DateTime.now(); // Update last load time
        }); // Update UI with new data
      }
    } catch (e) {
      print('Error loading data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Reload data when page becomes visible (only if data is empty or it's been more than 5 seconds)
    final now = DateTime.now();
    if (_bookings.isEmpty && _reminders.isEmpty && _rooms.isEmpty) {
      // First load or data was cleared
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadData();
        }
      });
    } else if (_lastLoadTime == null || now.difference(_lastLoadTime!).inSeconds > 5) {
      // Reload if it's been more than 5 seconds since last load
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadData();
        }
      });
    }
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Header with View Toggle
              SliverAppBar(
                pinned: true,
                expandedHeight: 180,
                backgroundColor:
                    (theme.appBarTheme.backgroundColor ?? const Color(0xFFFAFAFA))
                        .withOpacity(0.9),
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 60, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat('MMMM yyyy').format(_currentMonth),
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF111817)),
                                ),
                                Text(
                                  '${_calculateOccupancy()}% OCCUPANCY',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: primaryColor, letterSpacing: 1.2),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                _buildCircleBtn(Icons.search, () => _showSearchDialog()),
                                const SizedBox(width: 8),
                                _buildCircleBtn(Icons.tune, () => _showDatePicker()),
                              ],
                            )
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildSegmentedControl(),
                      ],
                    ),
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(50),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildLegendBar(),
                  ),
                ),
              ),

              // Calendar Grid
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _isMonthView ? _buildMonthView() : _buildWeekView(),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Fixed Components
          _buildFAB(),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomNav(),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)],
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: _buildSegmentBtn('Month', _isMonthView, () => setState(() => _isMonthView = true))),
          Expanded(child: _buildSegmentBtn('Week', !_isMonthView, () => setState(() => _isMonthView = false))),
        ],
      ),
    );
  }

  Widget _buildSegmentBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : null,
        ),
        child: Center(
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: active ? primaryColor : Colors.grey.shade500)),
        ),
      ),
    );
  }

  Widget _buildLegendBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(left: 10, right: 10, bottom: 60),
      child: Row(
        children: [
          _buildLegendItem('Rooms', bookingRoom),
          _buildLegendItem('Pool', bookingPool),
          _buildLegendItem('Maint.', bookingMaint),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildMonthView() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startDate = firstDay.subtract(Duration(days: firstDay.weekday - 1));
    final endDate = lastDay.add(Duration(days: 7 - lastDay.weekday));
    
    final days = <DateTime>[];
    for (var date = startDate; date.isBefore(endDate) || date.isAtSameMomentAs(endDate); date = date.add(const Duration(days: 1))) {
      days.add(date);
    }

    return Column(
      children: [
        _buildDayHeader(),
        ...List.generate((days.length / 7).ceil(), (weekIndex) {
          final weekDays = days.skip(weekIndex * 7).take(7).toList();
          return _buildWeekRow(weekDays);
        }),
      ],
    );
  }

  Widget _buildWeekView() {
    final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    final weekDays = List.generate(7, (index) => startOfWeek.add(Duration(days: index)));

    return Column(
      children: [
        _buildDayHeader(),
        _buildWeekRow(weekDays),
      ],
    );
  }

  Widget _buildDayHeader() {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return Container(
      color: const Color(0xFFF9F9F9),
      child: Row(
        children: days.map((day) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(day, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey)),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildWeekRow(List<DateTime> weekDays) {
    return IntrinsicHeight(
      child: Row(
        children: weekDays.map((date) => Expanded(
          child: _buildDayCell(date),
        )).toList(),
      ),
    );
  }

  Widget _buildDayCell(DateTime date) {
    final isToday = date.year == DateTime.now().year && 
                    date.month == DateTime.now().month && 
                    date.day == DateTime.now().day;
    final isCurrentMonth = date.month == _currentMonth.month;
    final dayNumber = date.day;
    final isPast = date.isBefore(DateTime.now().subtract(const Duration(days: 1)));
    
    // Get markings for this date
    final markings = _getMarkingsForDate(date);
    
    return GestureDetector(
      onTap: () => _showDateDetails(date, isPast: isPast),
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade100, width: 0.5),
          color: isToday ? Colors.white : (isCurrentMonth ? Colors.white : Colors.grey.shade50),
          boxShadow: isToday ? [BoxShadow(color: primaryColor.withOpacity(0.1), spreadRadius: -2, blurRadius: 0)] : null,
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dayNumber.toString(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: isToday ? FontWeight.w900 : FontWeight.bold,
                color: isToday ? primaryColor : (isCurrentMonth ? Colors.black : Colors.grey),
              ),
            ),
            const SizedBox(height: 2),
            ...markings.take(2).map((marking) => _buildPill(marking['color'] as Color)),
            if (markings.length > 2)
              Container(
                margin: const EdgeInsets.only(top: 2),
                child: Text(
                  '+${markings.length - 2}',
                  style: const TextStyle(fontSize: 8, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getMarkingsForDate(DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final markings = <Map<String, dynamic>>[];

    // Check bookings (rooms)
    for (var booking in _bookings) {
      final checkInDateStr = booking['checkInDate'] as String?;
      final numberOfNights = booking['numberOfNights'] as int?;
      final numberOfDays = booking['numberOfDays'] as int?;
      final roomCategory = booking['roomCategory'] as String?;
      final roomId = booking['roomId'] as String?;

      if (checkInDateStr != null && numberOfNights != null && numberOfDays != null && roomId != null) {
        final checkInDate = DateTime.parse(checkInDateStr);
        final checkInTimeStr = booking['checkInTime'] as String? ?? '00:00'; // Ensure checkInTimeStr is available
        final checkInTime = parseTimeOfDay(checkInTimeStr);

        final checkOutDate = calculateCheckOutDate(checkInDate, checkInTime, numberOfNights, numberOfDays);
        final checkInDateOnly = DateTime(checkInDate.year, checkInDate.month, checkInDate.day);
        final checkOutDateOnly = DateTime(checkOutDate.year, checkOutDate.month, checkOutDate.day);

        // Mark the date if it's on or after check-in day, and strictly before the check-out day.
        // This handles 1-night stays where the checkout day is not marked as occupied.
        if ((date.isAtSameMomentAs(checkInDateOnly) || date.isAfter(checkInDateOnly)) &&
            date.isBefore(checkOutDateOnly)) {
          // Check if the room is not under maintenance for this date
          final isUnderMaintenance = _reminders.any((reminder) {
            final rDate = reminder['date'] as Timestamp?;
            final rRoomId = reminder['roomId'] as String?;
            final rType = reminder['type'] as String?;

            if (rDate != null && rRoomId != null && rType == 'maintenance') {
              return rRoomId == roomId && DateFormat('yyyy-MM-dd').format(rDate.toDate()) == dateStr;
            }
            return false;
          });

          if (!isUnderMaintenance) {
            if (roomCategory == 'pool') {
              markings.add({'color': bookingPool, 'type': 'pool'});
            } else {
          markings.add({'color': bookingRoom, 'type': 'room'});
            }
            // Do not break here if a room can have both room and pool bookings or other types
          }
        }
      }
    }

    // Check reminders
    for (var reminder in _reminders) {
      final reminderDate = reminder['date'] as Timestamp?;
      if (reminderDate != null) {
        final reminderDateOnly = DateFormat('yyyy-MM-dd').format(reminderDate.toDate());
        if (reminderDateOnly == dateStr) {
          final type = reminder['type'] as String? ?? 'maintenance';
          if (type == 'pool') {
            markings.add({'color': bookingPool, 'type': 'pool'});
          } else {
            markings.add({'color': bookingMaint, 'type': 'maintenance'});
          }
        }
      }
    }

    return markings;
  }

  Widget _buildPill(Color color) {
    return Container(
      height: 6,
      width: double.infinity,
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
    );
  }

  int _calculateOccupancy() {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    final occupiedRoomIds = <String>{};

    for (var booking in _bookings) {
      final checkInDateStr = booking['checkInDate'] as String?;
      final numberOfNights = booking['numberOfNights'] as int?;
      final numberOfDays = booking['numberOfDays'] as int?;
      final roomId = booking['roomId'] as String?;

      if (checkInDateStr != null && numberOfNights != null && numberOfDays != null && roomId != null) {
        final checkInDate = DateTime.parse(checkInDateStr);
        final checkOutDate = checkInDate.add(Duration(days: numberOfNights + numberOfDays));

        if ((todayOnly.isAfter(checkInDate.subtract(const Duration(days: 1))) && todayOnly.isBefore(checkOutDate)) ||
            todayOnly.isAtSameMomentAs(checkInDate) ||
            todayOnly.isAtSameMomentAs(checkOutDate.subtract(const Duration(days: 1)))) {
          occupiedRoomIds.add(roomId);
        }
      }
    }
    
    final totalRooms = _rooms.length;
    if (totalRooms == 0) return 0;
    return ((occupiedRoomIds.length / totalRooms) * 100).round();
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Date'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Enter date (YYYY-MM-DD)',
            prefixIcon: Icon(Icons.calendar_today),
          ),
          onSubmitted: (value) {
            _searchDate(value);
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _searchDate(_searchController.text);
              Navigator.pop(context);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _searchDate(String query) {
    try {
      final date = DateFormat('yyyy-MM-dd').parse(query);
      setState(() {
        _selectedDate = date;
        _currentMonth = DateTime(date.year, date.month, 1);
        _isMonthView = true;
      });
      _searchController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid date format. Use YYYY-MM-DD')),
      );
    }
  }

  void _showDatePicker() {
    showDatePicker(
      context: context,
      initialDate: _currentMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    ).then((date) {
      if (date != null) {
        setState(() {
          _currentMonth = DateTime(date.year, date.month, 1);
          _selectedDate = date;
        });
      }
    });
  }

  Future<void> _showDateDetails(DateTime date, {bool isPast = false}) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    
    // Count available and occupied rooms for this date (Day and Night)
    int occupiedDayRooms = 0;
    int occupiedNightRooms = 0;
    int poolMaintenance = 0;
    
    // Separate rooms by availability (availableForDay and availableForNight)
    final dayRooms = _rooms.where((room) {
      final availableForDay = room['availableForDay'] as bool? ?? false;
      return availableForDay;
    }).toList();
    
    final nightRooms = _rooms.where((room) {
      final availableForNight = room['availableForNight'] as bool? ?? false;
      return availableForNight;
    }).toList();
    
    final totalDayRooms = dayRooms.length;
    final totalNightRooms = nightRooms.length;
    
    // Count occupied day and night rooms from bookings
    for (var booking in _bookings) {
      final checkInDateStr = booking['checkInDate'] as String?;
      final checkInTimeStr = booking['checkInTime'] as String?; // New
      final checkOutDateStr = booking['checkOutDate'] as String?; // New
      final checkOutTimeStr = booking['checkOutTime'] as String?; // New
      final roomName = booking['roomName'] as String?;
      
      if (checkInDateStr != null && checkInTimeStr != null && checkOutDateStr != null && checkOutTimeStr != null && roomName != null) {
        try {
          final checkInDate = DateTime.parse(checkInDateStr);
          final checkInTime = parseTimeOfDay(checkInTimeStr);
          final checkOutDate = DateTime.parse(checkOutDateStr);
          final checkOutTime = parseTimeOfDay(checkOutTimeStr);

          final checkInDateTime = DateTime(checkInDate.year, checkInDate.month, checkInDate.day, checkInTime.hour, checkInTime.minute);
          final checkOutDateTime = DateTime(checkOutDate.year, checkOutDate.month, checkOutDate.day, checkOutTime.hour, checkOutTime.minute);
          
          final selectedDateMidnight = DateTime(date.year, date.month, date.day);
          final selectedDateNextMidnight = selectedDateMidnight.add(const Duration(days: 1));

          // Check if the selected date (whole day) overlaps with the booking
          final isDateInRange = (selectedDateMidnight.isBefore(checkOutDateTime) && selectedDateNextMidnight.isAfter(checkInDateTime));
          
          if (isDateInRange) {
            final room = _rooms.firstWhere(
              (r) => (r['name'] as String? ?? '') == roomName,
              orElse: () => <String, dynamic>{},
            );
            
            if (room.isNotEmpty) {
              final availableForDay = room['availableForDay'] as bool? ?? false;
              final availableForNight = room['availableForNight'] as bool? ?? false;
              
              // Determine if the current date is occupied for day (6 AM to 6 PM)
              // and night (6 PM to 6 AM the next day) based on booking times.

              // Day occupancy: overlaps with 6 AM to 6 PM of the 'date'
              final dayStart = selectedDateMidnight.add(const Duration(hours: 6));
              final dayEnd = selectedDateMidnight.add(const Duration(hours: 18));
              final isDayOccupiedByBooking = checkInDateTime.isBefore(dayEnd) && checkOutDateTime.isAfter(dayStart);

              // Night occupancy: overlaps with 6 PM of 'date' to 6 AM of 'date + 1 day'
              final nightStart = selectedDateMidnight.add(const Duration(hours: 18));
              final nightEnd = selectedDateNextMidnight.add(const Duration(hours: 6));
              final isNightOccupiedByBooking = checkInDateTime.isBefore(nightEnd) && checkOutDateTime.isAfter(nightStart);

              if (availableForDay && isDayOccupiedByBooking) {
                occupiedDayRooms++;
              }
              if (availableForNight && isNightOccupiedByBooking) {
                  occupiedNightRooms++;
                }

            } else {
              // Fallback if room not found (less precise, but covers cases where room data might be missing)
              // We'll assume if a booking exists for the date, it occupies both day and night for simplicity
                occupiedDayRooms++;
                occupiedNightRooms++;
            }
          }
        } catch (e) {
          print('Error parsing booking date or time: $e');
        }
      }
    }
    
    // Get reminders for this date
    final dayReminders = _reminders.where((reminder) {
      final reminderDate = reminder['date'] as Timestamp?;
      if (reminderDate != null) {
        final reminderDateOnly = DateFormat('yyyy-MM-dd').format(reminderDate.toDate());
        return reminderDateOnly == dateStr;
      }
      return false;
    }).toList();

    // Get maintenance reminders and their associated rooms
    final maintenanceReminders = dayReminders.where((r) => r['type'] == 'maintenance' && r['roomId'] != null).toList();
    final maintenanceRoomIds = maintenanceReminders.map((r) => r['roomId'] as String).toList();
    final maintenanceDayRooms = dayRooms.where((room) => maintenanceRoomIds.contains(room['id'])).toList();
    final maintenanceNightRooms = nightRooms.where((room) => maintenanceRoomIds.contains(room['id'])).toList();
    
    // Count pool maintenance
    for (var reminder in dayReminders) {
      if (reminder['type'] == 'pool') {
        poolMaintenance++;
      }
    }
    
    // Check if there are any pools in the rooms collection
    final pools = _rooms.where((room) {
      final category = (room['category'] as String? ?? '').toLowerCase();
      return category == 'pool';
    }).toList();
    
    final hasPools = pools.isNotEmpty;
    
    // Calculate available rooms (excluding maintenance)
    final availableDayRooms = max(0, totalDayRooms - occupiedDayRooms - maintenanceDayRooms.length);
    final availableNightRooms = max(0, totalNightRooms - occupiedNightRooms - maintenanceNightRooms.length);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MMMM d, yyyy').format(date),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Day Availability Section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.wb_sunny, color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Text('DAY AVAILABILITY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMiniStatCard('Available', availableDayRooms.toString(), Colors.green),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMiniStatCard('Occupied', occupiedDayRooms.toString(), Colors.orange),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Night Availability Section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.indigo.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.nightlight_round, color: Colors.indigo, size: 20),
                          SizedBox(width: 8),
                          Text('NIGHT AVAILABILITY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMiniStatCard('Available', availableNightRooms.toString(), Colors.green),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMiniStatCard('Occupied', occupiedNightRooms.toString(), Colors.orange),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildStatCard(
                  'Pool Status', 
                  !hasPools 
                    ? 'No Pool' 
                    : (poolMaintenance > 0 ? 'Maintenance' : 'Available'), 
                  Icons.pool, 
                  !hasPools ? Colors.grey : bookingPool
                ),
                if (maintenanceDayRooms.isNotEmpty || maintenanceNightRooms.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bookingMaint.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: bookingMaint.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.construction, color: bookingMaint, size: 20),
                            const SizedBox(width: 8),
                            const Text('ROOMS UNDER MAINTENANCE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (maintenanceDayRooms.isNotEmpty) ...[
                          const Text('Day Rooms:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: maintenanceDayRooms.map((room) {
                              return Chip(
                                label: Text(
                                  '${room['name'] ?? 'Room'}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                backgroundColor: bookingMaint.withOpacity(0.2),
                                side: BorderSide(color: bookingMaint),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (maintenanceNightRooms.isNotEmpty) ...[
                          const Text('Night Rooms:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: maintenanceNightRooms.map((room) {
                              return Chip(
                                label: Text(
                                  '${room['name'] ?? 'Room'}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                backgroundColor: bookingMaint.withOpacity(0.2),
                                side: BorderSide(color: bookingMaint),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (dayReminders.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text('Reminders:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...dayReminders.map((reminder) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        reminder['type'] == 'pool' ? Icons.pool : Icons.construction,
                        color: reminder['type'] == 'pool' ? bookingPool : bookingMaint,
                      ),
                      title: Text(reminder['title'] ?? 'Reminder'),
                      subtitle: Text(reminder['description'] ?? ''),
                    ),
                  )),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMiniStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  void _showAddReminderDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedType = 'maintenance';
    String? selectedRoomId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Reminder'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Date'),
                  subtitle: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) {
                      setDialogState(() => selectedDate = date);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                    DropdownMenuItem(value: 'pool', child: Text('Pool')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedType = value!;
                      if (selectedType != 'maintenance') {
                        selectedRoomId = null; // Clear room selection if not maintenance
                      }
                    });
                  },
                ),
                if (selectedType == 'maintenance') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRoomId,
                    decoration: const InputDecoration(labelText: 'Select Room'),
                    hint: const Text('Select Room'),
                    items: _rooms.map((room) {
                      return DropdownMenuItem<String>(
                        value: room['id'] as String,
                        child: Text('${room['name'] ?? 'Room'} - ${room['floor'] ?? ''}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedRoomId = value);
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a title')),
                  );
                  return;
                }
                if (selectedType == 'maintenance' && selectedRoomId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a room for maintenance')),
                  );
                  return;
                }
                
                try {
                  // Save reminder to Firebase
                  final reminderData = {
                    'title': titleController.text,
                    'description': descriptionController.text,
                    'date': Timestamp.fromDate(selectedDate),
                    'type': selectedType,
                    'createdAt': FieldValue.serverTimestamp(),
                    'createdBy': widget.userEmail,
                  };
                  
                  if (selectedRoomId != null) {
                    reminderData['roomId'] = selectedRoomId!;
                  }
                  
                  await FirebaseFirestore.instance.collection('reminders').add(reminderData);
                  
                  // If maintenance type and room selected, update room status
                  if (selectedType == 'maintenance' && selectedRoomId != null) {
                    await FirebaseFirestore.instance
                        .collection('rooms')
                        .doc(selectedRoomId)
                        .update({
                      'status': 'Maintenance',
                      'maintenanceDate': Timestamp.fromDate(selectedDate),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                  }
                  
                  if (mounted) {
                    Navigator.pop(context);
                    _loadData();
                    _checkAndUpdateRoomStatuses(); // Check for expired maintenance
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reminder added successfully!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _checkAndUpdateRoomStatuses() async {
    if (!mounted) return; // Add mounted check at the beginning

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    try {
      // Get all maintenance reminders
      final remindersSnapshot = await FirebaseFirestore.instance
          .collection('reminders')
          .where('type', isEqualTo: 'maintenance')
          .get();
      
      for (var reminderDoc in remindersSnapshot.docs) {
        if (!mounted) return; // Add mounted check inside the loop
        final reminder = reminderDoc.data();
        final reminderDate = reminder['date'] as Timestamp?;
        final roomId = reminder['roomId'] as String?;
        
        if (reminderDate != null && roomId != null) {
          final reminderDateOnly = reminderDate.toDate();
          final reminderDateOnlyDay = DateTime(reminderDateOnly.year, reminderDateOnly.month, reminderDateOnly.day);
          
          // If maintenance date has passed, update room back to available
          if (reminderDateOnlyDay.isBefore(today)) {
            final roomDoc = await FirebaseFirestore.instance
                .collection('rooms')
                .doc(roomId)
                .get();
            
            if (!mounted) return; // Add mounted check before state-altering operations
            
            if (roomDoc.exists) {
              final roomData = roomDoc.data()!;
              // Only update if still in maintenance
              if (roomData['status'] == 'Maintenance') {
                await FirebaseFirestore.instance
                    .collection('rooms')
                    .doc(roomId)
                    .update({
                  'status': 'Available',
                  'updatedAt': FieldValue.serverTimestamp(),
                });
              }
            }
            
            // Delete the expired reminder
            await FirebaseFirestore.instance
                .collection('reminders')
                .doc(reminderDoc.id)
                .delete();
          }
        }
      }
      
      // Also check for expired reminders of other types (pool, other) and delete them
      final allRemindersSnapshot = await FirebaseFirestore.instance
          .collection('reminders')
          .get();
      
      for (var reminderDoc in allRemindersSnapshot.docs) {
        if (!mounted) return; // Add mounted check inside the loop
        final reminder = reminderDoc.data();
        final reminderDate = reminder['date'] as Timestamp?;
        
        if (reminderDate != null) {
          final reminderDateOnly = reminderDate.toDate();
          final reminderDateOnlyDay = DateTime(reminderDateOnly.year, reminderDateOnly.month, reminderDateOnly.day);
          
          // If reminder date has passed, delete it
          if (reminderDateOnlyDay.isBefore(today)) {
            await FirebaseFirestore.instance
                .collection('reminders')
                .doc(reminderDoc.id)
                .delete();
          }
        }
      }
      
      // Reload data to reflect changes
      if (mounted) { // Only call _loadData if mounted
        _loadData();
      }
    } catch (e) {
      print('Error checking room statuses: $e');
    }
  }

  Widget _buildFAB() {
    return Positioned(
      right: 24,
      bottom: 100,
      child: FloatingActionButton(
        onPressed: _showAddReminderDialog,
        backgroundColor: primaryColor,
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        child: const Icon(Icons.add, size: 32, color: Colors.white),
      ),
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
          _navItem(Icons.calendar_today, 'Calendar', true),
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
