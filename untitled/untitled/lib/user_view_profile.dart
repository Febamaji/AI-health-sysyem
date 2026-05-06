// lib/screens/user_profile_view.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:untitled/user_add_appo.dart';
import 'package:untitled/user_add_emergency.dart';
import 'package:untitled/user_add_medi_plan.dart';
import 'package:untitled/user_add_medicine.dart';
import 'package:untitled/userhome.dart';



// lib/models/user_profile.dart
class UserProfile {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String dateOfBirth;
  final int age;
  final String gender;
  final String address;
  final String relationship;
  final String? profileImage;
  final DateTime? createdAt;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.dateOfBirth,
    required this.age,
    required this.gender,
    required this.address,
    required this.relationship,
    this.profileImage,
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone_number'] ?? json['phone'] ?? '',
      dateOfBirth: json['dob'] ?? '',
      age: int.tryParse(json['age']?.toString() ?? '0') ?? 0,
      gender: json['gender'] ?? 'Male',
      address: json['address'] ?? '',
      relationship: json['relation'] ?? '',
      profileImage: json['face_image'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone_number': phone,
      'dob': dateOfBirth,
      'age': age,
      'gender': gender,
      'address': address,
      'relation': relationship,
      'face_image': profileImage,
    };
  }

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? dateOfBirth,
    int? age,
    String? gender,
    String? address,
    String? relationship,
    String? profileImage,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      address: address ?? this.address,
      relationship: relationship ?? this.relationship,
      profileImage: profileImage ?? this.profileImage,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class UserProfileViewPage extends StatefulWidget {
  const UserProfileViewPage({super.key});

  @override
  State<UserProfileViewPage> createState() => _UserProfileViewPageState();
}

class _UserProfileViewPageState extends State<UserProfileViewPage> {
  UserProfile? _userProfile;
  bool _isLoading = true;
  bool _isEditing = false;
  final ImagePicker _imagePicker = ImagePicker();
  File? _profileImage;
  DateTime? _selectedDate;
  int? _calculatedAge;
  bool _isAdult = false; // Flag to check if user is 18+

  // Form controllers for edit mode
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dateOfBirthController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _relationshipController = TextEditingController();

  String _selectedGender = 'Male';
  String? _selectedRelationship;

  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _relationships = [
    'Spouse',
    'Child',
    'Son',
    'Daughter',
    'Grandchild',
    'Sibling',
    'Parent',
    'Friend',
    'Neighbor',
    'Professional Caregiver',
    'Other Relative'
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String url = prefs.getString("url") ?? "";
    String imgurl = prefs.getString("img_url") ?? "";

    String userId = prefs.getString("lid") ?? "";

    print("Fetching profile from: $url/get_user_profile/?lid=$userId");

    try {
      final response = await http.get(
        Uri.parse('$url/get_user_profile/?lid=$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        // Check the response structure
        if (jsonData['status'] == 'ok' && jsonData['data'] != null) {
          // Extract data from the 'data' field
          final data = jsonData['data'];

          // Check if data is a list
          if (data is List) {
            if (data.isNotEmpty) {
              // Take the first element from the list
              final userData = data[0];
              print("User data: $userData");

              // Extract profile image URL
              String profileImageUrl = '';
              if (userData['face_image'] != null && userData['face_image'].isNotEmpty) {
                profileImageUrl = '$imgurl${userData['face_image']}';
                print("Profile image URL: $profileImageUrl");
              }

              setState(() {
                _userProfile = UserProfile.fromJson(userData);
                _userProfile = _userProfile!.copyWith(profileImage: profileImageUrl);
                _initializeControllers();

                // Check if user is 18+
                _isAdult = _userProfile!.age >= 18;

                _isLoading = false;
              });
            } else {
              // List is empty
              print("No user data found in list");
              _showSnack("No profile data found", Colors.orange);
              setState(() {
                _isLoading = false;
              });
            }
          } else if (data is Map<String, dynamic>) {
            // Single object response
            print("Single user data: $data");

            // Extract profile image URL
            String profileImageUrl = '';
            if (data['face_image'] != null && data['face_image'].isNotEmpty) {
              profileImageUrl = '$url${data['face_image']}';
              print("Profile image URL: $profileImageUrl");
            }

            setState(() {
              _userProfile = UserProfile.fromJson(data);
              _userProfile = _userProfile!.copyWith(profileImage: profileImageUrl);
              _initializeControllers();

              // Check if user is 18+
              _isAdult = _userProfile!.age >= 18;

              _isLoading = false;
            });
          } else {
            print("Unexpected data format: $data");
            _showSnack("Unexpected data format", Colors.red);
            setState(() {
              _isLoading = false;
            });
          }
        } else {
          print("Invalid response structure: $jsonData");
          _showSnack("Invalid response from server", Colors.red);
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        print("Failed with status: ${response.statusCode}");
        _showSnack("Failed to load profile", Colors.red);
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching profile: $e");
      _showSnack("Network error: $e", Colors.red);
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _initializeControllers() {
    if (_userProfile == null) return;

    _nameController.text = _userProfile!.name;
    _phoneController.text = _userProfile!.phone;
    _dateOfBirthController.text = _userProfile!.dateOfBirth;
    _addressController.text = _userProfile!.address;
    _relationshipController.text = _userProfile!.relationship;
    _selectedGender = _userProfile!.gender;
    _selectedRelationship = _userProfile!.relationship;

    // Parse date of birth
    try {
      final parts = _userProfile!.dateOfBirth.split('/');
      if (parts.length == 3) {
        _selectedDate = DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
        _calculatedAge = _calculateAge(_selectedDate!);
      }
    } catch (e) {
      print("Error parsing date: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FDF8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1B5E20),
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1B5E20)),
          onPressed: () {
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => PatientHomePage())
            );
          },
        ),
        title: Text(
          _isEditing ? 'Edit Profile' : 'My Profile',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
          ),
        ),
        actions: [
          if (!_isEditing && _userProfile != null)
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: Color(0xFF2E7D32)),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              tooltip: 'Edit Profile',
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.red),
              onPressed: _cancelEdit,
              tooltip: 'Cancel',
            ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          color: Color(0xFF2E7D32),
        ),
      )
          : _userProfile == null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off_rounded,
              size: 60,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No profile data found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _fetchUserProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2E7D32),
                foregroundColor: Colors.white,
              ),
              child: Text('Retry'),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 24),
            _isEditing ? _buildEditForm() : _buildProfileDetails(),
            // Show options for adults only
            if (!_isEditing && _isAdult) _buildAdultOptions(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    if (_userProfile == null) return SizedBox();

    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Color(0xFF2E7D32),
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: _profileImage != null
                    ? Image.file(
                  _profileImage!,
                  fit: BoxFit.cover,
                  width: 140,
                  height: 140,
                )
                    : (_userProfile!.profileImage != null && _userProfile!.profileImage!.isNotEmpty)
                    ? Image.network(
                  _userProfile!.profileImage!,
                  fit: BoxFit.cover,
                  width: 140,
                  height: 140,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                            : null,
                        color: Color(0xFF2E7D32),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    print("Image error: $error");
                    return Container(
                      color: Colors.grey[200],
                      child: Icon(
                        Icons.person_rounded,
                        size: 60,
                        color: Color(0xFF2E7D32),
                      ),
                    );
                  },
                )
                    : Container(
                  color: Colors.grey[200],
                  child: Icon(
                    Icons.person_rounded,
                    size: 60,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),
            ),
            if (_isEditing)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF2E7D32),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(Icons.camera_alt_rounded, size: 20, color: Colors.white),
                    onPressed: _pickImage,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _userProfile!.name,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _userProfile!.relationship,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
        // Age badge
        Container(
          margin: EdgeInsets.only(top: 8),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _isAdult ? Color(0xFF2E7D32) : Colors.orange,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Age: ${_userProfile!.age} years',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (_userProfile!.createdAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              'Member since ${DateFormat('MMMM yyyy').format(_userProfile!.createdAt!)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProfileDetails() {
    if (_userProfile == null) return SizedBox();

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      shadowColor: Color(0xFF2E7D32).withOpacity(0.2),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
              icon: Icons.email_rounded,
              title: 'Email',
              value: _userProfile!.email,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            _buildInfoRow(
              icon: Icons.phone_rounded,
              title: 'Phone',
              value: _userProfile!.phone,
              color: Colors.green,
            ),
            const SizedBox(height: 20),
            _buildInfoRow(
              icon: Icons.cake_rounded,
              title: 'Date of Birth',
              value: _userProfile!.dateOfBirth,
              subtitle: 'Age: ${_userProfile!.age} years',
              color: Colors.orange,
            ),
            const SizedBox(height: 20),
            _buildInfoRow(
              icon: Icons.transgender_rounded,
              title: 'Gender',
              value: _userProfile!.gender,
              color: Colors.purple,
            ),
            const SizedBox(height: 20),
            _buildInfoRow(
              icon: Icons.home_rounded,
              title: 'Address',
              value: _userProfile!.address,
              color: Colors.brown,
              isMultiLine: true,
            ),
            const SizedBox(height: 20),
            _buildInfoRow(
              icon: Icons.family_restroom_rounded,
              title: 'Relationship',
              value: _userProfile!.relationship,
              color: Colors.teal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdultOptions() {
    return Container(
      margin: EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              'Health Management Options',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E20),
              ),
            ),
          ),
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              _buildOptionCard(
                title: 'Add Medicine',
                icon: Icons.medication_rounded,
                color: Color(0xFF4CAF50),
                onTap: () {
                  // Navigate to Add Medicine page
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => userAddMedicinePage(pid: _userProfile!.id),
                    ),
                  );
                },
              ),
              _buildOptionCard(
                title: 'Add Emergency',
                icon: Icons.emergency_rounded,
                color: Color(0xFFF44336),
                onTap: () {
                  // Navigate to Add Emergency page
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => userEmergencyContactsPage(patientId: _userProfile!.id,patientName:_userProfile!.name),
                    ),
                  );
                },
              ),
              _buildOptionCard(
                title: 'Medicine Plan',
                icon: Icons.assignment_rounded,
                color: Color(0xFF2196F3),
                onTap: () {
                  // Navigate to Medicine Plan page
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => userMedicinePlanPage(patientId: _userProfile!.id,patientName: _userProfile!.name,),
                    ),
                  );
                },
              ),
              _buildOptionCard(
                title: 'Appointments',
                icon: Icons.calendar_today_rounded,
                color: Color(0xFF9C27B0),
                onTap: () {
                  // Navigate to Appointments page
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => user_DoctorAppointmentPage(patientId: _userProfile!.id,patientName: _userProfile!.name,),
                    ),
                  );
                },
              ),
            ],
          ),
          // Info message for age restriction
          Container(
            margin: EdgeInsets.only(top: 16),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFFE8F5E8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFF2E7D32).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_rounded, color: Color(0xFF2E7D32), size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'These options are available for users 18 years and above.',
                    style: TextStyle(
                      color: Color(0xFF1B5E20),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.15),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditForm() {
    if (_userProfile == null) return SizedBox();

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      shadowColor: Color(0xFF2E7D32).withOpacity(0.2),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Email (Read-only)
            _buildReadOnlyField(
              label: 'Email Address',
              value: _userProfile!.email,
              icon: Icons.email_rounded,
            ),
            const SizedBox(height: 20),

            // Full Name
            _buildFormField(
              controller: _nameController,
              label: 'Full Name *',
              hint: 'Enter your full name',
              prefixIcon: Icons.person_rounded,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your full name';
                }
                if (value.length < 2) {
                  return 'Name must be at least 2 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Phone Number
            _buildFormField(
              controller: _phoneController,
              label: 'Phone Number *',
              hint: 'Enter your phone number',
              prefixIcon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your phone number';
                }
                if (!RegExp(r'^[0-9]{10,15}$').hasMatch(value)) {
                  return 'Please enter a valid phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Date of Birth with Age Display
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFormField(
                  controller: _dateOfBirthController,
                  label: 'Date of Birth *',
                  hint: 'Select your date of birth',
                  prefixIcon: Icons.calendar_today_rounded,
                  readOnly: true,
                  onTap: () => _selectDateOfBirth(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select your date of birth';
                    }
                    return null;
                  },
                ),
                if (_calculatedAge != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.cake_rounded,
                          size: 16,
                          color: Color(0xFF2E7D32),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Age: $_calculatedAge years',
                          style: TextStyle(
                            color: Color(0xFF2E7D32),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Gender
            _buildGenderDropdown(),
            const SizedBox(height: 20),

            // Relationship to Caregiver
            _buildRelationshipDropdown(),
            const SizedBox(height: 20),

            // Custom Relationship (if "Other" is selected)
            if (_selectedRelationship == 'Other Relative')
              _buildFormField(
                controller: _relationshipController,
                label: 'Specify Relationship *',
                hint: 'Enter your relationship to caregiver',
                prefixIcon: Icons.family_restroom_rounded,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please specify your relationship';
                  }
                  return null;
                },
              ),
            if (_selectedRelationship == 'Other Relative') const SizedBox(height: 20),

            // Address
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Address *',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _addressController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Enter your complete address',
                    prefixIcon: Icon(Icons.home_rounded, color: Color(0xFF2E7D32)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[400]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF2E7D32), width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your address';
                    }
                    if (value.length < 10) {
                      return 'Please enter a complete address';
                    }
                    return null;
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Save and Cancel Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cancelEdit,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey[400]!),
                    ),
                    child: Text(
                      'CANCEL',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _updateProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'SAVE CHANGES',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Rest of your existing methods remain the same...
  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    Color color = Colors.grey,
    String? subtitle,
    bool isMultiLine = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: color,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  if (isMultiLine)
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
            color: Colors.grey[50],
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.grey[500]),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(Icons.lock_outline_rounded, size: 18, color: Colors.grey[500]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    bool obscureText = false,
    bool readOnly = false,
    String? Function(String?)? validator,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(prefixIcon, color: Color(0xFF2E7D32)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[400]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Color(0xFF2E7D32), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      style: TextStyle(
        fontSize: 16,
        color: Colors.grey[800],
        fontWeight: FontWeight.w500,
      ),
      validator: validator,
    );
  }

  Widget _buildGenderDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[400]!),
            color: Colors.grey[50],
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedGender,
            items: _genders.map((String gender) {
              return DropdownMenuItem<String>(
                value: gender,
                child: Text(
                  gender,
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedGender = newValue!;
              });
            },
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.transgender_rounded, color: Color(0xFF2E7D32)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRelationshipDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Relationship to Primary Caregiver *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[400]!),
            color: Colors.grey[50],
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedRelationship,
            items: _relationships.map((String relationship) {
              return DropdownMenuItem<String>(
                value: relationship,
                child: Text(
                  relationship,
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedRelationship = newValue;
                if (newValue != 'Other Relative') {
                  _relationshipController.clear();
                }
              });
            },
            decoration: InputDecoration(
              hintText: 'Select relationship',
              prefixIcon: Icon(Icons.family_restroom_rounded, color: Color(0xFF2E7D32)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[800],
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select your relationship to caregiver';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
      });
    }
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().subtract(Duration(days: 365 * 30)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF2E7D32),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateOfBirthController.text = "${picked.day}/${picked.month}/${picked.year}";
        _calculatedAge = _calculateAge(picked);

        // Update adult flag
        _isAdult = _calculatedAge! >= 18;
      });
    }
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    final monthDifference = now.month - birthDate.month;

    if (monthDifference < 0 || (monthDifference == 0 && now.day < birthDate.day)) {
      age--;
    }

    return age;
  }

  void _cancelEdit() {
    // Reset to original values
    _initializeControllers();
    setState(() {
      _isEditing = false;
      _profileImage = null;
    });
  }

  Future<void> _updateProfile() async {
    if (_userProfile == null) return;

    // Validate required fields
    if (_nameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _dateOfBirthController.text.isEmpty ||
        _addressController.text.isEmpty ||
        _selectedRelationship == null) {
      _showSnack("Please fill all required fields", Colors.orange);
      return;
    }

    // If "Other" is selected, validate custom relationship field
    if (_selectedRelationship == 'Other Relative' &&
        (_relationshipController.text.isEmpty || _relationshipController.text.length < 2)) {
      _showSnack("Please specify your relationship", Colors.orange);
      return;
    }

    // Calculate age if not already calculated
    if (_selectedDate != null && _calculatedAge == null) {
      _calculatedAge = _calculateAge(_selectedDate!);
    }

    setState(() {
      _isLoading = true;
    });

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String url = prefs.getString("url") ?? "";
    String userId = prefs.getString("lid") ?? ""; // Using lid as user_id

    if (url.isEmpty || userId.isEmpty) {
      // For demo, just update locally
      await Future.delayed(Duration(seconds: 1));
      final int newAge = _calculatedAge ?? _userProfile!.age;
      setState(() {
        _userProfile = _userProfile!.copyWith(
          name: _nameController.text,
          phone: _phoneController.text,
          dateOfBirth: _dateOfBirthController.text,
          age: newAge,
          gender: _selectedGender,
          address: _addressController.text,
          relationship: _selectedRelationship == 'Other Relative'
              ? _relationshipController.text
              : _selectedRelationship!,
        );
        // Update adult flag
        _isAdult = newAge >= 18;
        _isEditing = false;
        _isLoading = false;
      });
      _showSnack("Profile updated successfully!", Colors.green);
      return;
    }

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$url/update_user_profile/'));

      // Add text fields
      request.fields['lid'] = userId; // Using lid instead of user_id
      request.fields['name'] = _nameController.text;
      request.fields['phone_number'] = _phoneController.text;
      request.fields['dob'] = _dateOfBirthController.text; // Changed to dob
      request.fields['age'] = _calculatedAge?.toString() ?? _userProfile!.age.toString();
      request.fields['gender'] = _selectedGender;
      request.fields['address'] = _addressController.text;

      // Add relationship data
      String finalRelationship = _selectedRelationship == 'Other Relative'
          ? _relationshipController.text
          : _selectedRelationship!;
      request.fields['relation'] = finalRelationship; // Changed to relation

      // Add profile image if new one selected
      if (_profileImage != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'face_image', // Changed to face_image
          _profileImage!.path,
        ));
      }

      var response = await request.send();
      var responseBody = await http.Response.fromStream(response);

      print("Update response: ${responseBody.body}");

      if (response.statusCode == 200) {
        final jsonData = json.decode(responseBody.body);

        // Check if update was successful
        if (jsonData['status'] == 'ok') {
          final int newAge = _calculatedAge ?? _userProfile!.age;
          // Update local profile
          setState(() {
            _userProfile = _userProfile!.copyWith(
              name: _nameController.text,
              phone: _phoneController.text,
              dateOfBirth: _dateOfBirthController.text,
              age: newAge,
              gender: _selectedGender,
              address: _addressController.text,
              relationship: finalRelationship,
            );
            // Update adult flag
            _isAdult = newAge >= 18;
            _isEditing = false;
            _isLoading = false;
          });

          _showSnack("Profile updated successfully!", Colors.green);
        } else {
          _showSnack("Update failed: ${jsonData['message']}", Colors.red);
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        _showSnack("Failed to update profile", Colors.red);
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error updating profile: $e");
      _showSnack("Failed to update profile: $e", Colors.red);
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnack(String message, Color color) {
    Fluttertoast.showToast(
      msg: message,
      backgroundColor: color,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _dateOfBirthController.dispose();
    _addressController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }
}