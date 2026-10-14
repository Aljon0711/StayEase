import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'home.dart';
import 'search.dart';
import 'bookings.dart';
import 'profile.dart';
import 'room_detail.dart';

class FavoritesPage extends StatefulWidget {
  final String userEmail;
  final String userRole;

  const FavoritesPage({super.key, required this.userEmail, required this.userRole});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final Color primaryColor = const Color(0xFF2A585A);
  int currentIndex = 3; // Favorites tab

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F2EF).withOpacity(0.9),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Favorites',
          style: TextStyle(
            color: Color(0xFF131616),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('favorites')
            .where('userEmail', isEqualTo: widget.userEmail)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No favorites yet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Save your favorite rooms to quickly find them here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final docId = docs[index].id;
              final title = data['roomName'] ?? 'Favorite room';
              final imageUrl = data['roomImageUrl'] ??
                  'https://via.placeholder.com/400x300?text=No+Image';
              final price = data['roomPrice']?.toString() ?? '0';
              final priceUnit = data['roomPriceUnit'] ?? 'night';
              final roomId = data['roomId'] as String?;
              final roomType = data['roomType'] as String? ?? 'rooms';

              return _buildFavoriteCard(
                title: title,
                imageUrl: imageUrl,
                price: price,
                priceUnit: priceUnit,
                onTap: () {
                  if (roomId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RoomDetailLoaderPage(
                          userEmail: widget.userEmail,
                          userRole: widget.userRole,
                          itemId: roomId,
                          itemType: roomType,
                        ),
                      ),
                    );
                  }
                },
                onRemove: () async {
                  try {
                    await FirebaseFirestore.instance
                        .collection('favorites')
                        .doc(docId)
                        .delete();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Removed from favorites')),
                    );
                  } catch (_) {}
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildFavoriteCard({
    required String title,
    required String imageUrl,
    required String price,
    required String priceUnit,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                imageUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  color: Colors.grey[300],
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: onRemove,
                        icon: const Icon(Icons.favorite, color: Colors.red),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₱$price / $priceUnit',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
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
            MaterialPageRoute(
              builder: (context) => HomeExploreScreen(
                userEmail: widget.userEmail,
                userRole: widget.userRole,
              ),
            ),
          );
        } else if (i == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SearchResultsPage(
                userEmail: widget.userEmail,
                userRole: widget.userRole,
              ),
            ),
          );
        } else if (i == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookingsDashboardPage(
                userEmail: widget.userEmail,
                userRole: widget.userRole,
              ),
            ),
          );
        } else if (i == 3) {
          // Already on Favorites
        } else if (i == 4) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileSettingsPage(
                userEmail: widget.userEmail,
                userRole: widget.userRole,
              ),
            ),
          );
        }
      },
      selectedItemColor: primaryColor,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Explore'),
        BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
        BottomNavigationBarItem(icon: Icon(Icons.confirmation_number), label: 'Bookings'),
        BottomNavigationBarItem(icon: Icon(Icons.favorite_border), label: 'Favorites'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}
