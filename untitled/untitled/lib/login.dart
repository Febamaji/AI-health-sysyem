import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:untitled/userregister.dart';
import 'care_home.dart';
import 'userhome.dart';
import 'caretaker_reg.dart';
import 'main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.title});
  final String title;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  TextEditingController nameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  MobileScannerController cameraController = MobileScannerController();
  String _imgUrl = '';

  @override
  void initState() {
    super.initState();
    _loadImageUrl();
  }

  Future<void> _loadImageUrl() async {
    SharedPreferences sh = await SharedPreferences.getInstance();
    setState(() {
      _imgUrl = sh.getString("img_url")?.toString() ?? '';
    });
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FDF8),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 40),
                _buildHeaderSection(),
                const SizedBox(height: 60),
                _buildLoginFormCard(),
                const SizedBox(height: 40),
                _buildAdditionalOptions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF2E7D32).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.health_and_safety_rounded, size: 40, color: Colors.white),
        ),
        const SizedBox(height: 24),
        Text(
          'Welcome to MindCare Connect',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Dementia Care Management System',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF4CAF50),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginFormCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      shadowColor: Color(0xFF2E7D32).withOpacity(0.2),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Section Title
              Row(
                children: [
                  Icon(
                    Icons.medical_services_rounded,
                    color: Color(0xFF2E7D32),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Healthcare Login',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Username Field
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Username or Email',
                  hintText: 'Enter your username or email',
                  prefixIcon: Icon(Icons.person_rounded, color: Color(0xFF2E7D32)),
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w500,
                ),
                validator: (value) => value!.isEmpty ? 'Please enter username' : null,
              ),
              const SizedBox(height: 20),

              // Password Field
              TextFormField(
                controller: passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  prefixIcon: Icon(Icons.lock_rounded, color: Color(0xFF2E7D32)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      color: Colors.grey[600],
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w500,
                ),
                validator: (value) => value!.length < 3 ? 'Password must be at least 3 characters' : null,
              ),
              const SizedBox(height: 8),

              // Helper Text
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Enter your credentials to access dementia care management',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Sign In Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendData,
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
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.medical_services_rounded, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'SIGN IN',
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


              const SizedBox(height: 16),

              // Registration Options
              Text(
                'New to MindCare?',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),

              // Dual Registration Buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () => _navigateToRegister('caregiver'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Color(0xFFD32F2F),
                          side: BorderSide(color: Color(0xFFD32F2F)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.medical_services_rounded, size: 18),
                        label: Text(
                          'CAREGIVER',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Expanded(
                  //   child: SizedBox(
                  //     height: 50,
                  //     child: OutlinedButton.icon(
                  //       onPressed: () => _navigateToRegister('patient'),
                  //       style: OutlinedButton.styleFrom(
                  //         foregroundColor: Color(0xFF1976D2),
                  //         side: BorderSide(color: Color(0xFF1976D2)),
                  //         shape: RoundedRectangleBorder(
                  //           borderRadius: BorderRadius.circular(12),
                  //         ),
                  //       ),
                  //       icon: const Icon(Icons.person_rounded, size: 18),
                  //       label: Text(
                  //         'PATIENT',
                  //         style: TextStyle(
                  //           fontSize: 12,
                  //           fontWeight: FontWeight.w600,
                  //         ),
                  //       ),
                  //     ),
                  //   ),
                  // ),  // Expanded(
                  //   child: SizedBox(
                  //     height: 50,
                  //     child: OutlinedButton.icon(
                  //       onPressed: () => _navigateToRegister('patient'),
                  //       style: OutlinedButton.styleFrom(
                  //         foregroundColor: Color(0xFF1976D2),
                  //         side: BorderSide(color: Color(0xFF1976D2)),
                  //         shape: RoundedRectangleBorder(
                  //           borderRadius: BorderRadius.circular(12),
                  //         ),
                  //       ),
                  //       icon: const Icon(Icons.person_rounded, size: 18),
                  //       label: Text(
                  //         'PATIENT',
                  //         style: TextStyle(
                  //           fontSize: 12,
                  //           fontWeight: FontWeight.w600,
                  //         ),
                  //       ),
                  //     ),
                  //   ),
                  // ),  // Expanded(
                  //   child: SizedBox(
                  //     height: 50,
                  //     child: OutlinedButton.icon(
                  //       onPressed: () => _navigateToRegister('patient'),
                  //       style: OutlinedButton.styleFrom(
                  //         foregroundColor: Color(0xFF1976D2),
                  //         side: BorderSide(color: Color(0xFF1976D2)),
                  //         shape: RoundedRectangleBorder(
                  //           borderRadius: BorderRadius.circular(12),
                  //         ),
                  //       ),
                  //       icon: const Icon(Icons.person_rounded, size: 18),
                  //       label: Text(
                  //         'PATIENT',
                  //         style: TextStyle(
                  //           fontSize: 12,
                  //           fontWeight: FontWeight.w600,
                  //         ),
                  //       ),
                  //     ),
                  //   ),
                  // ),  // Expanded(
                  //   child: SizedBox(
                  //     height: 50,
                  //     child: OutlinedButton.icon(
                  //       onPressed: () => _navigateToRegister('patient'),
                  //       style: OutlinedButton.styleFrom(
                  //         foregroundColor: Color(0xFF1976D2),
                  //         side: BorderSide(color: Color(0xFF1976D2)),
                  //         shape: RoundedRectangleBorder(
                  //           borderRadius: BorderRadius.circular(12),
                  //         ),
                  //       ),
                  //       icon: const Icon(Icons.person_rounded, size: 18),
                  //       label: Text(
                  //         'PATIENT',
                  //         style: TextStyle(
                  //           fontSize: 12,
                  //           fontWeight: FontWeight.w600,
                  //         ),
                  //       ),
                  //     ),
                  //   ),
                  // ),  // Expanded(
                  //   child: SizedBox(
                  //     height: 50,
                  //     child: OutlinedButton.icon(
                  //       onPressed: () => _navigateToRegister('patient'),
                  //       style: OutlinedButton.styleFrom(
                  //         foregroundColor: Color(0xFF1976D2),
                  //         side: BorderSide(color: Color(0xFF1976D2)),
                  //         shape: RoundedRectangleBorder(
                  //           borderRadius: BorderRadius.circular(12),
                  //         ),
                  //       ),
                  //       icon: const Icon(Icons.person_rounded, size: 18),
                  //       label: Text(
                  //         'PATIENT',
                  //         style: TextStyle(
                  //           fontSize: 12,
                  //           fontWeight: FontWeight.w600,
                  //         ),
                  //       ),
                  //     ),
                  //   ),
                  // ),  // Expanded(
                  //   child: SizedBox(
                  //     height: 50,
                  //     child: OutlinedButton.icon(
                  //       onPressed: () => _navigateToRegister('patient'),
                  //       style: OutlinedButton.styleFrom(
                  //         foregroundColor: Color(0xFF1976D2),
                  //         side: BorderSide(color: Color(0xFF1976D2)),
                  //         shape: RoundedRectangleBorder(
                  //           borderRadius: BorderRadius.circular(12),
                  //         ),
                  //       ),
                  //       icon: const Icon(Icons.person_rounded, size: 18),
                  //       label: Text(
                  //         'PATIENT',
                  //         style: TextStyle(
                  //           fontSize: 12,
                  //           fontWeight: FontWeight.w600,
                  //         ),
                  //       ),
                  //     ),
                  //   ),
                  // ),  // Expanded(
                  //   child: SizedBox(
                  //     height: 50,
                  //     child: OutlinedButton.icon(
                  //       onPressed: () => _navigateToRegister('patient'),
                  //       style: OutlinedButton.styleFrom(
                  //         foregroundColor: Color(0xFF1976D2),
                  //         side: BorderSide(color: Color(0xFF1976D2)),
                  //         shape: RoundedRectangleBorder(
                  //           borderRadius: BorderRadius.circular(12),
                  //         ),
                  //       ),
                  //       icon: const Icon(Icons.person_rounded, size: 18),
                  //       label: Text(
                  //         'PATIENT',
                  //         style: TextStyle(
                  //           fontSize: 12,
                  //           fontWeight: FontWeight.w600,
                  //         ),
                  //       ),
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdditionalOptions() {
    return Column(
      children: [
        Text(
          'Healthcare Features',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildFeatureItem(Icons.health_and_safety_rounded, 'Patient Monitoring', Color(0xFF2E7D32)),
            _buildFeatureItem(Icons.medication_rounded, 'Medication Tracking', Color(0xFFD32F2F)),
            _buildFeatureItem(Icons.emergency_rounded, 'Emergency Alert', Color(0xFFF57C00)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildFeatureItem(Icons.family_restroom_rounded, 'Caregiver Support', Color(0xFF1976D2)),
            _buildFeatureItem(Icons.analytics_rounded, 'Health Analytics', Color(0xFF7B1FA2)),
            _buildFeatureItem(Icons.qr_code_rounded, 'Quick Access', Color(0xFF00796B)),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String text, Color color) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: color, size: 32),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }


  // ---------------- LOGIN LOGIC ----------------
// ---------------- LOGIN LOGIC ----------------
  Future<void> _loginWithCredentials(String username, String password) async {
    setState(() => _isLoading = true);

    SharedPreferences sh = await SharedPreferences.getInstance();
    String url = sh.getString('url')?.toString() ?? '';

    if (url.isEmpty) {
      Fluttertoast.showToast(
        msg: 'Server URL not configured',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      setState(() => _isLoading = false);
      return;
    }

    final urls = Uri.parse('$url/user_login/');

    try {
      final response = await http.post(
          urls,
          body: {
            'username': username,
            'password': password
          }
      ).timeout(Duration(seconds: 30));

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("Login response: $data");

        if (data['status'] == 'ok') {
          // Save user data to shared preferences
          await sh.setString("lid", data['lid'].toString());
          await sh.setString("uname", data['name'].toString());
          await sh.setString("uphoto", data['photo']?.toString() ?? '');
          await sh.setString("user_type", data['type']?.toString() ?? '');

          _showSuccessDialog(data['type'].toString(), data['name'].toString());

        } else {
          Fluttertoast.showToast(
            msg: data['message'] ?? 'Invalid credentials',
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
      } else {
        Fluttertoast.showToast(
          msg: 'Server error: ${response.statusCode}',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print("Login error: $e");
      Fluttertoast.showToast(
        msg: 'Connection Error: ${e.toString()}',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(String userType, String userName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
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
                'Welcome $userName!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5E20),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'User Type: $userType',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You have successfully signed in to MindCare Connect',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    _navigateToHomePage(userType);
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
                    'CONTINUE TO DASHBOARD',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToHomePage(String userType) {
    if (userType.toLowerCase() == 'caretaker') {
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => CaregiverHomePage())
      );
    } else {
      // Navigate to patient home page if you have one
      Fluttertoast.showToast(
        msg: 'Patient dashboard coming soon',
        backgroundColor: Colors.blue,
        textColor: Colors.white,
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PatientHomePage())
      );
    }
  }
  void _sendData() async {
    if (_formKey.currentState!.validate()) {
      await _loginWithCredentials(nameController.text.trim(), passwordController.text.trim());
    }
  }

  void _navigateToRegister(String userType) {
    if (userType == 'caregiver') {
      Navigator.push(context, MaterialPageRoute(builder: (context) => CaregiverRegisterPage()));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (context) => PatientRegisterPage()));
    }

    // Show temporary message
    Fluttertoast.showToast(
      msg: 'Navigate to ${userType == 'caregiver' ? 'Caregiver' : 'Patient'} Registration',
      backgroundColor: Color(0xFF2E7D32),
      textColor: Colors.white,
    );
  }

}

// ---------------- Full Image Viewer ----------------
class FullImageView extends StatelessWidget {
  final String imageUrl;
  const FullImageView({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Medical Document'),
        elevation: 0,),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_rounded, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Unable to load medical document',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}