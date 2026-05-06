import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class userMedicinePlanPage extends StatefulWidget {
  final String patientId;
  final String patientName;

  const userMedicinePlanPage({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<userMedicinePlanPage> createState() => _userMedicinePlanPageState();
}

class _userMedicinePlanPageState extends State<userMedicinePlanPage> {
  List<dynamic> _medicinePlans = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadMedicinePlans();
  }

  Future<void> _loadMedicinePlans() async {
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
          Uri.parse('$url/view_medicine_plans/?patient_id=${widget.patientId}')
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'ok') {
          setState(() {
            _medicinePlans = data['data'];
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
      print("Error loading medicine plans: $e");
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _deleteMedicinePlan(String planId, String medicineName) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Delete'),
        content: Text('Are you sure you want to delete the medicine plan for $medicineName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _confirmDelete(planId);
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

  Future<void> _confirmDelete(String planId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String url = prefs.getString("url") ?? "";

    try {
      final response = await http.post(
          Uri.parse('$url/delete_medicine_plan/'),
          body: {'plan_id': planId}
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'ok') {
          Fluttertoast.showToast(
            msg: 'Medicine plan deleted successfully',
            backgroundColor: Colors.green,
            textColor: Colors.white,
          );
          _loadMedicinePlans(); // Refresh the list
        } else {
          Fluttertoast.showToast(
            msg: 'Failed to delete medicine plan',
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error deleting medicine plan',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  void _editMedicinePlan(Map<String, dynamic> plan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEdituserMedicinePlanPage(
          patientId: widget.patientId,
          patientName: widget.patientName,
          plan: plan,
        ),
      ),
    ).then((_) => _loadMedicinePlans());
  }

  void _addNewMedicinePlan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEdituserMedicinePlanPage(
          patientId: widget.patientId,
          patientName: widget.patientName,
        ),
      ),
    ).then((_) => _loadMedicinePlans());
  }

  void _showMedicinePlanDetails(Map<String, dynamic> plan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Medicine Plan Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('ID', plan['id'].toString()),
              _buildDetailRow('Medicine', plan['medicine_name'] ?? 'N/A'),
              _buildDetailRow('Dosage', plan['dosage'] ?? 'N/A'),
              _buildDetailRow('Scheduled Time', plan['scheduled_time'] ?? 'N/A'),
              _buildDetailRow('Frequency', plan['frequency'] ?? 'N/A'),
              _buildDetailRow('Days of Week', plan['days_of_week'] ?? 'N/A'),
              _buildDetailRow('Status', plan['is_active'] == '1' ? 'Active' : 'Inactive'),
              _buildDetailRow('Start Date', plan['start_date'] ?? 'N/A'),
              _buildDetailRow('End Date', plan['end_date'] ?? 'N/A'),
              _buildDetailRow('Instructions', plan['instructions'] ?? 'N/A'),
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

  Color _getStatusColor(String isActive) {
    return isActive == '1' ? Color(0xFF2E7D32) : Colors.grey;
  }

  String _getStatusText(String isActive) {
    return isActive == '1' ? 'Active' : 'Inactive';
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
          'Medicine Plans - ${widget.patientName}',
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
            onPressed: _loadMedicinePlans,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(Icons.add_rounded),
            onPressed: _addNewMedicinePlan,
            tooltip: 'Add New Plan',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewMedicinePlan,
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
              'Loading medicine plans...',
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
              'Failed to load medicine plans',
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
              onPressed: _loadMedicinePlans,
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

    if (_medicinePlans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medical_services_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No Medicine Plans Found',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Add medicine plans to manage patient medications',
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _addNewMedicinePlan,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2E7D32),
                foregroundColor: Colors.white,
              ),
              child: Text('Add New Medicine Plan'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _medicinePlans.length,
      itemBuilder: (context, index) {
        final plan = _medicinePlans[index];
        return _buildMedicinePlanCard(plan);
      },
    );
  }

  Widget _buildMedicinePlanCard(Map<String, dynamic> plan) {
    Color statusColor = _getStatusColor(plan['is_active']?.toString() ?? '0');
    String statusText = _getStatusText(plan['is_active']?.toString() ?? '0');

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
                    Icons.medication_rounded,
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
                        plan['medicine_name'] ?? 'Unknown Medicine',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${plan['dosage'] ?? 'N/A'} • ${plan['scheduled_time'] ?? 'N/A'}',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
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
              ],
            ),
            SizedBox(height: 12),

            // Plan Details
            _buildPlanDetailRow('Frequency', plan['frequency'] ?? 'N/A'),
            _buildPlanDetailRow('Days', plan['days_of_week'] ?? 'N/A'),
            _buildPlanDetailRow('Period', '${plan['start_date'] ?? 'N/A'} to ${plan['end_date'] ?? 'N/A'}'),

            SizedBox(height: 8),

            // Instructions
            if (plan['instructions'] != null && plan['instructions'].isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instructions:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    plan['instructions'],
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
                    onPressed: () => _editMedicinePlan(plan),
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
                    onPressed: () => _deleteMedicinePlan(
                      plan['id'].toString(),
                      plan['medicine_name'] ?? 'Unknown',
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

  Widget _buildPlanDetailRow(String label, String value) {
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

// Add/Edit Medicine Plan Page
class AddEdituserMedicinePlanPage extends StatefulWidget {
  final String patientId;
  final String patientName;
  final Map<String, dynamic>? plan;

  const AddEdituserMedicinePlanPage({
    super.key,
    required this.patientId,
    required this.patientName,
    this.plan,
  });

  @override
  State<AddEdituserMedicinePlanPage> createState() => _AddEdituserMedicinePlanPageState();
}

class _AddEdituserMedicinePlanPageState extends State<AddEdituserMedicinePlanPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _scheduledTimeController = TextEditingController();
  final TextEditingController _frequencyController = TextEditingController();
  final TextEditingController _daysOfWeekController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();

  String _selectedMedicineId = '';
  bool _isActive = true;
  bool _isLoading = false;
  List<dynamic> _medicines = [];

  final List<String> _frequencies = [
    'Once Daily',
    'Twice Daily',
    'Three Times Daily',
    'Four Times Daily',
    'As Needed',
    'Every 4 Hours',
    'Every 6 Hours',
    'Every 8 Hours',
    'Every 12 Hours',
    'Weekly',
    'Monthly'
  ];

  final List<String> _daysOfWeekOptions = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
    'Everyday',
    'Weekdays',
    'Weekends'
  ];

  @override
  void initState() {
    super.initState();
    _loadMedicines();
    if (widget.plan != null) {
      _initializeForm();
    }
  }

  void _initializeForm() {
    final plan = widget.plan!;
    _dosageController.text = plan['dosage'] ?? '';
    _scheduledTimeController.text = plan['scheduled_time'] ?? '';
    _frequencyController.text = plan['frequency'] ?? '';
    _daysOfWeekController.text = plan['days_of_week'] ?? '';
    _startDateController.text = plan['start_date'] ?? '';
    _endDateController.text = plan['end_date'] ?? '';
    _instructionsController.text = plan['instructions'] ?? '';
    _selectedMedicineId = plan['MEDICINE_id']?.toString() ?? '';
    _isActive = plan['is_active'] == '1';
  }

  Future<void> _loadMedicines() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String url = prefs.getString("url") ?? "";

    try {
      final response = await http.get(Uri.parse('$url/view_medicines/?pid=${widget.patientId}'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'ok') {
          setState(() {
            _medicines = data['data'];
          });
        }
      }
    } catch (e) {
      print("Error loading medicines: $e");
    }
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
          widget.plan == null ? 'Add Medicine Plan' : 'Edit Medicine Plan',
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
              _buildMedicinePlanForm(),
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
            Icons.medical_services_rounded,
            size: 50,
            color: Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.plan == null ? 'Add Medicine Plan' : 'Edit Medicine Plan',
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

  Widget _buildMedicinePlanForm() {
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
              // Medicine Selection
              _buildMedicineDropdown(),
              const SizedBox(height: 20),

              // Dosage
              _buildFormField(
                controller: _dosageController,
                label: 'Dosage *',
                hint: 'e.g., 1 tablet, 5ml, 2 drops',
                prefixIcon: Icons.scale_rounded,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter dosage';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Scheduled Time
              _buildFormField(
                controller: _scheduledTimeController,
                label: 'Scheduled Time *',
                hint: 'e.g., 08:00 AM, 02:00 PM, 10:00 PM',
                prefixIcon: Icons.access_time_rounded,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter scheduled time';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Frequency
              _buildFrequencyDropdown(),
              const SizedBox(height: 20),

              // Days of Week
              _buildDaysOfWeekDropdown(),
              const SizedBox(height: 20),

              // Start Date
              _buildFormField(
                controller: _startDateController,
                label: 'Start Date *',
                hint: 'YYYY-MM-DD',
                prefixIcon: Icons.calendar_today_rounded,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter start date';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // End Date
              _buildFormField(
                controller: _endDateController,
                label: 'End Date',
                hint: 'YYYY-MM-DD (Optional)',
                prefixIcon: Icons.calendar_today_rounded,
              ),
              const SizedBox(height: 20),

              // Instructions
              _buildInstructionsField(),
              const SizedBox(height: 20),

              // Active Status
              _buildActiveStatusSwitch(),
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
                            Icon(Icons.save_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              widget.plan == null ? 'SAVE' : 'UPDATE',
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
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

  Widget _buildMedicineDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Medicine *',
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
            value: _selectedMedicineId.isEmpty ? null : _selectedMedicineId,
            items: _medicines.map((medicine) {
              return DropdownMenuItem<String>(
                value: medicine['id'].toString(),
                child: Text(
                  '${medicine['name']} (${medicine['dosage_strength']})',
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedMedicineId = newValue!;
              });
            },
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.medication_rounded, color: Color(0xFF2E7D32)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[800],
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a medicine';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFrequencyDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Frequency *',
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
            value: _frequencyController.text.isEmpty ? null : _frequencyController.text,
            items: _frequencies.map((String frequency) {
              return DropdownMenuItem<String>(
                value: frequency,
                child: Text(
                  frequency,
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _frequencyController.text = newValue!;
              });
            },
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.repeat_rounded, color: Color(0xFF2E7D32)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[800],
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select frequency';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDaysOfWeekDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Days of Week *',
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
            value: _daysOfWeekController.text.isEmpty ? null : _daysOfWeekController.text,
            items: _daysOfWeekOptions.map((String day) {
              return DropdownMenuItem<String>(
                value: day,
                child: Text(
                  day,
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _daysOfWeekController.text = newValue!;
              });
            },
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.calendar_view_week_rounded, color: Color(0xFF2E7D32)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[800],
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select days of week';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Instructions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _instructionsController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Enter special instructions, precautions, etc.',
            alignLabelWithHint: true,
            prefixIcon: Icon(Icons.description_rounded, color: Color(0xFF2E7D32)),
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

  Widget _buildActiveStatusSwitch() {
    return Row(
      children: [
        Icon(Icons.toggle_on_rounded, color: Color(0xFF2E7D32)),
        SizedBox(width: 12),
        Text(
          'Active Plan',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        Spacer(),
        Switch(
          value: _isActive,
          onChanged: (value) {
            setState(() {
              _isActive = value;
            });
          },
          activeColor: Color(0xFF2E7D32),
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
          Uri.parse(widget.plan == null ? '$url/add_medicine_plan/' : '$url/update_medicine_plan/')
      );

      // Add text fields
      request.fields['patient_id'] = widget.patientId;
      request.fields['medicine_id'] = _selectedMedicineId;
      request.fields['dosage'] = _dosageController.text;
      request.fields['scheduled_time'] = _scheduledTimeController.text;
      request.fields['frequency'] = _frequencyController.text;
      request.fields['days_of_week'] = _daysOfWeekController.text;
      request.fields['is_active'] = _isActive ? '1' : '0';
      request.fields['start_date'] = _startDateController.text;
      request.fields['end_date'] = _endDateController.text;
      request.fields['instructions'] = _instructionsController.text;

      if (widget.plan != null) {
        request.fields['plan_id'] = widget.plan!['id'].toString();
      }

      var response = await request.send();
      var responseBody = await http.Response.fromStream(response);

      if (response.statusCode == 200) {
        var jsonData = json.decode(responseBody.body);
        print("Medicine plan ${widget.plan == null ? 'added' : 'updated'} successfully: $jsonData");
        _showSuccessDialog();
      } else {
        print("Failed: ${responseBody.body}");
        _showSnack("Failed to ${widget.plan == null ? 'add' : 'update'} medicine plan: ${responseBody.body}", Colors.red);
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
                  'Medicine Plan ${widget.plan == null ? 'Added' : 'Updated'} Successfully!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'The medicine plan has been ${widget.plan == null ? 'created' : 'updated'} successfully for patient care management.',
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
                      'BACK TO MEDICINE PLANS',
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
    _dosageController.dispose();
    _scheduledTimeController.dispose();
    _frequencyController.dispose();
    _daysOfWeekController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }
}