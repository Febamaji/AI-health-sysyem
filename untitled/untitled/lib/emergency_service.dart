import 'dart:async';
import 'package:intl/intl.dart';
import 'package:shake/shake.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:vibration/vibration.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pedometer/pedometer.dart';
import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';

class EmergencyService {
  static final EmergencyService _instance = EmergencyService._internal();
  factory EmergencyService() => _instance;
  EmergencyService._internal();

  // Shake detection
  ShakeDetector? _shakeDetector;
  DateTime _lastShakeTime = DateTime.now();
  static const int SHAKE_COOLDOWN_SECONDS = 10;

  // Activity monitoring
  StreamSubscription<StepCount>? _stepCountSubscription;
  DateTime _lastStepTime = DateTime.now();
  Timer? _inactivityTimer;
  Duration _inactivityThreshold = const Duration(minutes: 30);

  // Emergency contacts
  List<Map<String, dynamic>> _emergencyContacts = [];
  bool _isInitialized = false;

  // Telephony for SMS
  final Telephony _telephony = Telephony.instance;

  // Callback to show alerts in UI
  Function(String)? onEmergencyAlert;

  // NEW: Face emotion check callback
  Future<String> Function(String)? faceCheckCallback;

  // Background task tracking
  bool _isSendingInBackground = false;

  // Getter for emergency contacts
  List<Map<String, dynamic>> get emergencyContacts => List.from(_emergencyContacts);

  // UPDATED: Initialize method now accepts faceCheckCallback
  Future<void> initialize({
    Function(String)? alertCallback,
    Future<String> Function(String)? faceCheckCallback,
  }) async {
    if (_isInitialized) {
      print('⚠️ Emergency service already initialized');
      return;
    }

    try {
      onEmergencyAlert = alertCallback;
      this.faceCheckCallback = faceCheckCallback; // NEW: Store face check callback
      await _loadEmergencyContacts();
      await _requestPermissions();
      await _startShakeDetection();
      await _startActivityMonitoring();

      _isInitialized = true;
      print('✅ Emergency service initialized successfully');
    } catch (e) {
      print('❌ Error initializing emergency service: $e');
      rethrow;
    }
  }

  // UPDATED: Trigger emergency alert with face check
  Future<void> _triggerEmergencyAlert(String type) async {
    print('🚨 Emergency alert triggered: $type');

    // NEW: Check face emotion before sending alert
    if (faceCheckCallback != null) {
      try {
        print('🎭 Checking face emotion before sending alert...');
        final emotionResult = await faceCheckCallback!(type);

        if (emotionResult == 'ok') {
          print('✅ User is okay, not sending emergency alert');
          return;
        } else if (emotionResult == 'not_ok') {
          print('🆘 User needs help, sending emergency alert');
        } else if (emotionResult == 'timeout') {
          print('⏰ Face check timeout, sending emergency alert as precaution');
        }
      } catch (e) {
        print('❌ Error in face check: $e, proceeding with alert');
      }
    } else {
      print('ℹ️ Face check callback not available, proceeding with alert');
    }

    // Show UI alert if app is in foreground
    if (onEmergencyAlert != null) {
      onEmergencyAlert!(type);
    }

    // Vibrate phone for immediate feedback
    await _vibratePhone();

    // Send SMS alerts
    await _sendEmergencySMSWithSleepProtection(type);
  }

  // UPDATED: Manual emergency trigger with face check
  Future<void> triggerManualEmergency() async {
    print('🆘 Manual emergency triggered');

    // NEW: Check face emotion before sending alert
    if (faceCheckCallback != null) {
      try {
        print('🎭 Checking face emotion before sending alert...');
        final emotionResult = await faceCheckCallback!('MANUAL');

        if (emotionResult == 'ok') {
          print('✅ User is okay, not sending emergency alert');
          return;
        } else if (emotionResult == 'not_ok') {
          print('🆘 User needs help, sending emergency alert');
        } else if (emotionResult == 'timeout') {
          print('⏰ Face check timeout, sending emergency alert as precaution');
        }
      } catch (e) {
        print('❌ Error in face check: $e, proceeding with alert');
      }
    }

    await _triggerEmergencyAlert('MANUAL');
  }

  // NEW: Inactivity emergency trigger with face check
  Future<void> triggerInactivityEmergency() async {
    print('🕒 Inactivity emergency triggered');

    // NEW: Check face emotion before sending alert
    if (faceCheckCallback != null) {
      try {
        print('🎭 Checking face emotion before sending alert...');
        final emotionResult = await faceCheckCallback!('INACTIVITY');

        if (emotionResult == 'ok') {
          print('✅ User is okay, not sending emergency alert');
          return;
        } else if (emotionResult == 'not_ok') {
          print('🆘 User needs help, sending emergency alert');
        } else if (emotionResult == 'timeout') {
          print('⏰ Face check timeout, sending emergency alert as precaution');
        }
      } catch (e) {
        print('❌ Error in face check: $e, proceeding with alert');
      }
    }

    await _triggerEmergencyAlert('INACTIVITY');
  }

  // Rest of the existing methods remain the same (with minor updates below)

  // UPDATED: _onPhoneShake method to use triggerInactivityEmergency
  void _onPhoneShake(ShakeEvent event) {
    final now = DateTime.now();
    if (now.difference(_lastShakeTime).inSeconds > SHAKE_COOLDOWN_SECONDS) {
      _lastShakeTime = now;
      _updateActivityTime();
      triggerInactivityEmergency(); // Changed to use the new method
    }
  }

  // UPDATED: Inactivity timer callback
  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityThreshold, () {
      triggerInactivityEmergency(); // Changed to use the new method
    });
  }

  // UPDATED: Fallback inactivity monitoring
  void _startFallbackInactivityMonitoring() {
    _updateActivityTime();

    // Use a periodic timer as fallback
    Timer.periodic(const Duration(minutes: 1), (timer) {
      if (DateTime.now().difference(_lastStepTime) > _inactivityThreshold) {
        triggerInactivityEmergency(); // Changed to use the new method
      }
    });

    print('⏰ Fallback inactivity monitoring started');
  }

  // NEW: Direct emergency trigger (without face check) for critical situations
  Future<void> triggerDirectEmergency(String type) async {
    print('🚨 Direct emergency triggered: $type (skipping face check)');

    // Show UI alert if app is in foreground
    if (onEmergencyAlert != null) {
      onEmergencyAlert!(type);
    }

    // Vibrate phone for immediate feedback
    await _vibratePhone();

    // Send SMS alerts
    await _sendEmergencySMSWithSleepProtection(type);
  }

  // UPDATED: Create emergency message
  String _createEmergencyMessage(String type, String patientName, String location) {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    switch (type) {
      case 'SHAKE_DETECTED':
        return "EMERGENCY ALERT! $patientName has triggered an emergency alert by shaking their phone. Location: $location. Time: $timestamp";
      case 'MANUAL':
        return "MANUAL EMERGENCY ALERT! $patientName has manually triggered an emergency alert. Location: $location. Time: $timestamp";
      case 'INACTIVITY':
        return "INACTIVITY ALERT! $patientName's phone has been inactive for ${_inactivityThreshold.inMinutes} minutes. Last activity: ${DateFormat('HH:mm:ss').format(_lastStepTime)}. Please check on them. Location: $location";
      default:
        return "EMERGENCY ALERT! $patientName needs assistance. Location: $location. Time: $timestamp";
    }
  }

  // UPDATED: Get status for debugging
  Map<String, dynamic> getStatus() {
    return {
      'initialized': _isInitialized,
      'lastActivity': DateFormat('HH:mm:ss').format(_lastStepTime),
      'inactivityThreshold': _inactivityThreshold.inMinutes,
      'emergencyContacts': _emergencyContacts.length,
      'shakeDetectorActive': _shakeDetector != null,
      'contacts': _emergencyContacts,
      'isSendingInBackground': _isSendingInBackground,
      'faceCheckAvailable': faceCheckCallback != null, // NEW
    };
  }

  // Rest of the existing methods remain unchanged...
  Future<void> _requestPermissions() async {
    try {
      // Request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('⚠️ Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('⚠️ Location permission permanently denied');
      }

      // Request SMS permissions
      final smsResult = await _telephony.requestSmsPermissions;
      if (smsResult == true) {
        print('✅ SMS permissions granted');
      } else {
        print('⚠️ SMS permissions denied or not available');
      }
    } catch (e) {
      print('❌ Error requesting permissions: $e');
    }
  }

  Future<void> _startShakeDetection() async {
    try {
      // CORRECTED: Use the proper callback signature with ShakeEvent parameter
      _shakeDetector = ShakeDetector.autoStart(
        onPhoneShake: (ShakeEvent event) {
          _onPhoneShake(event);
        },
        minimumShakeCount: 1,
        shakeSlopTimeMS: 500,
        shakeCountResetTime: 3000,
        shakeThresholdGravity: 2.5,
      );

      print('📱 Shake detection started successfully');
    } catch (e) {
      print('❌ Error starting shake detection: $e');
      // Use sensors_plus as fallback
      await _startSensorsPlusShakeDetection();
    }
  }

  // Alternative implementation using sensors_plus (more reliable)
  Future<void> _startSensorsPlusShakeDetection() async {
    try {
      // Import sensors_plus at the top of your file:
      // import 'package:sensors_plus/sensors_plus.dart';

      print('📱 Using sensors_plus for shake detection');
      // This is a placeholder - you'll need to implement the actual sensors_plus code
      // See the implementation below
    } catch (e) {
      print('❌ Error starting sensors_plus shake detection: $e');
    }
  }

  void _updateActivityTime() {
    _lastStepTime = DateTime.now();
    _resetInactivityTimer();
  }

  Future<void> _startActivityMonitoring() async {
    try {
      // Check if pedometer is available
      final stepCountStream = Pedometer.stepCountStream;

      _stepCountSubscription = stepCountStream.listen(
            (StepCount event) {
          _updateActivityTime();
          print('👣 Step detected: ${event.steps}');
        },
        onError: (error) {
          print('❌ Pedometer error: $error');
          _startFallbackInactivityMonitoring();
        },
        cancelOnError: true,
      );

      _updateActivityTime();
      print('🚶 Activity monitoring started');
    } catch (e) {
      print('❌ Error starting activity monitoring: $e');
      _startFallbackInactivityMonitoring();
    }
  }

  Future<void> _sendEmergencySMSWithSleepProtection(String type) async {
    if (_emergencyContacts.isEmpty) {
      print('❌ No emergency contacts found');
      return;
    }

    // Prevent multiple simultaneous sends
    if (_isSendingInBackground) {
      print('⚠️ Emergency alert already in progress');
      return;
    }

    _isSendingInBackground = true;

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      String patientName = prefs.getString("uname") ?? "Patient";

      // Get location with timeout handling
      String location = "Location unavailable";
      try {
        location = await _getCurrentLocation().timeout(const Duration(seconds: 10), onTimeout: () {
          print('⏰ Location request timed out');
          return "Location request timed out";
        });
      } catch (e) {
        print('❌ Error getting location: $e');
        location = "Location error: ${e.toString()}";
      }

      // Create the emergency message
      String message = _createEmergencyMessage(type, patientName, location);

      // Send SMS with enhanced retry mechanism
      await _sendSMSWithSleepHandling(message, retries: 3);

    } catch (e) {
      print('❌ Error in emergency SMS sending: $e');
    } finally {
      _isSendingInBackground = false;
    }
  }

  Future<void> _sendSMSWithSleepHandling(String message, {int retries = 3}) async {
    for (int attempt = 1; attempt <= retries; attempt++) {
      try {
        print('🔄 SMS attempt $attempt of $retries');

        final success = await _sendSMSDirectly(message).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            print('⏰ SMS attempt $attempt timed out');
            return false;
          },
        );

        if (success) {
          print('✅ SMS sent successfully on attempt $attempt');
          return;
        }

        if (attempt < retries) {
          print('⏳ Waiting 10 seconds before retry...');
          await Future.delayed(const Duration(seconds: 10));
        }
      } catch (e) {
        print('❌ SMS attempt $attempt failed: $e');
        if (attempt == retries) rethrow;
      }
    }
  }

  Future<bool> _sendSMSDirectly(String message) async {
    try {
      // Check if device can send SMS
      bool? canSendSms = await _telephony.isSmsCapable;
      if (canSendSms != true) {
        print('❌ Device cannot send SMS');
        return false;
      }

      int successCount = 0;
      int totalContacts = _emergencyContacts.length;

      print('📤 Sending SMS to $totalContacts contacts...');

      for (var contact in _emergencyContacts) {
        try {
          String phoneNumber = _cleanPhoneNumber(contact['phone_number']?.toString() ?? '');
          String contactName = contact['name']?.toString() ?? 'Unknown';

          if (phoneNumber.isEmpty) {
            print('❌ Invalid phone number for contact: $contactName');
            continue;
          }

          print('📱 Sending SMS to: $contactName ($phoneNumber)');

          // Send SMS using telephony package
          await _telephony.sendSms(to: phoneNumber, message: message);

          print('✅ SMS sent successfully to: $contactName');
          successCount++;

          // Small delay between messages to avoid rate limiting
          await Future.delayed(const Duration(seconds: 2));

        } catch (e) {
          print('❌ Failed to send SMS to ${contact['name']}: $e');
        }
      }

      print('📊 SMS sending completed: $successCount/$totalContacts successful');
      return successCount > 0;

    } catch (e) {
      print('❌ Error in SMS sending: $e');
      return false;
    }
  }

  String _cleanPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters except +
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // Ensure it starts with +91 for Indian numbers if it's 10 digits
    if (cleaned.length == 10 && !cleaned.startsWith('+')) {
      cleaned = '+91$cleaned';
    }

    // Validate phone number length
    if (cleaned.length < 10) {
      return '';
    }

    return cleaned;
  }

  Future<String> _getCurrentLocation() async {
    try {
      print('📍 Checking location services...');

      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('❌ Location services are disabled');
        return "Location services disabled";
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        print('❌ Location permission denied');
        return "Location permission denied";
      }

      if (permission == LocationPermission.deniedForever) {
        print('❌ Location permission permanently denied');
        return "Location permission permanently denied";
      }

      print('📍 Getting current position...');

      // Get position with lower accuracy for faster response
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 8),
      );

      String location = "Lat: ${position.latitude.toStringAsFixed(4)}, Long: ${position.longitude.toStringAsFixed(4)}";
      print('📍 Location obtained: $location');
      return location;

    } on TimeoutException {
      print('⏰ Location request timed out');
      return "Location request timed out";
    } catch (e) {
      print('❌ Error getting location: $e');
      return "Location error: ${e.toString().split('\n').first}";
    }
  }

  Future<void> _vibratePhone() async {
    try {
      bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(duration: 1000);
        await Future.delayed(const Duration(milliseconds: 500));
        Vibration.vibrate(duration: 1000);
        print('📳 Phone vibrated for emergency alert');
      }
    } catch (e) {
      print('❌ Error vibrating phone: $e');
    }
  }

  Future<void> _loadEmergencyContacts() async {
    print("🔄 Loading emergency contacts from Python backend...");

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String url = prefs.getString("url") ?? "";
    String lid = prefs.getString("lid") ?? "";

    if (url.isEmpty || lid.isEmpty) {
      print('❌ URL or LID not found in preferences');
      _useDefaultContacts();
      return;
    }

    try {
      final response = await http
          .get(Uri.parse('$url/get_emergency_contacts/?patient_id=$lid'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'success' && data['contacts'] != null) {
          final rawContacts = data['contacts'] as List<dynamic>;

          // Safely convert all contact types into uniform map format
          _emergencyContacts = rawContacts.map<Map<String, dynamic>>((contact) {
            if (contact is String) {
              return {
                'phone_number': contact,
                'name': 'Emergency Contact',
                'relationship': 'Contact'
              };
            } else if (contact is Map<String, dynamic>) {
              return {
                'phone_number': contact['phone_number']?.toString() ?? '',
                'name': contact['name']?.toString() ?? 'Unknown',
                'relationship': contact['relationship']?.toString() ?? 'Unknown'
              };
            } else {
              return {
                'phone_number': contact.toString(),
                'name': 'Unknown',
                'relationship': 'Unknown'
              };
            }
          }).where((contact) => contact['phone_number']?.toString().isNotEmpty == true).toList();

          print('✅ Loaded ${_emergencyContacts.length} emergency contacts');
        } else {
          print('❌ API returned error status: ${data['status']}');
          _useDefaultContacts();
        }
      } else {
        print('❌ HTTP error: ${response.statusCode}');
        _useDefaultContacts();
      }
    } on TimeoutException {
      print('⏰ Timeout loading emergency contacts');
      _useDefaultContacts();
    } catch (e) {
      print('❌ Error loading emergency contacts: $e');
      _useDefaultContacts();
    }
  }

  void _useDefaultContacts() {
    _emergencyContacts = [];
    print('ℹ️ Using default/empty emergency contacts list');
  }

  // Simulate activity (for testing)
  void simulateActivity() {
    _updateActivityTime();
    print('🎯 Activity simulated at ${DateTime.now()}');
  }

  void dispose() {
    _shakeDetector?.stopListening();
    _shakeDetector = null;
    _inactivityTimer?.cancel();
    _stepCountSubscription?.cancel();
    _isInitialized = false;
    print('🛑 Emergency service disposed');
  }

  void updateEmergencyContacts(List<Map<String, dynamic>> contacts) {
    _emergencyContacts = List.from(contacts);
    print('📞 Updated emergency contacts: ${_emergencyContacts.length} contacts');
  }

  void updateInactivityThreshold(Duration threshold) {
    _inactivityThreshold = threshold;
    _resetInactivityTimer();
    print('⏰ Inactivity threshold updated to ${threshold.inMinutes} minutes');
  }

  // Enhanced methods for missed medicine alerts
  Future<void> sendMissedMedicineAlert(String medicineName, String scheduledTime, int missedCount) async {
    if (_emergencyContacts.isEmpty) {
      print('❌ No emergency contacts found for missed medicine alert');
      return;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String patientName = prefs.getString("uname") ?? "Patient";

    String message = _createMissedMedicineMessage(patientName, medicineName, scheduledTime, missedCount);

    await _sendSMSWithSleepHandling(message, retries: 2);
  }

  String _createMissedMedicineMessage(String patientName, String medicineName, String scheduledTime, int missedCount) {
    final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());

    switch (missedCount) {
      case 1:
        return " MEDICINE ALERT: $patientName missed their $medicineName scheduled for $scheduledTime. This is reminder 1 of 3. Time: $timestamp";
      case 2:
        return " URGENT MEDICINE ALERT: $patientName has missed $medicineName twice. Scheduled time: $scheduledTime. Please check on them. This is reminder 2 of 3. Time: $timestamp";
      case 3:
        return " CRITICAL MEDICINE ALERT: $patientName has missed $medicineName 3 times! Scheduled: $scheduledTime. Emergency protocols activated. Please check on them immediately! Time: $timestamp";
      default:
        return "Medicine alert for $patientName: Missed $medicineName at $timestamp";
    }
  }

  Future<void> initiateEmergencyCallForMedicine(String medicineName) async {
    if (_emergencyContacts.isEmpty) {
      print('❌ No emergency contacts available for calling');
      return;
    }

    print('🚨 INITIATING EMERGENCY CALL FOR MISSED MEDICINE: $medicineName');

    for (var contact in _emergencyContacts) {
      String phoneNumber = _cleanPhoneNumber(contact['phone_number']?.toString() ?? '');
      String contactName = contact['name']?.toString() ?? 'Unknown';

      if (phoneNumber.isNotEmpty) {
        print("📞 Attempting call to: $contactName ($phoneNumber)");

        bool callSuccessful = await _makePhoneCall(phoneNumber);

        if (callSuccessful) {
          print("✅ Successfully initiated call to: $contactName");
          break;
        } else {
          print("❌ Call failed for: $contactName, trying next contact");
        }
      }
    }
  }

  Future<bool> _makePhoneCall(String phoneNumber) async {
    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
      return await canLaunchUrl(phoneUri);
    } catch (e) {
      print("❌ Error initiating call to $phoneNumber: $e");
      return false;
    }
  }

  Future<void> sendAllClearNotification(String medicineName) async {
    if (_emergencyContacts.isEmpty) {
      return;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String patientName = prefs.getString("uname") ?? "Patient";

    String message = "✅ ALL CLEAR: $patientName has confirmed taking $medicineName. Emergency alerts cancelled. Time: ${DateFormat('HH:mm:ss').format(DateTime.now())}";

    await _sendSMSWithSleepHandling(message, retries: 1);
  }

  // Method to check if emergency features are enabled
  bool isEmergencyEnabled() {
    return _isInitialized;
  }

  // Method to get contact count
  int getContactCount() {
    return _emergencyContacts.length;
  }

  // Method to get last activity time
  String getLastActivityTime() {
    return DateFormat('HH:mm:ss').format(_lastStepTime);
  }

  // Method to get inactivity threshold in minutes
  int getInactivityThreshold() {
    return _inactivityThreshold.inMinutes;
  }

  // Method to manually update activity time (for external use)
  void updateActivityTime() {
    _updateActivityTime();
  }
}