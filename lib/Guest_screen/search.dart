import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'room_detail.dart';
import 'home.dart';
import 'profile.dart';
import 'bookings.dart';
import 'favorites.dart';

class SearchResultsPage extends StatefulWidget {
  final String userEmail;
  final String userRole;
  const SearchResultsPage({super.key, required this.userEmail, required this.userRole});

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  int currentIndex = 1; // 1 for Search tab
  String _selectedCategoryFilter = 'All Stays'; // New state variable for filtering

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    final Color greyTextColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    final Color cardColor = isDarkMode ? const Color(0xFF22262A) : Colors.white;
    final Color accentGold = const Color(0xFFCBA474); // Keep gold consistent

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                // 1. Sticky AppBar & Filter Bar
                SliverAppBar(
                  pinned: true,
                  floating: true,
                  backgroundColor: Theme.of(context).appBarTheme.backgroundColor!.withOpacity(0.9),
                  elevation: 0,
                  expandedHeight: 140,
                  toolbarHeight: 70,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Column(
                      children: [
                        const SizedBox(height: 75),
                        _buildFilterBar(primaryColor, isDarkMode),
                      ],
                    ),
                  ),
                  title: _buildAppBarTitle(textColor, greyTextColor),
                  centerTitle: true,
                  automaticallyImplyLeading: false,
                ),

                // 2 & 3. Dynamic Accommodation List from Firestore
                StreamBuilder<QuerySnapshot>(
                  stream: _selectedCategoryFilter == 'All Stays'
                      ? FirebaseFirestore.instance.collection('rooms').snapshots()
                      : FirebaseFirestore.instance
                          .collection('rooms')
                          .where('category', isEqualTo: _selectedCategoryFilter)
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SliverToBoxAdapter(
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return SliverToBoxAdapter(
                        child: Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: textColor))),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Center(child: Text('No rooms found.', style: TextStyle(color: textColor))),
                      );
                    }

                    final docs = snapshot.data!.docs;

                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final data = docs[index].data() as Map<String, dynamic>;
                            final roomName = data['name'] ?? 'Unnamed Room';
                            final price = data['price']?.toString() ?? '0';
                            final imageUrl = data['imageUrl'] ??
                                'https://via.placeholder.com/400x300?text=No+Image';
                            final bedType = data['bedType'] ?? '';
                            final roomArea = data['roomArea'] ?? '';
                            final capacity = data['capacity'] ?? '';

                            final tags = <String>[];
                            if (bedType.isNotEmpty) tags.add(bedType);
                            if (roomArea.isNotEmpty) tags.add('$roomArea sq ft');
                            if (capacity.isNotEmpty) tags.add('$capacity Adults');

                            return Padding(
                              padding: EdgeInsets.only(bottom: index == docs.length - 1 ? 140 : 24),
                              child: _buildStayCard(
                                context: context,
                                title: roomName,
                                price: price,
                                rating: data['roomCategory'] ?? '',
                                imageUrl: imageUrl,
                                tags: tags,
                                accentGold: accentGold,
                                primaryColor: primaryColor,
                                itemId: docs[index].id,
                                itemType: 'rooms',
                                isDarkMode: isDarkMode,
                                textColor: textColor,
                                cardColor: cardColor,
                                greyTextColor: greyTextColor,
                              ),
                            );
                          },
                          childCount: docs.length,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

        ],
      ),
      bottomNavigationBar: _buildBottomNav(context, isDarkMode, primaryColor, greyTextColor),
    );
  }

  Widget _buildAppBarTitle(Color textColor, Color greyTextColor) {
    return Column(
      children: [
        Text(
          'Stays in Boracay',
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          'Oct 12 - 15 • 2 Guests',
          style: TextStyle(color: greyTextColor, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildFilterBar(Color primaryColor, bool isDarkMode) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: _buildCategoryChips(primaryColor, isDarkMode),
      ),
    );
  }

  List<Widget> _buildCategoryChips(Color primaryColor, bool isDarkMode) {
    final categories = ['All Stays', 'Suites', 'Deluxe', 'Pool', 'Standard'];
    return categories.map((category) {
      final bool isActive = _selectedCategoryFilter == category;
      return GestureDetector(
        onTap: () {
          setState(() {
            _selectedCategoryFilter = category;
          });
        },
        child: Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? primaryColor : (isDarkMode ? Colors.grey[800] : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: isActive ? null : Border.all(color: isDarkMode ? Colors.white38 : const Color(0xFFE5E7EB)),
          ),
          child: Text(
            category,
            style: TextStyle(
              color: isActive ? Colors.white : (isDarkMode ? Colors.white70 : Colors.black),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildStayCard({
    required BuildContext context,
    required String title,
    required String price,
    required String rating,
    required String imageUrl,
    required List<String> tags,
    required Color accentGold,
    required Color primaryColor,
    required String itemId,
    required String itemType,
    required bool isDarkMode,
    required Color textColor,
    required Color cardColor,
    required Color greyTextColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: (isDarkMode ? Colors.black : Colors.black).withOpacity(isDarkMode ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(imageUrl, height: 240, width: double.infinity, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) {
                  return Image.network("https://via.placeholder.com/400x300?text=No+Image", height: 240, width: double.infinity, fit: BoxFit.cover);
                }),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: GestureDetector(
                  onTap: () => _addToFavorites(
                    itemId: itemId,
                    itemType: itemType,
                    title: title,
                    imageUrl: imageUrl,
                    price: price,
                  ),
                  child: CircleAvatar(
                    backgroundColor: (isDarkMode ? Colors.black : Colors.white).withOpacity(0.9),
                    radius: 20,
                    child: Icon(Icons.favorite, color: primaryColor, size: 20),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, // Fixed Error
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.star, color: accentGold, size: 14),
                              const SizedBox(width: 4),
                              Text(rating, style: TextStyle(color: accentGold, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₱$price', style: TextStyle(color: primaryColor, fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('PER NIGHT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: greyTextColor)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tags.map((tag) => _buildTag(tag, isDarkMode, textColor)).toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RoomDetailLoaderPage(
                            userEmail: widget.userEmail,
                            userRole: widget.userRole,
                            itemId: itemId,
                            itemType: itemType,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Book Now', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addToFavorites({
    required String itemId,
    required String itemType,
    required String title,
    required String imageUrl,
    required String price,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('favorites').add({
        'userEmail': widget.userEmail,
        'roomId': itemId,
        'roomType': itemType,
        'roomName': title,
        'roomImageUrl': imageUrl,
        'roomPrice': price,
        'roomPriceUnit': 'night',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to favorites')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add to favorites: $e')),
      );
    }
  }

  Widget _buildTag(String label, bool isDarkMode, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[700] : const Color(0xFFF6F2EF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
    );
  }

  Widget _buildBottomNav(BuildContext context, bool isDarkMode, Color primaryColor, Color greyTextColor) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (i) {
        setState(() => currentIndex = i);
        if (i == 0) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => HomeExploreScreen(userEmail: widget.userEmail, userRole: widget.userRole)),
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
        BottomNavigationBarItem(icon: Icon(Icons.confirmation_number), label: "Bookings"),
        BottomNavigationBarItem(icon: Icon(Icons.favorite_border), label: "Favorites"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
      ],
    );
  }
}