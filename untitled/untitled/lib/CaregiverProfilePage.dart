import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class CaregiverProfilePage extends StatefulWidget {
  const CaregiverProfilePage({super.key});

  @override
  State<CaregiverProfilePage> createState() => _CaregiverProfilePageState();
}

class _CaregiverProfilePageState extends State<CaregiverProfilePage> {
  final _formKey = GlobalKey<FormState>();

  // Profile fields
  Map<String, dynamic> _profileData = {};
  bool _isLoading = true;
  bool _hasError = false;
  bool _isEditing = false;

  // Controllers for editing
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String url = prefs.getString("url") ?? "";
    String lid = prefs.getString("lid") ?? "";

    if (url.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$url/view_caregiver_profile/?lid=$lid'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("API Response: $data"); // Debug print

        if (data['status'] == 'ok') {
          // Handle both List and Map responses
          dynamic responseData = data['data'];
          Map<String, dynamic> profileData = {};

          if (responseData is List) {
            // If it's a list, take the first element
            if (responseData.isNotEmpty) {
              profileData = responseData[0] is Map<String, dynamic>
                  ? responseData[0]
                  : {};
            }
          } else if (responseData is Map) {
            // If it's already a map, use it directly
            profileData = responseData.cast<String, dynamic>();
          }

          setState(() {
            _profileData = profileData;
            _initializeControllers();
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
          Fluttertoast.showToast(
            msg: 'Failed to load profile data',
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
        Fluttertoast.showToast(
          msg: 'Server error: ${response.statusCode}',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print("Error loading profile: $e");
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      Fluttertoast.showToast(
        msg: 'Error: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  void _initializeControllers() {
    _nameController.text = _profileData['name'] ?? _profileData['NAME'] ?? '';
    _phoneController.text = _profileData['phone_number'] ?? _profileData['PHONE_NUMBER'] ?? '';
    _emailController.text = _profileData['email'] ?? _profileData['EMAIL'] ?? '';
    _genderController.text = _profileData['gender'] ?? _profileData['GENDER'] ?? '';
    _addressController.text = _profileData['address'] ?? _profileData['ADDRESS'] ?? '';
  }

  // Helper method to get profile value with fallback for different field names
  String _getProfileValue(List<String> possibleKeys) {
    for (String key in possibleKeys) {
      if (_profileData.containsKey(key) && _profileData[key] != null) {
        return _profileData[key].toString();
      }
    }
    return 'Not set';
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      String url = prefs.getString("url") ?? "";
      String lid = prefs.getString("lid") ?? "";

      try {
        final response = await http.post(
          Uri.parse('$url/update_caregiver_profile/'),
          body: {
            'lid': lid,
            'name': _nameController.text,
            'phone_number': _phoneController.text,
            'email': _emailController.text,
            'gender': _genderController.text,
            'address': _addressController.text,
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          print("Update Response: $data"); // Debug print

          if (data['status'] == 'success') {
            // Update local profile data
            setState(() {
              _profileData = {
                'name': _nameController.text,
                'phone_number': _phoneController.text,
                'email': _emailController.text,
                'gender': _genderController.text,
                'address': _addressController.text,
              };
              _isEditing = false;
              _isLoading = false;
            });

            // Update SharedPreferences
            await prefs.setString('uname', _nameController.text);

            Fluttertoast.showToast(
              msg: 'Profile updated successfully',
              backgroundColor: Colors.green,
              textColor: Colors.white,
            );

            // Reload data to ensure consistency
            _loadProfileData();
          } else {
            setState(() {
              _isLoading = false;
            });
            Fluttertoast.showToast(
              msg: data['message'] ?? 'Failed to update profile',
              backgroundColor: Colors.red,
              textColor: Colors.white,
            );
          }
        } else {
          setState(() {
            _isLoading = false;
          });
          Fluttertoast.showToast(
            msg: 'Server error: ${response.statusCode}',
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        Fluttertoast.showToast(
          msg: 'Error updating profile: $e',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _initializeControllers(); // Reset to original values
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FDF8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1B5E20),
        elevation: 2,
        title: Text(
          'Caregiver Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
          ),
        ),
        actions: _buildAppBarActions(),
      ),
      body: _buildBody(),
    );
  }

  List<Widget> _buildAppBarActions() {
    if (_isLoading) {
      return [];
    }

    if (_isEditing) {
      return [
        IconButton(
          icon: Icon(Icons.close_rounded),
          onPressed: _cancelEditing,
          color: Color(0xFFD32F2F),
        ),
        IconButton(
          icon: Icon(Icons.check_rounded),
          onPressed: _updateProfile,
          color: Color(0xFF1B5E20),
        ),
      ];
    } else {
      return [
        IconButton(
          icon: Icon(Icons.edit_rounded),
          onPressed: _startEditing,
          color: Color(0xFF1B5E20),
        ),
        IconButton(
          icon: Icon(Icons.refresh_rounded),
          onPressed: _loadProfileData,
          tooltip: 'Refresh',
        ),
      ];
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
            ),
            SizedBox(height: 16),
            Text(
              'Loading profile...',
              style: TextStyle(
                color: Color(0xFF1B5E20),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.red,
            ),
            SizedBox(height: 16),
            Text(
              'Failed to load profile',
              style: TextStyle(
                color: Colors.red,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Please check your connection and try again',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadProfileData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2E7D32),
                foregroundColor: Colors.white,
              ),
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Profile Header
            _buildProfileHeader(),
            SizedBox(height: 24),

            // Profile Information
            _buildProfileInformation(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    String displayName = _getProfileValue(['name', 'NAME', 'uname']);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName.isEmpty ? 'Caregiver' : displayName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Certified Caregiver',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  if (!_isEditing)
                    Text(
                      'Tap edit to update your profile information',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  if (_isEditing)
                    Text(
                      'Editing mode - Make your changes and save',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
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

  Widget _buildProfileInformation() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_outline_rounded, color: Color(0xFF1B5E20)),
                SizedBox(width: 8),
                Text(
                  'Personal Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Name Field
            _buildEditableField(
              label: 'Full Name',
              value: _getProfileValue(['name', 'NAME']),
              controller: _nameController,
              icon: Icons.person_rounded,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),

            // Phone Number Field
            _buildEditableField(
              label: 'Phone Number',
              value: _getProfileValue(['phone_number', 'PHONE_NUMBER']),
              controller: _phoneController,
              icon: Icons.phone_rounded,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter phone number';
                }
                if (value.length < 10) {
                  return 'Please enter a valid phone number';
                }
                return null;
              },
            ),

            // Email Field
            _buildEditableField(
              label: 'Email Address',
              value: _getProfileValue(['email', 'EMAIL']),
              controller: _emailController,
              icon: Icons.email_rounded,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter email address';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),

            // Gender Field
            _buildEditableField(
              label: 'Gender',
              value: _getProfileValue(['gender', 'GENDER']),
              controller: _genderController,
              icon: Icons.people_rounded,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter gender';
                }
                return null;
              },
            ),

            // Address Field
            _buildEditableField(
              label: 'Address',
              value: _getProfileValue(['address', 'ADDRESS']),
              controller: _addressController,
              icon: Icons.home_rounded,
              isMultiline: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter address';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required String value,
    required TextEditingController controller,
    required IconData icon,
    required String? Function(String?) validator,
    bool isMultiline = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Color(0xFF1B5E20), size: 20),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1B5E20),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          _isEditing
              ? TextFormField(
            controller: controller,
            validator: validator,
            maxLines: isMultiline ? 3 : 1,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFF1B5E20)),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red),
              ),
            ),
          )
              : Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: value == 'Not set' ? Colors.grey : Colors.grey.shade800,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _genderController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}