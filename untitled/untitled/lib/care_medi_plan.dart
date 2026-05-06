import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MedicinePlanPage extends StatefulWidget {
  final String patientId;
  final String patientName;

  const MedicinePlanPage({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<MedicinePlanPage> createState() => _MedicinePlanPageState();
}

class _MedicinePlanPageState extends State<MedicinePlanPage> {
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
        builder: (_) => AddEditMedicinePlanPage(
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
        builder: (_) => AddEditMedicinePlanPage(
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
              ],
            ),
            SizedBox(height: 12),

            // Plan Details
            _buildPlanDetailRow('Frequency', plan['frequency'] ?? 'N/A'),
            _buildPlanDetailRow('Days', plan['days_of_week'] ?? 'N/A'),
            _buildPlanDetailRow('Period', '${plan['start_date'] ?? 'N/A'} to ${plan['end_date'] ?? 'N/A'}'),

            SizedBox(height: 8),

            // Instructions
            if (plan['instructions'] != null && plan['instructions'].toString().isNotEmpty)
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
class AddEditMedicinePlanPage extends StatefulWidget {
  final String patientId;
  final String patientName;
  final Map<String, dynamic>? plan;

  const AddEditMedicinePlanPage({
    super.key,
    required this.patientId,
    required this.patientName,
    this.plan,
  });

  @override
  State<AddEditMedicinePlanPage> createState() => _AddEditMedicinePlanPageState();
}

class _AddEditMedicinePlanPageState extends State<AddEditMedicinePlanPage> {
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

  // Radio button selections
  String? _selectedFrequency;
  String? _selectedDaysOfWeek;

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

    // Initialize radio button selections
    _selectedFrequency = plan['frequency'] ?? '';
    _selectedDaysOfWeek = plan['days_of_week'] ?? '';
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

  // Date Picker Function
  Future<void> _selectDate(TextEditingController controller) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF2E7D32),
              onPrimary: Colors.white,
              surface: Color(0xFFF8FDF8),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      String formattedDate = "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
      setState(() {
        controller.text = formattedDate;
      });
    }
  }

  // Time Picker Function
  Future<void> _selectTime(TextEditingController controller) async {
    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF2E7D32),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      // Format time as "HH:MM AM/PM"
      String period = pickedTime.period == DayPeriod.am ? 'AM' : 'PM';
      int hour = pickedTime.hourOfPeriod;
      String hourStr = hour.toString().padLeft(2, '0');
      String minuteStr = pickedTime.minute.toString().padLeft(2, '0');
      String formattedTime = "$hourStr:$minuteStr $period";

      setState(() {
        controller.text = formattedTime;
      });
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

              // Scheduled Time with Time Picker
              _buildTimePickerField(),
              const SizedBox(height: 20),

              // Frequency with Radio Buttons
              _buildFrequencyRadio(),
              const SizedBox(height: 20),

              // Days of Week with Radio Buttons
              _buildDaysOfWeekRadio(),
              const SizedBox(height: 20),

              // Start Date with Date Picker
              _buildDatePickerField(
                controller: _startDateController,
                label: 'Start Date *',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select start date';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // End Date with Date Picker (Optional)
              _buildDatePickerField(
                controller: _endDateController,
                label: 'End Date',
                isOptional: true,
              ),
              const SizedBox(height: 20),

              // Instructions
              _buildInstructionsField(),
              const SizedBox(height: 20),

              // Active Status Switch
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
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(prefixIcon, color: Color(0xFF2E7D32)),
        suffixIcon: readOnly ? Icon(Icons.arrow_drop_down, color: Color(0xFF2E7D32)) : null,
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

  Widget _buildTimePickerField() {
    return TextFormField(
      controller: _scheduledTimeController,
      readOnly: true,
      onTap: () => _selectTime(_scheduledTimeController),
      decoration: InputDecoration(
        labelText: 'Scheduled Time *',
        hintText: 'Tap to select time',
        prefixIcon: Icon(Icons.access_time_rounded, color: Color(0xFF2E7D32)),
        suffixIcon: Icon(Icons.access_time, color: Color(0xFF2E7D32)),
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
          return 'Please select scheduled time';
        }
        return null;
      },
    );
  }

  Widget _buildDatePickerField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    bool isOptional = false,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () => _selectDate(controller),
      decoration: InputDecoration(
        labelText: label,
        hintText: isOptional ? 'YYYY-MM-DD (Optional)' : 'YYYY-MM-DD',
        prefixIcon: Icon(Icons.calendar_today_rounded, color: Color(0xFF2E7D32)),
        suffixIcon: Icon(Icons.calendar_month, color: Color(0xFF2E7D32)),
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

  Widget _buildFrequencyRadio() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.repeat_rounded, color: Color(0xFF2E7D32), size: 20),
            const SizedBox(width: 8),
            Text(
              'Frequency *',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[400]!),
            color: Colors.grey[50],
          ),
          child: Column(
            children: _frequencies.map((frequency) {
              return RadioListTile<String>(
                title: Text(
                  frequency,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                  ),
                ),
                value: frequency,
                groupValue: _selectedFrequency,
                activeColor: Color(0xFF2E7D32),
                dense: true,
                visualDensity: VisualDensity.compact,
                onChanged: (String? value) {
                  setState(() {
                    _selectedFrequency = value;
                    _frequencyController.text = value ?? '';
                  });
                },
              );
            }).toList(),
          ),
        ),
        if (_selectedFrequency == null || _selectedFrequency!.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12),
            child: Text(
              'Please select frequency',
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDaysOfWeekRadio() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_view_week_rounded, color: Color(0xFF2E7D32), size: 20),
            const SizedBox(width: 8),
            Text(
              'Days of Week *',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[400]!),
            color: Colors.grey[50],
          ),
          child: Column(
            children: _daysOfWeekOptions.map((day) {
              return RadioListTile<String>(
                title: Text(
                  day,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                  ),
                ),
                value: day,
                groupValue: _selectedDaysOfWeek,
                activeColor: Color(0xFF2E7D32),
                dense: true,
                visualDensity: VisualDensity.compact,
                onChanged: (String? value) {
                  setState(() {
                    _selectedDaysOfWeek = value;
                    _daysOfWeekController.text = value ?? '';
                  });
                },
              );
            }).toList(),
          ),
        ),
        if (_selectedDaysOfWeek == null || _selectedDaysOfWeek!.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12),
            child: Text(
              'Please select days of week',
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 12,
              ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[400]!),
        color: Colors.grey[50],
      ),
      child: Row(
        children: [
          Icon(Icons.toggle_on_rounded, color: Color(0xFF2E7D32), size: 28),
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
            activeTrackColor: Color(0xFF2E7D32).withOpacity(0.5),
          ),
        ],
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      _showSnack("Please fill all required fields correctly", Colors.orange);
      return;
    }

    // Validate radio selections
    if (_selectedFrequency == null || _selectedFrequency!.isEmpty) {
      _showSnack("Please select frequency", Colors.orange);
      return;
    }

    if (_selectedDaysOfWeek == null || _selectedDaysOfWeek!.isEmpty) {
      _showSnack("Please select days of week", Colors.orange);
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
      // Convert days of week text to numbers format expected by backend
      String daysOfWeekNumbers = _convertDaysToNumbers(_selectedDaysOfWeek!);

      var request = http.MultipartRequest(
          'POST',
          Uri.parse(widget.plan == null ? '$url/add_medicine_plan/' : '$url/update_medicine_plan/')
      );

      // Add text fields
      request.fields['patient_id'] = widget.patientId;
      request.fields['medicine_id'] = _selectedMedicineId;
      request.fields['dosage'] = _dosageController.text;
      request.fields['scheduled_time'] = _scheduledTimeController.text;
      request.fields['frequency'] = _selectedFrequency ?? '';
      request.fields['days_of_week'] = daysOfWeekNumbers; // Send numbers instead of text
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

  // Convert day names to numbers (1-7) as expected by the backend
  String _convertDaysToNumbers(String daysText) {
    Map<String, String> dayToNumber = {
      'Monday': '1',
      'Tuesday': '2',
      'Wednesday': '3',
      'Thursday': '4',
      'Friday': '5',
      'Saturday': '6',
      'Sunday': '7',
    };

    if (daysText == 'Everyday') {
      return '1,2,3,4,5,6,7';
    } else if (daysText == 'Weekdays') {
      return '1,2,3,4,5';
    } else if (daysText == 'Weekends') {
      return '6,7';
    } else {
      // Single day
      return dayToNumber[daysText] ?? daysText;
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