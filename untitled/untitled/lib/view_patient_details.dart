import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'add_emergency_contact.dart';
import 'care_add_medicine.dart';
import 'care_medi_plan.dart';
import 'doctor_app.dart';

class ViewPatientsPage extends StatefulWidget {
  const ViewPatientsPage({super.key});

  @override
  State<ViewPatientsPage> createState() => _ViewPatientsPageState();
}

class _ViewPatientsPageState extends State<ViewPatientsPage> {
  List<dynamic> _patients = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
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
      final response = await http.get(Uri.parse('$url/view_patients/?lid=$lid'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'ok') {
          setState(() {
            _patients = data['data'];
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      print("Error loading patients: $e");
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _deletePatient(String patientId, String patientName) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Delete'),
        content: Text('Are you sure you want to delete patient $patientName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _confirmDelete(patientId);
            },
            child: Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(String patientId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String url = prefs.getString("url") ?? "";

    try {
      final response = await http.post(
          Uri.parse('$url/delete_patient/'),
          body: {'patient_id': patientId}
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          Fluttertoast.showToast(
            msg: 'Patient deleted successfully',
            backgroundColor: Colors.green,
            textColor: Colors.white,
          );
          _loadPatients(); // Refresh the list
        } else {
          Fluttertoast.showToast(
            msg: 'Failed to delete patient',
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error deleting patient',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  void _showPatientDetails(Map<String, dynamic> patient) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Patient Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('ID', patient['id'].toString()),
              _buildDetailRow('Name', patient['NAME'] ?? 'N/A'),
              _buildDetailRow('Phone', patient['PHONE_NUMBER'] ?? 'N/A'),
              _buildDetailRow('Date of Birth', patient['DATE_OF_BIRTH'] ?? 'N/A'),
              _buildDetailRow('Gender', patient['GENDER'] ?? 'N/A'),
              _buildDetailRow('Email', patient['EMAIL'] ?? 'N/A'),
              _buildDetailRow('Relationship', patient['relationship'] ?? 'N/A'),
              _buildDetailRow('Sleep Start', patient['sleep_start_time'] ?? 'Not set'),
              _buildDetailRow('Sleep End', patient['sleep_end_time'] ?? 'Not set'),
              _buildDetailRow('Address', patient['ADDRESS'] ?? 'N/A'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showMedicineDetails(Map<String, dynamic> patient) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => AddMedicinePage(pid:patient['id'].toString())));

  }

  Widget _buildMedicineSection(Map<String, dynamic> patient) {
    // Placeholder for medicine list
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey),
      ),
      child: Column(
        children: [
          Icon(
            Icons.medication_rounded,
            size: 40,
            color: Colors.grey[400],
          ),
          SizedBox(height: 8),
          Text(
            'No medicines added yet',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Add medicines to track patient medication',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _addNewMedicine(Map<String, dynamic> patient) {
    Navigator.pop(context); // Close current dialog
    // Navigate to add medicine page
    // Navigator.push(context, MaterialPageRoute(
    //   builder: (_) => AddMedicinePage(patientId: patient['id'])
    // ));

    // For now, show a message
    Fluttertoast.showToast(
      msg: 'Navigate to Add Medicine for ${patient['NAME']}',
      backgroundColor: Color(0xFF2E7D32),
      textColor: Colors.white,
    );
  }

  void _viewMedicineLog(Map<String, dynamic> patient) {
    Navigator.pop(context); // Close current dialog
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Medicine Log - ${patient['NAME']}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5E20),
                ),
              ),
              SizedBox(height: 16),
              _buildMedicineLogList(patient),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                ),
                child: Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedicineLogList(Map<String, dynamic> patient) {
    // Placeholder for medicine log
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey),
      ),
      child: Column(
        children: [
          Icon(
            Icons.history_rounded,
            size: 40,
            color: Colors.grey[400],
          ),
          SizedBox(height: 8),
          Text(
            'No medicine log available',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Medicine administration log will appear here',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
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
          'Manage Patients',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded),
            onPressed: _loadPatients,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
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
              'Loading patients...',
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
              'Failed to load patients',
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
              onPressed: _loadPatients,
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

    if (_patients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No Patients Found',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Add patients to get started',
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _patients.length,
      itemBuilder: (context, index) {
        final patient = _patients[index];
        return _buildPatientCard(patient);
      },
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    return Card(
      elevation: 3,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Color(0xFF2E7D32).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: Color(0xFF2E7D32),
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient['NAME'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        patient['PHONE_NUMBER'] ?? 'No phone',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: Colors.grey[600]),
                  onSelected: (value) {
                    if (value == 'view') {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => DoctorAppointmentPage(patientId:patient['id'].toString(), patientName: patient['NAME'],)));
                    } else if (value == 'medicineplan') {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => MedicinePlanPage(patientId:patient['id'].toString(), patientName: patient['NAME'],)));

                    } else if (value == 'delete') {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => DoctorAppointmentPage(patientId:patient['id'].toString(), patientName: patient['NAME'],)));

                    }
                    else if (value == 'Emergency') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EmergencyContactsPage(
                            patientId:patient['id'].toString(), // Convert to int
                            patientName: patient['NAME'] ?? '',
                          ),
                        ),
                      );
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_rounded, color: Color(0xFF1B5E20)),
                          SizedBox(width: 8),
                          Text('View Appointment'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'medicineplan',
                      child: Row(
                        children: [
                          Icon(Icons.medication_rounded, color: Color(0xFF2E7D32)),
                          SizedBox(width: 8),
                          Text('Medicine Plan'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'Emergency',
                      child: Row(
                        children: [
                          Icon(Icons.medication_rounded, color: Color(0xFF2E7D32)),
                          SizedBox(width: 8),
                          Text('Emergency'),
                        ],
                      ),
                    ),

                  ],
                ),
              ],
            ),
            SizedBox(height: 12),

            // Patient Details
            _buildPatientDetailRow('ID', patient['id'].toString()),
            _buildPatientDetailRow('Date of Birth', patient['DATE_OF_BIRTH'] ?? 'N/A'),
            _buildPatientDetailRow('Gender', patient['GENDER'] ?? 'N/A'),
            _buildPatientDetailRow('Email', patient['EMAIL'] ?? 'N/A'),
            _buildPatientDetailRow('Relationship', patient['relationship'] ?? 'N/A'),
            _buildPatientDetailRow('Sleep Hours',
                '${patient['sleep_start_time'] ?? 'Not set'} - ${patient['sleep_end_time'] ?? 'Not set'}'
            ),

            SizedBox(height: 12),

            // Address
            if (patient['ADDRESS'] != null && patient['ADDRESS'].isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Address:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    patient['ADDRESS'],
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),

            SizedBox(height: 12),

            // Action Buttons - Only Delete and Medicine Management
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showMedicineDetails(patient),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: Icon(Icons.medication_rounded, size: 16),
                    label: Text('Medicine'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deletePatient(
                      patient['id'].toString(),
                      patient['NAME'] ?? 'Unknown',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: Icon(Icons.delete_rounded, size: 16),
                    label: Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}