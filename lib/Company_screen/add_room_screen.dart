import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

class AddRoomScreen extends StatefulWidget {
  const AddRoomScreen({super.key});

  @override
  State<AddRoomScreen> createState() => _AddRoomScreenState();
}

class _AddRoomScreenState extends State<AddRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomNameController = TextEditingController();
  final _floorController = TextEditingController();
  final _priceController = TextEditingController();
  final _roomAreaController = TextEditingController();
  final _roomDetailsController = TextEditingController();
  String _category = ''; // Room category: Suites, Deluxe, Standard
  String _bedType = '';
  String _capacity = ''; // New field for capacity
  final String _priceUnit = 'night'; // Default to 'night'
  XFile? _pickedImage; // To store the picked image file
  Uint8List? _imageBytes; // To store image bytes for web compatibility
  bool _isLoading = false;
  final List<String> _selectedAmenities = []; // New field for amenities
  bool _availableForDay = true; // Room available for day bookings
  bool _availableForNight = true; // Room available for night bookings

  @override
  void dispose() {
    _roomNameController.dispose();
    _floorController.dispose();
    _priceController.dispose();
    _roomAreaController.dispose();
    _roomDetailsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // Compress image to 85% quality
      );
      
      if (image != null) {
        // Read image bytes for web compatibility
        final Uint8List bytes = await image.readAsBytes();
        setState(() {
          _pickedImage = image;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<String?> _uploadImageToFirebase() async {
    if (_pickedImage == null || _imageBytes == null) return null;

    try {
      // Store images as base64 in Firestore for all platforms
      // This avoids Firebase Storage CORS issues and setup requirements
      // Convert image to base64
      final String base64Image = base64Encode(_imageBytes!);
      
      // Detect MIME type from image bytes header (more reliable than file extension)
      String mimeType = 'jpeg'; // default
      if (_imageBytes!.isNotEmpty) {
        // Check image header bytes
        final Uint8List header = _imageBytes!.sublist(0, _imageBytes!.length > 12 ? 12 : _imageBytes!.length);
        
        // PNG: 89 50 4E 47
        if (header.length >= 4 && header[0] == 0x89 && header[1] == 0x50 && header[2] == 0x4E && header[3] == 0x47) {
          mimeType = 'png';
        }
        // JPEG: FF D8 FF
        else if (header.length >= 3 && header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF) {
          mimeType = 'jpeg';
        }
        // GIF: 47 49 46 38
        else if (header.length >= 4 && header[0] == 0x47 && header[1] == 0x49 && header[2] == 0x46 && header[3] == 0x38) {
          mimeType = 'gif';
        }
        // WebP: Check for "RIFF" and "WEBP"
        else if (header.length >= 12 && 
                 String.fromCharCodes(header.sublist(0, 4)) == 'RIFF' &&
                 String.fromCharCodes(header.sublist(8, 12)) == 'WEBP') {
          mimeType = 'webp';
        }
        // Fallback: try file extension
        else {
          final String fileName = _pickedImage!.name.toLowerCase();
          if (fileName.endsWith('.png')) {
            mimeType = 'png';
          } else if (fileName.endsWith('.gif')) {
            mimeType = 'gif';
          } else if (fileName.endsWith('.webp')) {
            mimeType = 'webp';
          }
        }
      }
      
      final String dataUrl = 'data:image/$mimeType;base64,$base64Image';
      
      // Store in Firestore as base64 (works for both web and mobile)
      // Note: Firestore has 1MB limit per document, so compress images if needed
      final String imageId = 'room_image_${DateTime.now().millisecondsSinceEpoch}';
      await FirebaseFirestore.instance.collection('room_images').doc(imageId).set({
        'imageData': dataUrl,
        'fileName': _pickedImage!.name,
        'uploadedAt': FieldValue.serverTimestamp(),
      });
      
      // Return the data URL directly
      return dataUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _addRoomToFirestore() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Validate that at least one availability option is selected
      if (!_availableForDay && !_availableForNight) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one availability option (Day or Night)')),
        );
        return;
      }

      // Validate that an image is selected
      if (_pickedImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an image')),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        // First, upload the image to Firebase Storage
        final String? uploadedImageUrl = await _uploadImageToFirebase();
        
        if (uploadedImageUrl == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to upload image. Please try again.')),
            );
          }
          return;
        }

        // Then, save the room data with the image URL
        await FirebaseFirestore.instance.collection('rooms').add({
          'name': _roomNameController.text.trim(),
          'category': _category,
          'floor': _floorController.text.trim(),
          'bedType': _bedType, // Updated field name
          'roomArea': _roomAreaController.text.trim(), // New field
          'capacity': _capacity, // New field
          'price': _priceController.text.trim(),
          'priceUnit': _priceUnit,
          'description': _roomDetailsController.text.trim(), // Changed from 'details' to 'description'
          'amenities': _selectedAmenities, // New field
          'imageUrl': uploadedImageUrl,
          'status': 'Available', // Default status for a new room
          'availableForDay': _availableForDay, // Available for day bookings
          'availableForNight': _availableForNight, // Available for night bookings
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Room added successfully!')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add room: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildAmenityCheckbox(String title, IconData icon) {
    return CheckboxListTile(
      title: Row(
        children: [
          Icon(icon, color: const Color(0xFF339999)),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      value: _selectedAmenities.contains(title),
      onChanged: (bool? value) {
        setState(() {
          if (value == true) {
            _selectedAmenities.add(title);
          } else {
            _selectedAmenities.remove(title);
          }
        });
      },
      activeColor: const Color(0xFF339999),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Room'),
        backgroundColor: const Color(0xFF339999),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _roomNameController,
                decoration: const InputDecoration(
                  labelText: 'Room Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a room name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                initialValue: _category.isEmpty ? null : _category,
                items: const [
                  DropdownMenuItem(value: 'Suites', child: Text('Suites')),
                  DropdownMenuItem(value: 'Deluxe', child: Text('Deluxe')),
                  DropdownMenuItem(value: 'Standard', child: Text('Standard')),
                  DropdownMenuItem(value: 'Pool', child: Text('Pool')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a category';
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {
                    _category = value ?? '';
                  });
                },
                onSaved: (value) {
                  _category = value ?? '';
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _floorController,
                decoration: const InputDecoration(
                  labelText: 'Floor',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the floor number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Bed Type',
                  border: OutlineInputBorder(),
                ),
                initialValue: _bedType.isEmpty ? null : _bedType,
                items: const [
                  DropdownMenuItem(value: 'King Bed', child: Text('King Bed')),
                  DropdownMenuItem(value: 'Queen Bed', child: Text('Queen Bed')),
                  DropdownMenuItem(value: 'Single Bed', child: Text('Single Bed')),
                  DropdownMenuItem(value: 'Twin Beds', child: Text('Twin Beds')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a bed type';
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {
                    _bedType = value ?? '';
                  });
                },
                onSaved: (value) {
                  _bedType = value ?? '';
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _roomAreaController,
                decoration: const InputDecoration(
                  labelText: 'Room Area (sq ft)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the room area';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Capacity (Adults)',
                  border: OutlineInputBorder(),
                ),
                initialValue: _capacity.isEmpty ? null : _capacity,
                items: const [
                  DropdownMenuItem(value: '1', child: Text('1 Adult')),
                  DropdownMenuItem(value: '2', child: Text('2 Adults')),
                  DropdownMenuItem(value: '3', child: Text('3 Adults')),
                  DropdownMenuItem(value: '4', child: Text('4 Adults')),
                  DropdownMenuItem(value: '5+', child: Text('5+ Adults')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select room capacity';
                  }
                  return null;
                },
                      onChanged: (value) {
                        setState(() {
                    _capacity = value ?? '';
                        });
                      },
                onSaved: (value) {
                  _capacity = value ?? '';
                      },
                    ),
              const SizedBox(height: 16),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the price';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Availability checkboxes
              const Text(
                'Availability',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text('Available for Day Bookings'),
                value: _availableForDay,
                onChanged: (bool? value) {
                  setState(() {
                    _availableForDay = value ?? true;
                  });
                },
                activeColor: const Color(0xFF339999),
              ),
              CheckboxListTile(
                title: const Text('Available for Night Bookings'),
                value: _availableForNight,
                onChanged: (bool? value) {
                  setState(() {
                    _availableForNight = value ?? true;
                  });
                },
                activeColor: const Color(0xFF339999),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _roomDetailsController,
                decoration: const InputDecoration(
                  labelText: 'Room Details',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter room details';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Amenities Checklist
              const Text(
                'Amenities',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              _buildAmenityCheckbox('Free Wi-Fi', Icons.wifi),
              _buildAmenityCheckbox('Air Conditioning', Icons.ac_unit),
              _buildAmenityCheckbox('Pool Access', Icons.pool),
              _buildAmenityCheckbox('Mini Bar', Icons.local_bar),
              _buildAmenityCheckbox('Smart TV', Icons.tv),
              _buildAmenityCheckbox('Espresso Machine', Icons.coffee_maker),
              const SizedBox(height: 16),
              // Image picker button and preview
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Room Image',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pickImage,
                    icon: const Icon(Icons.image),
                    label: const Text('Pick Image from Gallery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF339999),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Image preview section
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _pickedImage != null && _imageBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _imageBytes!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                      SizedBox(height: 8),
                                      Text('Failed to load image', style: TextStyle(color: Colors.grey)),
                                    ],
                                  ),
                                );
                              },
                            ),
                          )
                        : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image, size: 50, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('No image selected', style: TextStyle(color: Colors.grey)),
                                SizedBox(height: 4),
                                Text('Tap "Pick Image" to select', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _addRoomToFirestore,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF339999),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Add Room',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

