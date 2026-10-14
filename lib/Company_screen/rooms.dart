import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_room_screen.dart';
import 'room_model.dart'; // New import for Room class
import 'home.dart';
import 'calendar.dart';
import 'bookings.dart';
import 'settings.dart';
import 'profile.dart';

class InventoryPage extends StatefulWidget {
  final String userEmail;
  final String userRole;
  const InventoryPage({super.key, required this.userEmail, required this.userRole});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Color primaryColor = const Color(0xFF339999);
  final Color statusAvailable = const Color(0xFF33A333);
  final Color statusOccupied = const Color(0xFFD98C2C);
  final Color statusMaintenance = const Color(0xFF99A1AB);

  int _selectedTabIndex = 0; // Track selected tab

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);
    // Check and update room statuses when page loads
    _checkAndUpdateRoomStatuses();
  }

  void _handleTabChange() {
    if (mounted && _selectedTabIndex != _tabController.index) {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    }
  }
  
  Future<void> _checkAndUpdateRoomStatuses() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    try {
      // Get all maintenance reminders
      final remindersSnapshot = await FirebaseFirestore.instance
          .collection('reminders')
          .where('type', isEqualTo: 'maintenance')
          .get();
      
      for (var reminderDoc in remindersSnapshot.docs) {
        final reminder = reminderDoc.data();
        final reminderDate = reminder['date'] as Timestamp?;
        final roomId = reminder['roomId'] as String?;
        
        if (reminderDate != null && roomId != null) {
          final reminderDateOnly = reminderDate.toDate();
          final reminderDateOnlyDay = DateTime(reminderDateOnly.year, reminderDateOnly.month, reminderDateOnly.day);
          
          // If maintenance date has passed
          if (reminderDateOnlyDay.isBefore(today)) {
            // Update room status back to available
            final roomDoc = await FirebaseFirestore.instance
                .collection('rooms')
                .doc(roomId)
                .get();
            
            if (roomDoc.exists) {
              final roomData = roomDoc.data()!;
              // Only update if still in maintenance
              if (roomData['status'] == 'Maintenance' || roomData['status'] == 'Under Maintenance') {
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
    } catch (e) {
      print('Error checking room statuses: $e');
    }
  }
  
  List<Room> _getFilteredRooms(List<Room> allRooms, int tabIndex) {
    if (tabIndex == 0) {
      // All Rooms
      return allRooms;
    } else if (tabIndex == 1) {
      // Suites
      return allRooms.where((room) {
        final category = room.category?.toLowerCase() ?? '';
        final name = room.name.toLowerCase();
        return category == 'suites' || name.contains('suite') || name.contains('suites');
      }).toList();
    } else if (tabIndex == 2) {
      // Deluxe
      return allRooms.where((room) {
        final category = room.category?.toLowerCase() ?? '';
        final name = room.name.toLowerCase();
        return category == 'deluxe' || name.contains('deluxe');
      }).toList();
    } else if (tabIndex == 3) {
      // Standard
      return allRooms.where((room) {
        final category = room.category?.toLowerCase() ?? '';
        final name = room.name.toLowerCase();
        return category == 'standard' || name.contains('standard');
      }).toList();
    }
    return allRooms;
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AddRoomScreen()));
        },
        backgroundColor: primaryColor,
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50),
          side: const BorderSide(color: Colors.white, width: 4),
        ),
        child: const Icon(Icons.add, size: 32, color: Colors.white),
      ),
      // To offset the FAB from the bottom nav
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // 1. iOS Style Navigation Bar
              SliverAppBar(
                pinned: true,
                backgroundColor: (theme.appBarTheme.backgroundColor ??
                        const Color(0xFFF9F9FA))
                    .withOpacity(0.8),
                elevation: 0,
                centerTitle: false,
                title: Row(
                  children: [
                    Icon(Icons.analytics_outlined, color: primaryColor, size: 28),
                    const SizedBox(width: 8),
                    const Text('Inventory', 
                      style: TextStyle(color: Color(0xFF121616), fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
                actions: [
                  _buildRoundIconButton(Icons.tune),
                  const SizedBox(width: 16),
                ],
              ),

              // 2. Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: const TextField(
                      decoration: InputDecoration(
                        hintText: 'Search room, floor, or status...',
                        hintStyle: TextStyle(color: Color(0xFF6A8181)),
                        prefixIcon: Icon(Icons.search, color: Color(0xFF6A8181)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Category Tabs
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFDDE3E3))),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorColor: primaryColor,
                    indicatorWeight: 3,
                    labelColor: primaryColor,
                    unselectedLabelColor: const Color(0xFF6A8181),
                    labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    tabs: const [
                      Tab(text: 'All Rooms'),
                      Tab(text: 'Suites'),
                      Tab(text: 'Deluxe'),
                      Tab(text: 'Standard'),
                    ],
                  ),
                ),
              ),

              // 4. Room List
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                sliver: StreamBuilder<QuerySnapshot>(
                  key: const ValueKey('rooms_stream'),
                  stream: FirebaseFirestore.instance.collection('rooms').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Center(
                            child: Text(
                              'Error: ${snapshot.error}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(
                            child: Text(
                              'No rooms found.',
                              style: TextStyle(color: Color(0xFF6A8181)),
                            ),
                          ),
                        ),
                      );
                    }

                    // Build rooms list from snapshot
                    final allRooms = snapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return Room(
                        name: data['name']?.toString() ?? '',
                        category: data['category']?.toString(),
                        floor: data['floor']?.toString() ?? '',
                        size: data['bedType']?.toString() ?? 'N/A',
                        price: data['price']?.toString() ?? '',
                        priceUnit: data['priceUnit']?.toString() ?? 'night',
                        status: data['status']?.toString() ?? 'Available',
                        imageUrl: data['imageUrl']?.toString() ?? '',
                        details: data['details']?.toString(),
                      );
                    }).toList();

                    // Filter rooms based on selected tab
                    final filteredRooms = _getFilteredRooms(allRooms, _selectedTabIndex);

                    if (filteredRooms.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Center(
                            child: Text(
                              'No ${_getTabName(_selectedTabIndex)} found.',
                              style: const TextStyle(color: Color(0xFF6A8181)),
                            ),
                          ),
                        ),
                      );
                    }

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index >= filteredRooms.length) return const SizedBox.shrink();
                          final room = filteredRooms[index];
                          Color statusColor;
                          switch (room.status) {
                            case 'Available':
                              statusColor = statusAvailable;
                              break;
                            case 'Occupied':
                              statusColor = statusOccupied;
                              break;
                            case 'Under Maintenance':
                            case 'Maintenance':
                              statusColor = statusMaintenance;
                              break;
                            default:
                              statusColor = Colors.grey;
                          }
                          return _buildRoomItem(
                            key: ValueKey('room_${index}_${room.name}_${room.floor}'),
                            name: room.name.isEmpty ? 'Unnamed Room' : room.name,
                            sub: 'Floor ${room.floor.isEmpty ? 'N/A' : room.floor} • ${room.size} • ₱${room.price.isEmpty ? '0' : room.price}/${room.priceUnit}',
                            status: room.status,
                            statusColor: statusColor,
                            imgUrl: room.imageUrl,
                          );
                        },
                        childCount: filteredRooms.length,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // 5. Fixed Bottom Navigation
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: theme.bottomNavigationBarTheme.backgroundColor ??
            (isDark ? const Color(0xFF22262A) : Colors.white),
        elevation: 10.0,
        child: _buildBottomNav(),
      ),
    );
  }

  Widget _buildRoundIconButton(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFDDE3E3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Icon(icon, color: const Color(0xFF121616), size: 20),
    );
  }

  Widget _buildRoomItem({Key? key, required String name, required String sub, required String status, required Color statusColor, required String imgUrl}) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE3E3).withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imgUrl.isNotEmpty
                ? Image.network(
                    imgUrl,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 64,
                        height: 64,
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 64,
                        height: 64,
                        color: Colors.grey[300],
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                  )
                : Container(
                    width: 64,
                    height: 64,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image, color: Colors.grey),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF121616))),
                const SizedBox(height: 4),
                Text(sub, style: const TextStyle(fontSize: 12, color: Color(0xFF6A8181))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(status.toUpperCase(), 
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  ],
                )
              ],
            ),
          ),
          const Icon(Icons.more_vert, color: Color(0xFF6A8181)),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: theme.bottomNavigationBarTheme.backgroundColor ??
            (isDark ? const Color(0xFF22262A) : Colors.white),
        // Removed top border as BottomAppBar already has elevation/shadow
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
          _navItem(Icons.bed_outlined, 'Rooms', true),
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
  
  String _getTabName(int index) {
    switch (index) {
      case 0:
        return 'rooms';
      case 1:
        return 'Suites';
      case 2:
        return 'Deluxe';
      case 3:
        return 'Standard';
      default:
        return 'rooms';
    }
  }
}