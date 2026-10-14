import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CompanyEditProfilePage extends StatefulWidget {
  final String userEmail;
  final String userRole;

  const CompanyEditProfilePage({super.key, required this.userEmail, required this.userRole});

  @override
  State<CompanyEditProfilePage> createState() => _CompanyEditProfilePageState();
}

class _CompanyEditProfilePageState extends State<CompanyEditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _employeeIdController;
  late TextEditingController _departmentController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _emailController = TextEditingController(text: widget.userEmail);
    _phoneController = TextEditingController();
    _employeeIdController = TextEditingController();
    _departmentController = TextEditingController();
    _fetchUserData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _employeeIdController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.userEmail).get();
      if (doc.exists) {
        final data = doc.data();
        _fullNameController.text = data?['fullName'] ?? '';
        _phoneController.text = data?['phone'] ?? '';
        _employeeIdController.text = data?['employeeId'] ?? '';
        _departmentController.text = data?['department'] ?? '';
      }
    } catch (e) {
      _showSnack('Failed to load user data.');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUserData() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await FirebaseFirestore.instance.collection('users').doc(widget.userEmail).update({
          'fullName': _fullNameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'employeeId': _employeeIdController.text.trim(),
          'department': _departmentController.text.trim(),
        });
        _showSnack('Profile updated successfully!');
        if (mounted) Navigator.pop(context); // Go back to profile page
      } catch (e) {
        _showSnack('Failed to update profile.');
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Employee Profile'),
        backgroundColor: const Color(0xFFF6F2EF),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter full name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      readOnly: true, // Email should not be editable
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(labelText: 'Phone Number'),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _employeeIdController,
                      decoration: const InputDecoration(labelText: 'Employee ID'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter employee ID';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _departmentController,
                      decoration: const InputDecoration(labelText: 'Department'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter department';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _updateUserData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2A585A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

