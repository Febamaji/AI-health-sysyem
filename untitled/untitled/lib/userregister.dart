import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

import 'care_home.dart';

class PatientRegisterPage extends StatefulWidget {
  const PatientRegisterPage({super.key});

  @override
  State<PatientRegisterPage> createState() => _PatientRegisterPageState();
}

class _PatientRegisterPageState extends State<PatientRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dateOfBirthController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _relationshipController = TextEditingController();

  String _selectedGender = 'Male';
  String? _selectedRelationship;
  File? _profileImage;
  bool _isLoading = false;
  final ImagePicker _imagePicker = ImagePicker();
  DateTime? _selectedDate;
  int? _calculatedAge;

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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FDF8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1B5E20),
        elevation: 0,
        title: Text(
          'Patient Registration',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => CaregiverHomePage())
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              _buildHeaderSection(),
              const SizedBox(height: 32),
              _buildRegistrationForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      children: [
        // Profile Image Section
        Stack(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Color(0xFF2E7D32),
                  width: 3,
                ),
                color: Colors.grey[100],
              ),
              child: _profileImage != null
                  ? ClipOval(
                child: Image.file(
                  _profileImage!,
                  fit: BoxFit.cover,
                  width: 120,
                  height: 120,
                ),
              )
                  : Icon(
                Icons.person_rounded,
                size: 50,
                color: Color(0xFF2E7D32),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF2E7D32),
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: IconButton(
                  icon: Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                  onPressed: _pickImage,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Add Profile Photo',
          style: TextStyle(
            color: Color(0xFF2E7D32),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Dementia Care Patient Registration',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Create your healthcare account to access personalized care',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRegistrationForm() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      shadowColor: Color(0xFF2E7D32).withOpacity(0.2),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
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

              // Email
              _buildFormField(
                controller: _emailController,
                label: 'Email Address *',
                hint: 'Enter your email address',
                prefixIcon: Icons.email_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email address';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Please enter a valid email address';
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
              _buildAddressField(),
              const SizedBox(height: 20),

              // Password
              _buildFormField(
                controller: _passwordController,
                label: 'Password *',
                hint: 'Create a secure password',
                prefixIcon: Icons.lock_rounded,
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Confirm Password
              _buildFormField(
                controller: _confirmPasswordController,
                label: 'Confirm Password *',
                hint: 'Re-enter your password',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Register Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_add_rounded, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'CREATE ACCOUNT',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Terms Notice
              Text(
                'By creating an account, you agree to our Terms of Service and Privacy Policy',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
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

  Widget _buildAddressField() {
    return Column(
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
      initialDate: DateTime.now().subtract(Duration(days: 365 * 30)), // 30 years ago
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
      });
    }
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    final monthDifference = now.month - birthDate.month;

    // Adjust age if birthday hasn't occurred this year
    if (monthDifference < 0 || (monthDifference == 0 && now.day < birthDate.day)) {
      age--;
    }

    return age;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      _showSnack("Please fill all required fields correctly", Colors.orange);
      return;
    }

    // Validate relationship
    if (_selectedRelationship == null || _selectedRelationship!.isEmpty) {
      _showSnack("Please select your relationship to caregiver", Colors.orange);
      return;
    }

    // If "Other" is selected, validate custom relationship field
    if (_selectedRelationship == 'Other Relative' &&
        (_relationshipController.text.isEmpty || _relationshipController.text.length < 2)) {
      _showSnack("Please specify your relationship", Colors.orange);
      return;
    }

    // Validate that date of birth is selected and age is calculated
    if (_selectedDate == null) {
      _showSnack("Please select a valid date of birth", Colors.orange);
      return;
    }

    // Calculate age if not already calculated
    if (_calculatedAge == null) {
      _calculatedAge = _calculateAge(_selectedDate!);
    }

    // Additional validation for age (optional)
    if (_calculatedAge! < 0) {
      _showSnack("Invalid date of birth", Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String url = prefs.getString("url") ?? "";
    String lid = prefs.getString("lid") ?? "";

    if (url.isEmpty) {
      _showSnack("Server configuration not found", Colors.red);
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$url/Userregister/'));

      // Add text fields
      request.fields['name'] = _nameController.text;
      request.fields['lid'] = lid;
      request.fields['phone_number'] = _phoneController.text;
      request.fields['date_of_birth'] = _dateOfBirthController.text;
      request.fields['age'] = _calculatedAge!.toString(); // Send age to Python
      request.fields['gender'] = _selectedGender;
      request.fields['address'] = _addressController.text;
      request.fields['email'] = _emailController.text;
      request.fields['password'] = _passwordController.text;

      // Add relationship data
      String finalRelationship = _selectedRelationship == 'Other Relative'
          ? _relationshipController.text
          : _selectedRelationship!;
      request.fields['relationship'] = finalRelationship;

      // Add profile image if selected
      if (_profileImage != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'profile_image',
          _profileImage!.path,
        ));
      }

      var response = await request.send();
      var responseBody = await http.Response.fromStream(response);

      if (response.statusCode == 200) {
        var jsonData = json.decode(responseBody.body);
        print("Registration successful: $jsonData");
        print("Age sent to server: $_calculatedAge");
        _showSuccessDialog();
      } else {
        print("Failed: ${responseBody.body}");
        _showSnack("Registration failed: ${responseBody.body}", Colors.red);
      }
    } catch (e) {
      print("Error: $e");
      _showSnack("Network error: Please check your connection", Colors.red);
    } finally {
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

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Color(0xFF2E7D32).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.health_and_safety_rounded,
                    color: Color(0xFF2E7D32),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Registration Successful!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your patient account has been created successfully. You can now access personalized dementia care services.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_calculatedAge != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Color(0xFF2E7D32).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline_rounded, color: Color(0xFF2E7D32), size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Age: $_calculatedAge years',
                            style: TextStyle(
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => CaregiverHomePage())
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'CONTINUE TO LOGIN',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _dateOfBirthController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }
}