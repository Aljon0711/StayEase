import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'confirm_booking.dart';

// This is the loader page that fetches data and passes it to RoomDetailContent
class RoomDetailLoaderPage extends StatefulWidget {
  final String userEmail;
  final String userRole;
  final String itemId;
  final String itemType;

  const RoomDetailLoaderPage({
    super.key,
    required this.userEmail,
    required this.userRole,
    required this.itemId,
    required this.itemType,
  });

  @override
  State<RoomDetailLoaderPage> createState() => _RoomDetailLoaderPageState();
}

class _RoomDetailLoaderPageState extends State<RoomDetailLoaderPage> {
  Map<String, dynamic>? _itemData;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isFavorite = false;
  String? _favoriteDocId; // To store the doc ID of the favorite item

  @override
  void initState() {
    super.initState();
    _fetchItemDetails();
  }

  Future<void> _fetchItemDetails() async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection(widget.itemType)
          .doc(widget.itemId)
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        setState(() {
          _itemData = docSnapshot.data() as Map<String, dynamic>;
          _isLoading = false;
        });
        await _checkIfFavorite(); // Check favorite status after fetching item details
      } else {
        setState(() {
          _errorMessage = 'Item not found.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching details: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _checkIfFavorite() async {
    try {
      final favoriteDocs = await FirebaseFirestore.instance
          .collection('favorites')
          .where('userEmail', isEqualTo: widget.userEmail)
          .where('roomId', isEqualTo: widget.itemId)
          .limit(1)
          .get();

      if (!mounted) return;

      if (favoriteDocs.docs.isNotEmpty) {
        setState(() {
          _isFavorite = true;
          _favoriteDocId = favoriteDocs.docs.first.id;
        });
      } else {
        setState(() {
          _isFavorite = false;
          _favoriteDocId = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      print('Error checking favorite status: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    if (_itemData == null) return;

    try {
      if (_isFavorite) {
        // Remove from favorites
        if (_favoriteDocId != null) {
          await FirebaseFirestore.instance
              .collection('favorites')
              .doc(_favoriteDocId)
              .delete();
          if (!mounted) return;
          setState(() {
            _isFavorite = false;
            _favoriteDocId = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Removed from favorites')),
          );
        }
      } else {
        // Add to favorites
        final newDocRef = await FirebaseFirestore.instance.collection('favorites').add({
          'userEmail': widget.userEmail,
          'roomId': widget.itemId,
          'roomType': widget.itemType,
          'roomName': _itemData!['name'] ?? 'Unnamed Room',
          'roomImageUrl': _itemData!['imageUrl'] ?? 'https://via.placeholder.com/400',
          'roomPrice': _itemData!['price']?.toString() ?? '0.0',
          'roomPriceUnit': _itemData!['priceUnit'] ?? 'night',
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (!mounted) return;
        setState(() {
          _isFavorite = true;
          _favoriteDocId = newDocRef.id;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to favorites')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update favorites: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(_errorMessage!)),
      );
    }

    if (_itemData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Not Found')),
        body: const Center(child: Text('Item data is missing.')),
      );
    }

    return RoomDetailContent(
      userEmail: widget.userEmail,
      userRole: widget.userRole,
      name: _itemData!['name'] ?? 'N/A',
      imageUrl: _itemData!['imageUrl'] ?? 'https://via.placeholder.com/400',
      price: double.tryParse(_itemData!['price']?.toString() ?? '0.0') ?? 0.0,
      priceUnit: _itemData!['priceUnit'] ?? 'night',
      description: _itemData!['description'] ?? _itemData!['details'] ?? 'No description available.',
      roomArea: _itemData!['roomArea'] ?? 'N/A',
      capacity: _itemData!['capacity'] ?? 'N/A',
      bedType: _itemData!['bedType'] ?? 'N/A',
      amenities: List<String>.from(_itemData!['amenities'] ?? []),
      location: _itemData!['location'] ?? 'Boracay, Philippines', // New field
      roomFloor: _itemData!['floor'] ?? 'N/A', // Fetch floor
      roomCategory: _itemData!['category'] ?? 'N/A', // Fetch category
      roomSize: _itemData!['size'] ?? 'N/A', // Fetch size
      isFavorite: _isFavorite,
      itemId: widget.itemId,
      itemType: widget.itemType,
      onToggleFavorite: _toggleFavorite,
    );
  }
}

// This is the Stateless Widget that displays the details
class RoomDetailContent extends StatelessWidget {
  final String userEmail;
  final String userRole;
  final String name;
  final String imageUrl;
  final double price;
  final String priceUnit;
  final String description;
  final String roomArea;
  final String capacity;
  final String bedType;
  final List<String> amenities;
  final String location; // New field
  final String roomFloor; // New field
  final String roomCategory; // New field
  final String roomSize; // New field
  final bool isFavorite;
  final String itemId;
  final String itemType;
  final VoidCallback onToggleFavorite;

  const RoomDetailContent({
    super.key,
    required this.userEmail,
    required this.userRole,
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.priceUnit,
    required this.description,
    required this.roomArea,
    required this.capacity,
    required this.bedType,
    required this.amenities,
    required this.location,
    required this.roomFloor,
    required this.roomCategory,
    required this.roomSize,
    required this.isFavorite,
    required this.itemId,
    required this.itemType,
    required this.onToggleFavorite,
  });

  final Color primaryColor = const Color(0xFF2A585A);
  final Color accentGold = const Color(0xFFCBA474);
  final Color bgLight = const Color(0xFFF6F2EF);

  Widget _buildImageWidget(String imageUrl) {
    if (imageUrl.startsWith('data:image')) {
      final String base64String = imageUrl.split(',').last;
      try {
        return Image.memory(
          base64Decode(base64String),
          height: 250,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Image.network(
              "https://via.placeholder.com/400",
              height: 250,
              width: double.infinity,
              fit: BoxFit.cover,
            );
          },
        );
      } catch (e) {
        return Image.network(
          "https://via.placeholder.com/400",
          height: 250,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      }
    } else {
      return Image.network(
        imageUrl,
        height: 250,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.network(
            "https://via.placeholder.com/400",
            height: 250,
            width: double.infinity,
            fit: BoxFit.cover,
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Header Image Gallery
              SliverAppBar(
                expandedHeight: MediaQuery.of(context).size.height * 0.45,
                automaticallyImplyLeading: false,
                backgroundColor: Colors.transparent,
                stretch: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildImageWidget(imageUrl),
                      // Gradient Overlay
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black38,
                              Colors.transparent,
                              Colors.black54,
                            ],
                          ),
                        ),
                      ),
                      // Pagination Dots & Badge - Removed static pagination
                      Positioned(
                        bottom: 40,
                        left: 24,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: accentGold, borderRadius: BorderRadius.circular(20)),
                          child: const Text('STAFF PICK', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content Area
              SliverToBoxAdapter(
                child: Container(
                  transform: Matrix4.translationValues(0, -24, 0),
                  decoration: BoxDecoration(
                    color: bgLight,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeadline(),
                      _buildQuickSpecs(),
                      _buildDescription(),
                      _buildAmenities(),
                      // _buildReviews(), // Removed reviews section
                      // _buildMapSection(), // Removed map section
                      const SizedBox(height: 120), // Padding for sticky footer
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Custom Transparent Top Nav
          _buildTopNav(context),

          // Sticky Booking Bar
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildBookingBar(context),
          ),
        ],
      ),
    );
  }


  Widget _buildTopNav(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: _buildCircleButton(Icons.arrow_back_ios_new),
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: onToggleFavorite,
                  child: _buildCircleButton(isFavorite ? Icons.favorite : Icons.favorite_border),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }

  Widget _buildHeadline() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.1)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₱${price.toStringAsFixed(2)}', style: TextStyle(color: primaryColor, fontSize: 24, fontWeight: FontWeight.w800)),
                  Text('PER ${priceUnit.toUpperCase()}', style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
          // Removed static star rating and reviews
        ],
      ),
    );
  }

  Widget _buildQuickSpecs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          if (roomArea != 'N/A') ...[
            _specItem(Icons.straighten, 'Size', '$roomArea sq ft'),
            const SizedBox(width: 24),
          ],
          if (capacity != 'N/A') ...[
            _specItem(Icons.group_outlined, 'Capacity', '$capacity Adults'),
          const SizedBox(width: 24),
          ],
          if (bedType != 'N/A') ...[
            _specItem(Icons.bed_outlined, 'Bed', bedType),
          const SizedBox(width: 24),
          ],
        ],
      ),
    );
  }

  Widget _specItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        )
      ],
    );
  }

  Widget _buildDescription() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('About this suite', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(description, style: const TextStyle(color: Color(0xFF131616), fontSize: 15, height: 1.6)),
        ],
      ),
    );
  }

  Widget _buildAmenities() {
    if (amenities.isEmpty) {
      return const SizedBox.shrink(); // Hide if no amenities
    }
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Amenities', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              // Removed "View all"
            ],
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2, // Adjust as needed
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: amenities.length,
          itemBuilder: (context, index) {
            return _amenityTile(
                _getAmenityIcon(amenities[index]), amenities[index]);
          },
        ),
      ],
    );
  }

  IconData _getAmenityIcon(String amenity) {
    switch (amenity) {
      case 'Free Wi-Fi':
        return Icons.wifi;
      case 'Air Conditioning':
        return Icons.ac_unit;
      case 'Pool Access':
        return Icons.pool;
      case 'Mini Bar':
        return Icons.local_bar;
      case 'Smart TV':
        return Icons.tv;
      case 'Espresso Machine':
        return Icons.coffee_maker;
      default:
        return Icons.help_outline;
    }
  }

  Widget _amenityTile(IconData icon, String label) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: primaryColor),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // Removed _buildReviews and _ratingBar widgets

  Widget _buildBookingBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('₱${price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  Text(' / $priceUnit', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                ],
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CheckoutPage(
                        userEmail: userEmail,
                        userRole: userRole,
                        roomName: name,
                        roomImageUrl: imageUrl,
                        roomPrice: price,
                        roomPriceUnit: priceUnit,
                        roomDescription: description,
                        roomArea: roomArea,
                        roomCapacity: capacity,
                        roomBedType: bedType,
                        roomAmenities: amenities,
                        roomLocation: location,
                        roomFloor: roomFloor,
                        roomCategory: roomCategory,
                        roomSize: roomSize,
                      ),
                    ),
                  );
                },
                child: Text('Check availability', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, decoration: TextDecoration.underline, fontSize: 12)),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                  MaterialPageRoute(
                    builder: (context) => CheckoutPage(
                      userEmail: userEmail,
                      userRole: userRole,
                      roomName: name,
                      roomImageUrl: imageUrl,
                      roomPrice: price,
                      roomPriceUnit: priceUnit,
                      roomDescription: description,
                      roomArea: roomArea,
                      roomCapacity: capacity,
                      roomBedType: bedType,
                      roomAmenities: amenities,
                      roomLocation: location,
                      roomFloor: roomFloor,
                      roomCategory: roomCategory,
                      roomSize: roomSize,
                    ),
                  ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: const Text('Book Now', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
