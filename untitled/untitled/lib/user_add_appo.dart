import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class user_DoctorAppointmentPage extends StatefulWidget {
  final String patientId;
  final String patientName;

  const user_DoctorAppointmentPage({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<user_DoctorAppointmentPage> createState() => _user_DoctorAppointmentPageState();
}

class _user_DoctorAppointmentPageState extends State<user_DoctorAppointmentPage> {
  List<dynamic> _appointments = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String url = prefs.getString("url") ?? "";

    if (url.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    try {
      final response = await http.get(
          Uri.parse('$url/view_appointments/?patient_id=${widget.patientId}')
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'ok') {
          setState(() {
            _appointments = data['data'];
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
      print("Error loading appointments: $e");
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _deleteAppointment(String appointmentId, String doctorName) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Delete'),
        content: Text('Are you sure you want to delete the appointment with Dr. $doctorName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _confirmDelete(appointmentId);
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

  Future<void> _confirmDelete(String appointmentId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String url = prefs.getString("url") ?? "";

    try {
      final response = await http.post(
          Uri.parse('$url/delete_appointment/'),
          body: {'appointment_id': appointmentId}
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'ok') {
          Fluttertoast.showToast(
            msg: 'Appointment deleted successfully',
            backgroundColor: Colors.green,
            textColor: Colors.white,
          );
          _loadAppointments(); // Refresh the list
        } else {
          Fluttertoast.showToast(
            msg: 'Failed to delete appointment',
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error deleting appointment',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  void _editAppointment(Map<String, dynamic> appointment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditAppointmentPage(
          patientId: widget.patientId,
          patientName: widget.patientName,
          appointment: appointment,
        ),
      ),
    ).then((_) => _loadAppointments());
  }

  void _addNewAppointment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditAppointmentPage(
          patientId: widget.patientId,
          patientName: widget.patientName,
        ),
      ),
    ).then((_) => _loadAppointments());
  }

  void _showAppointmentDetails(Map<String, dynamic> appointment) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Appointment Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5E20),
                ),
              ),
              SizedBox(height: 16),
              _buildDetailRow('ID', appointment['id'].toString()),
              _buildDetailRow('Doctor', appointment['doctor_name'] ?? 'N/A'),
              _buildDetailRow('Specialization', appointment['doctor_specialization'] ?? 'N/A'),
              _buildDetailRow('Hospital', appointment['hospital_name'] ?? 'N/A'),
              _buildDetailRow('Date', appointment['appointment_date'] ?? 'N/A'),
              _buildDetailRow('Time', appointment['appointment_time'] ?? 'N/A'),
              _buildDetailRow('Contact', appointment['contact_phone'] ?? 'N/A'),
              _buildDetailRow('Purpose', appointment['purpose'] ?? 'N/A'),
              if (appointment['notes'] != null && appointment['notes'].isNotEmpty)
                _buildDetailRow('Notes', appointment['notes'] ?? 'N/A'),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Close'),
                ),
              ),
            ],
          ),
        ),
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

  Color _getAppointmentStatusColor(String appointmentDate) {
    final now = DateTime.now();
    final appointment = DateTime.tryParse(appointmentDate);

    if (appointment == null) return Colors.grey;

    if (appointment.isBefore(now)) {
      return Colors.green; // Past appointment
    } else if (appointment.isAfter(now)) {
      return Color(0xFF2E7D32); // Upcoming appointment
    } else {
      return Colors.orange; // Today's appointment
    }
  }

  String _getAppointmentStatusText(String appointmentDate) {
    final now = DateTime.now();
    final appointment = DateTime.tryParse(appointmentDate);

    if (appointment == null) return 'Unknown';

    if (appointment.isBefore(now)) {
      return 'Completed';
    } else if (appointment.isAfter(now)) {
      return 'Upcoming';
    } else {
      return 'Today';
    }
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
          'Doctor Appointments - ${widget.patientName}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded),
            onPressed: _loadAppointments,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewAppointment,
        backgroundColor: Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        child: Icon(Icons.add_rounded),
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
              'Loading appointments...',
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
              'Failed to load appointments',
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
              onPressed: _loadAppointments,
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

    if (_appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No Appointments Found',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Add appointments to manage doctor visits',
              style: TextStyle(
                color: Colors.grey[500],
              ),),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _addNewAppointment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF2E7D32),
                ),
                 child: Text('Add New Appointment'),
              ),


          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _appointments.length,
      itemBuilder: (context, index) {
        final appointment = _appointments[index];
        return _buildAppointmentCard(appointment);
      },
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    Color statusColor = _getAppointmentStatusColor(appointment['appointment_date'] ?? '');
    String statusText = _getAppointmentStatusText(appointment['appointment_date'] ?? '');

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
                    Icons.medical_services_rounded,
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
                        appointment['doctor_name'] ?? 'Unknown Doctor',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        appointment['doctor_specialization'] ?? 'General Practitioner',
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
                      _showAppointmentDetails(appointment);
                    } else if (value == 'edit') {
                      _editAppointment(appointment);
                    } else if (value == 'delete') {
                      _deleteAppointment(
                        appointment['id'].toString(),
                        appointment['doctor_name'] ?? 'Unknown',
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
                          Text('View Details'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_rounded, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12),

            // Appointment Details
            _buildAppointmentDetailRow('Hospital', appointment['hospital_name'] ?? 'N/A'),
            _buildAppointmentDetailRow('Date', _formatDate(appointment['appointment_date'] ?? '')),
            _buildAppointmentDetailRow('Time', appointment['appointment_time'] ?? 'N/A'),
            _buildAppointmentDetailRow('Contact', appointment['contact_phone'] ?? 'N/A'),
            _buildAppointmentDetailRow('Purpose', appointment['purpose'] ?? 'N/A'),

            SizedBox(height: 8),

            // Status Badge
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            SizedBox(height: 8),

            // Notes
            if (appointment['notes'] != null && appointment['notes'].isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notes:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    appointment['notes'],
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),

            SizedBox(height: 12),

            // Action Buttons - Edit and Delete
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _editAppointment(appointment),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: BorderSide(color: Colors.blue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: Icon(Icons.edit_rounded, size: 16),
                    label: Text('Edit'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteAppointment(
                      appointment['id'].toString(),
                      appointment['doctor_name'] ?? 'Unknown',
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

  Widget _buildAppointmentDetailRow(String label, String value) {
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
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}

// Add/Edit Appointment Page
class AddEditAppointmentPage extends StatefulWidget {
  final String patientId;
  final String patientName;
  final Map<String, dynamic>? appointment;

  const AddEditAppointmentPage({
    super.key,
    required this.patientId,
    required this.patientName,
    this.appointment,
  });

  @override
  State<AddEditAppointmentPage> createState() => _AddEditAppointmentPageState();
}

class _AddEditAppointmentPageState extends State<AddEditAppointmentPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _doctorNameController = TextEditingController();
  final TextEditingController _specializationController = TextEditingController();
  final TextEditingController _hospitalController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.appointment != null) {
      _initializeForm();
    }
  }

  void _initializeForm() {
    final appointment = widget.appointment!;
    _doctorNameController.text = appointment['doctor_name'] ?? '';
    _specializationController.text = appointment['doctor_specialization'] ?? '';
    _hospitalController.text = appointment['hospital_name'] ?? '';
    _dateController.text = appointment['appointment_date'] ?? '';
    _timeController.text = appointment['appointment_time'] ?? '';
    _phoneController.text = appointment['contact_phone'] ?? '';
    _purposeController.text = appointment['purpose'] ?? '';
    _notesController.text = appointment['notes'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FDF8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1B5E20),
        elevation: 0,
        title: Text(
          widget.appointment == null ? 'Add Appointment' : 'Edit Appointment',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              _buildHeaderSection(),
              const SizedBox(height: 32),
              _buildAppointmentForm(),
            ],
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
            color: Color(0xFF2E7D32).withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: Color(0xFF2E7D32),
              width: 2,
            ),
          ),
          child: Icon(
            Icons.calendar_today_rounded,
            size: 50,
            color: Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.appointment == null ? 'New Doctor Appointment' : 'Edit Appointment',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'For Patient: ${widget.patientName}',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentForm() {
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
                    'Appointment Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Doctor Name
              _buildFormField(
                controller: _doctorNameController,
                label: 'Doctor Name *',
                hint: 'Enter doctor\'s full name',
                prefixIcon: Icons.person_rounded,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter doctor name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Specialization
              _buildFormField(
                controller: _specializationController,
                label: 'Specialization *',
                hint: 'e.g., Cardiologist, Neurologist, General Practitioner',
                prefixIcon: Icons.work_rounded,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter specialization';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Hospital Name
              _buildFormField(
                controller: _hospitalController,
                label: 'Hospital/Clinic Name *',
                hint: 'Enter hospital or clinic name',
                prefixIcon: Icons.local_hospital_rounded,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter hospital name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Appointment Date
              _buildFormField(
                controller: _dateController,
                label: 'Appointment Date *',
                hint: 'YYYY-MM-DD',
                prefixIcon: Icons.calendar_today_rounded,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter appointment date';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Appointment Time
              _buildFormField(
                controller: _timeController,
                label: 'Appointment Time *',
                hint: 'e.g., 10:00 AM, 02:30 PM',
                prefixIcon: Icons.access_time_rounded,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter appointment time';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Contact Phone
              _buildFormField(
                controller: _phoneController,
                label: 'Contact Phone *',
                hint: 'Enter doctor\'s or hospital phone number',
                prefixIcon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter contact phone';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Purpose
              _buildFormField(
                controller: _purposeController,
                label: 'Purpose *',
                hint: 'e.g., Regular checkup, Consultation, Follow-up',
                prefixIcon: Icons.description_rounded,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter appointment purpose';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Notes
              _buildNotesField(),
              const SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  // Cancel Button
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Color(0xFF2E7D32),
                          side: BorderSide(color: Color(0xFF2E7D32)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'CANCEL',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Save Button
                  Expanded(
                    child: SizedBox(
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
                            // Icon(Icons.save_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              widget.appointment == null ? 'SAVE' : 'UPDATE',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
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

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notes',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Enter any additional notes or instructions...',
            alignLabelWithHint: true,
            prefixIcon: Icon(Icons.note_rounded, color: Color(0xFF2E7D32)),
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
        ),
      ],
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      _showSnack("Please fill all required fields correctly", Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String url = prefs.getString("url") ?? "";
    if (url.isEmpty) {
      _showSnack("Server configuration not found", Colors.red);
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      var request = http.MultipartRequest(
          'POST',
          Uri.parse(widget.appointment == null ? '$url/add_appointment/' : '$url/update_appointment/')
      );

      // Add text fields
      request.fields['patient_id'] = widget.patientId;
      request.fields['doctor_name'] = _doctorNameController.text;
      request.fields['doctor_specialization'] = _specializationController.text;
      request.fields['hospital_name'] = _hospitalController.text;
      request.fields['appointment_date'] = _dateController.text;
      request.fields['appointment_time'] = _timeController.text;
      request.fields['contact_phone'] = _phoneController.text;
      request.fields['purpose'] = _purposeController.text;
      request.fields['notes'] = _notesController.text;

      if (widget.appointment != null) {
        request.fields['appointment_id'] = widget.appointment!['id'].toString();
      }

      var response = await request.send();
      var responseBody = await http.Response.fromStream(response);

      if (response.statusCode == 200) {
        var jsonData = json.decode(responseBody.body);
        print("Appointment ${widget.appointment == null ? 'added' : 'updated'} successfully: $jsonData");
        _showSuccessDialog();
      } else {
        print("Failed: ${responseBody.body}");
        _showSnack("Failed to ${widget.appointment == null ? 'add' : 'update'} appointment: ${responseBody.body}", Colors.red);
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
                    Icons.verified_rounded,
                    color: Color(0xFF2E7D32),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Appointment ${widget.appointment == null ? 'Added' : 'Updated'} Successfully!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'The appointment has been ${widget.appointment == null ? 'scheduled' : 'updated'} successfully.',
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
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'BACK TO APPOINTMENTS',
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
    _doctorNameController.dispose();
    _specializationController.dispose();
    _hospitalController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _phoneController.dispose();
    _purposeController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}