import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'home.dart';
import 'rooms.dart';
import 'calendar.dart';
import 'bookings.dart';
import 'profile.dart';

// Conditional imports for map helper
import 'map_helper_stub.dart' if (dart.library.html) 'map_helper_web.dart';

// Google Maps is only available on mobile, not web
// We'll use static maps for web instead

class PropertyDetailsPage extends StatefulWidget {
  final String userEmail;
  final String userRole;
  const PropertyDetailsPage({super.key, required this.userEmail, required this.userRole});

  @override
  State<PropertyDetailsPage> createState() => _PropertyDetailsPageState();
}

class _PropertyDetailsPageState extends State<PropertyDetailsPage> {
  int currentIndex = 4; // 4 for Settings tab
  final Color primaryColor = const Color(0xFF2D8684);
  
  // Form controllers
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cancellationController = TextEditingController();
  
  // Map variables
  dynamic _mapController; // Use dynamic for web compatibility
  double _latitude = 47.3769; // Default: Zurich, Switzerland
  double _longitude = 8.5417;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cancellationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('property_settings')
          .doc('main')
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _phoneController.text = data['phone'] ?? '+41 44 211 55 00';
          _emailController.text = data['email'] ?? 'admin@grandplaza-zurich.com';
          _addressController.text = data['address'] ?? 'Bahnhofstrasse 31, 8001 Zürich, Switzerland';
          _cancellationController.text = data['cancellationPolicy'] ?? 'Free cancellation up to 48 hours before check-in. Late cancellations or no-shows incur a 1-night penalty.';
          
          if (data['latitude'] != null && data['longitude'] != null) {
            _latitude = data['latitude'];
            _longitude = data['longitude'];
          }
        });
      } else {
        // Set default values
        _cancellationController.text = 'Free cancellation up to 48 hours before check-in. Late cancellations or no-shows incur a 1-night penalty.';
      }
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    
    try {
      // Save to Firebase - creates 'property_settings' collection if it doesn't exist
      // Use set() without merge to replace entire document and remove old fields
      await FirebaseFirestore.instance
          .collection('property_settings')
          .doc('main')
          .set({
        'phone': _phoneController.text,
        'email': _emailController.text,
        'address': _addressController.text,
        'cancellationPolicy': _cancellationController.text,
        'latitude': _latitude,
        'longitude': _longitude,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': widget.userEmail,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _updateLocation(double lat, double lng) {
    setState(() {
      _latitude = lat;
      _longitude = lng;
    });
    // Only update camera on mobile (Google Maps not available on web)
    if (!kIsWeb) {
      _updateMobileMapCamera(lat, lng);
    }
  }

  void _updateMobileMapCamera(double lat, double lng) {
    // This will only be called on mobile where Google Maps is available
    if (kIsWeb) return;
    // Mobile map camera update will be handled by the map widget itself
    // For now, just update the coordinates
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            (theme.appBarTheme.backgroundColor ?? Colors.white).withOpacity(0.8),
        elevation: 0,
        scrolledUnderElevation: 1,
        automaticallyImplyLeading: false,
        title: const Text(
          'Property Details',
          style: TextStyle(color: Color(0xFF101818), fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveSettings,
            child: Text('SAVE', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(Icons.location_on, 'Hotel Location'),
                _buildLocationCard(),
                const SizedBox(height: 24),
                _buildSectionHeader(Icons.contact_support, 'Contact Information'),
                _buildContactForm(),
                const SizedBox(height: 24),
                _buildSectionHeader(Icons.gavel, 'Policy Management'),
                _buildPolicyCard(),
                const SizedBox(height: 32),
                _buildDangerZone(),
              ],
            ),
          ),
          _buildFloatingSaveButton(),
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
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PendingRequestsPage(userEmail: widget.userEmail, userRole: widget.userRole)),
              );
            },
            child: _navItem(Icons.confirmation_number, 'Booking', false),
          ),
          _navItem(Icons.settings, 'Settings', true),
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

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: primaryColor, size: 20),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          // Search button above the map
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showExpandedMapWithSearch,
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Search Location'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
          // Map
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 200,
                width: double.infinity,
                child: kIsWeb ? _buildWebMap() : _buildMobileMap(),
              ),
            ),
          ),
          const Divider(height: 1),
          // Coordinates
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('COORDINATES', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                      Text(
                        '${_latitude.toStringAsFixed(4)}° N, ${_longitude.toStringAsFixed(4)}° E',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildWebMap() {
    if (!kIsWeb) {
      return _buildMobileMap();
    }
    
    // Create a unique ID for this map instance using timestamp to avoid conflicts
    final String mapId = 'leaflet_map_${DateTime.now().millisecondsSinceEpoch}';
    
    // Register Leaflet map view factory (web only) with location update callback
    try {
      final String htmlContent = createLeafletMapHtml(_latitude, _longitude);
      registerMapView(mapId, htmlContent, (lat, lng) {
        if (mounted) {
          setState(() {
            _latitude = lat;
            _longitude = lng;
          });
        }
      });
    } catch (e) {
      print('Error registering map view: $e');
    }
    
    return SizedBox(
      width: double.infinity,
      height: 200,
      child: _buildMapView(mapId),
    );
  }
  
  Widget _buildLeafletFullScreenMap({bool enableSearch = false}) {
    if (!kIsWeb) {
      return _buildMobileFullScreenMap();
    }
    
    // Use unique timestamp for full screen map
    final String mapId = 'leaflet_fullscreen_${DateTime.now().millisecondsSinceEpoch}';
    
    try {
      final String htmlContent = createLeafletMapHtml(_latitude, _longitude);
      registerMapView(mapId, htmlContent, (lat, lng) {
        if (mounted) {
          setState(() {
            _latitude = lat;
            _longitude = lng;
          });
        }
      });
    } catch (e) {
      print('Error registering full screen map view: $e');
    }
    
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: _buildMapView(mapId),
    );
  }
  
  void _showExpandedMapWithSearch() {
    final TextEditingController searchController = TextEditingController();
    final FocusNode searchFocusNode = FocusNode();
    List<Map<String, dynamic>> searchSuggestions = [];
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // Header with search
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Search Location',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Stack(
                        children: [
                          TextField(
                            controller: searchController,
                            focusNode: searchFocusNode,
                            style: const TextStyle(color: Colors.white),
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: 'Search address or place...',
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                              prefixIcon: const Icon(Icons.search, color: Colors.white),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.2),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onChanged: (value) async {
                              if (value.length >= 3) {
                                final suggestions = await _getSearchSuggestions(value);
                                setDialogState(() {
                                  searchSuggestions = suggestions;
                                });
                              } else {
                                setDialogState(() {
                                  searchSuggestions = [];
                                });
                              }
                            },
                            onSubmitted: (value) {
                              if (value.isNotEmpty) {
                                _searchLocation(value);
                                Navigator.pop(context);
                              }
                            },
                          ),
                          // Suggestions dropdown
                          if (searchSuggestions.isNotEmpty)
                            Positioned(
                              top: 50,
                              left: 0,
                              right: 0,
                              child: Material(
                                elevation: 4,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  constraints: const BoxConstraints(maxHeight: 200),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: searchSuggestions.length > 5 ? 5 : searchSuggestions.length,
                                    itemBuilder: (context, index) {
                                      final suggestion = searchSuggestions[index];
                                      return ListTile(
                                        leading: const Icon(Icons.location_on, color: Colors.grey),
                                        title: Text(
                                          suggestion['display_name'] ?? '',
                                          style: const TextStyle(fontSize: 14),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        onTap: () {
                                          final lat = double.parse(suggestion['lat']);
                                          final lng = double.parse(suggestion['lon']);
                                          _updateLocation(lat, lng);
                                          Navigator.pop(context);
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Map area
                Expanded(
                  child: _buildLeafletFullScreenMap(enableSearch: true),
                ),
                // Controls
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[300],
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Confirm'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    
    // Auto focus the search field
    Future.delayed(const Duration(milliseconds: 100), () {
      searchFocusNode.requestFocus();
    });
  }
  
  Future<List<Map<String, dynamic>>> _getSearchSuggestions(String query) async {
    if (query.isEmpty || query.length < 3) return [];
    
    try {
      final String encodedQuery = Uri.encodeComponent(query);
      final String url = 'https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&limit=5';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'StayEase Hotel App'},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => {
          'display_name': item['display_name'] ?? '',
          'lat': item['lat'] ?? '',
          'lon': item['lon'] ?? '',
        }).toList();
      }
    } catch (e) {
      print('Error getting suggestions: $e');
    }
    
    return [];
  }
  
  Widget _buildMobileFullScreenMap() {
    // For mobile, show a simple map preview
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.grey[300],
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map, size: 80, color: primaryColor),
                const SizedBox(height: 16),
                Text(
                  '${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)}',
                  style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use Search to find a location',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildMapView(String viewType) {
    if (kIsWeb) {
      // ignore: undefined_prefixed_name
      return HtmlElementView(viewType: viewType);
    } else {
      return Container(
        color: Colors.grey[300],
        child: Center(
          child: Icon(Icons.map, size: 50, color: primaryColor),
        ),
      );
    }
  }

  Widget _buildMobileMap() {
    // For mobile, also use Leaflet via webview or iframe
    // Since we're using the same approach, create an iframe for mobile too
    if (kIsWeb) {
      return _buildWebMap();
    }
    
    // For mobile (non-web), use a webview with Leaflet
    // For now, use a simple static map preview that works on mobile
    // In a real app, you'd use webview_flutter or google_maps_flutter
    return GestureDetector(
      onTap: _showFullScreenMap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Use a simple tile-based map image
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[300],
            ),
            child: Image.network(
              'https://tile.openstreetmap.org/15/${((_longitude + 180) / 360 * 32768).floor()}/${((1 - (0.5 * math.log(1 + math.tan(45.0 * _latitude * math.pi / 180.0)) / math.pi)) / 2 * 32768).floor()}.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[300],
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map, size: 50, color: primaryColor),
                        const SizedBox(height: 8),
                        Text(
                          '${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)}',
                          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(color: Colors.black12),
          CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(Icons.location_searching, color: primaryColor),
          ),
        ],
      ),
    );
  }

  void _showMapSearchDialog() {
    final TextEditingController searchController = TextEditingController();
    final TextEditingController latController = TextEditingController(text: _latitude.toStringAsFixed(6));
    final TextEditingController lngController = TextEditingController(text: _longitude.toStringAsFixed(6));
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Location'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  labelText: 'Search address or place',
                  hintText: 'e.g., Manila, Philippines',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                onSubmitted: (value) {
                  _searchLocation(value);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Or enter coordinates:',
                style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: latController,
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        hintText: 'e.g., 14.5995',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: lngController,
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        hintText: 'e.g., 120.9842',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (searchController.text.isNotEmpty) {
                _searchLocation(searchController.text);
              } else {
                final lat = double.tryParse(latController.text);
                final lng = double.tryParse(lngController.text);
                if (lat != null && lng != null && 
                    lat >= -90 && lat <= 90 && 
                    lng >= -180 && lng <= 180) {
                  _updateLocation(lat, lng);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid coordinates')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            child: const Text('Search/Update', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Use Google Geocoding API to search for location
      // Note: You need to add your Google Maps API Key
      // For now, using a free alternative approach with Nominatim (OpenStreetMap)
      final String encodedQuery = Uri.encodeComponent(query);
      
      // Using Nominatim (OpenStreetMap) - free, no API key needed
      final String url = 'https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&limit=1';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'StayEase Hotel App'}, // Required by Nominatim
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        if (data.isNotEmpty) {
          final location = data[0];
          final double lat = double.parse(location['lat']);
          final double lng = double.parse(location['lon']);
          final String displayName = location['display_name'] ?? query;
          
          // Update location
          _updateLocation(lat, lng);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Found: $displayName'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Location not found: $query'),
                backgroundColor: Colors.orange,
                action: SnackBarAction(
                  label: 'Use Coordinates',
                  textColor: Colors.white,
                  onPressed: () {
                    _showLocationPicker();
                  },
                ),
              ),
            );
          }
        }
      } else {
        throw Exception('Failed to search location');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching location: $e\nTry using coordinates instead.'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Use Coordinates',
              textColor: Colors.white,
              onPressed: () {
                _showLocationPicker();
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showFullScreenMap() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Select Location',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Map area
              Expanded(
                child: kIsWeb ? _buildLeafletFullScreenMap(enableSearch: false) : _buildMobileFullScreenMap(),
              ),
              // Controls
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showMapSearchDialog();
                        },
                        icon: const Icon(Icons.search),
                        label: const Text('Search'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      ),
                      child: const Text('Confirm'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLocationPicker() {
    final TextEditingController latController = TextEditingController(text: _latitude.toStringAsFixed(6));
    final TextEditingController lngController = TextEditingController(text: _longitude.toStringAsFixed(6));
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter coordinates manually'),
            const SizedBox(height: 16),
            TextField(
              controller: latController,
              decoration: const InputDecoration(
                labelText: 'Latitude',
                hintText: 'e.g., 47.3769',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lngController,
              decoration: const InputDecoration(
                labelText: 'Longitude',
                hintText: 'e.g., 8.5417',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final lat = double.tryParse(latController.text);
              final lng = double.tryParse(lngController.text);
              if (lat != null && lng != null && 
                  lat >= -90 && lat <= 90 && 
                  lng >= -180 && lng <= 180) {
                _updateLocation(lat, lng);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid coordinates')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            child: const Text('Update', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildContactForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _buildTextField(controller: _phoneController, label: 'Phone Number', icon: Icons.call),
          const SizedBox(height: 16),
          _buildTextField(controller: _emailController, label: 'Support Email', icon: Icons.mail),
          const SizedBox(height: 16),
          _buildTextField(controller: _addressController, label: 'Physical Address', icon: Icons.apartment, isMultiline: true),
        ],
      ),
    );
  }

  Widget _buildPolicyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('CANCELLATION RULE', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text('ACTIVE', style: TextStyle(color: primaryColor, fontSize: 9, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _cancellationController,
            maxLines: 3,
            style: const TextStyle(fontSize: 12, color: Color(0xFF606060), height: 1.5),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF6F7F8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, bool isMultiline = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: isMultiline ? 3 : 1,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey, size: 20),
            filled: true,
            fillColor: const Color(0xFFF6F7F8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }


  Widget _buildDangerZone() {
    return TextButton.icon(
      onPressed: () {
        _showResetDialog();
      },
      icon: const Icon(Icons.delete_forever, size: 18),
      label: const Text('Reset Property Configuration'),
      style: TextButton.styleFrom(
        foregroundColor: Colors.red,
        backgroundColor: Colors.red.withOpacity(0.05),
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Configuration'),
        content: const Text('Are you sure you want to reset all settings to default values? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Reset to defaults
              _phoneController.text = '+41 44 211 55 00';
              _emailController.text = 'admin@grandplaza-zurich.com';
              _addressController.text = 'Bahnhofstrasse 31, 8001 Zürich, Switzerland';
              _cancellationController.text = 'Free cancellation up to 48 hours before check-in. Late cancellations or no-shows incur a 1-night penalty.';
              _latitude = 47.3769;
              _longitude = 8.5417;
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingSaveButton() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _saveSettings,
          icon: _isLoading ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ) : const Icon(Icons.save),
          label: Text(_isLoading ? 'Saving...' : 'Save Configuration'),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 60),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 8,
            shadowColor: primaryColor.withOpacity(0.5),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade100),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
    );
  }
}
