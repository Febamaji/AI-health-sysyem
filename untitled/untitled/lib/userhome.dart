
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:untitled/user_view_profile.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:camera/camera.dart';
import 'package:path/path.dart' as path;
import 'package:audioplayers/audioplayers.dart'; // Add this import
import 'emergency_service.dart';
import 'main.dart';

class PatientHomePage extends StatefulWidget {
  const PatientHomePage({super.key});

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage> {
  List<dynamic> _todayMedicines = [];
  List<dynamic> _upcomingAppointments = [];
  List<dynamic> _missedMedicines = [];
  bool _isLoading = true;
  int _totalMedicinesToday = 0;
  int _pendingAppointments = 0;
  late String patientName;
  late EmergencyService _emergencyService;
  bool _emergencyFeaturesEnabled = false;
  String _lastAlert = '';
  Map<String, dynamic> _emergencyStatus = {};
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isEmotionCaptureActive = false;
  Timer? _emotionCaptureTimer;
  int _captureCount = 0;
  String _lastEmotionResult = '';

  // Audio Player for beep sound
  late AudioPlayer _audioPlayer;
  bool _isBeepPlaying = false;

  // Timer for checking medicine times
  Timer? _medicineCheckTimer;

  // Medicine reminder tracking
  Map<String, Timer?> _medicineReminderTimers = {};
  Map<String, int> _reminderCount = {};
  Map<String, bool> _emergencyCalled = {};
  Set<String> _showingDialogs = {};

  // Face emotion check for emergency alerts
  bool _isCheckingEmotionForAlert = false;
  Timer? _faceCheckTimer;
  String _lastEmotionForAlert = '';

  // Voice Assistant Variables
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  bool _isListening = false;
  String _transcribedText = '';
  bool _speechEnabled = false;

  // Audio Recording Variables
  late AudioRecorder _audioRecorder;
  String? _audioFilePath;
  bool _isRecordingAudio = false;
  bool _hasRecordedAudio = false;

  // Two separate voice assistants
  bool _showMedicineAssistant = false;
  bool _showSummaryAssistant = false;
  String _medicineAssistantMessage = "മരുന്ന് സ്ഥിരീകരിക്കാൻ ശബ്ദം റെക്കോർഡ് ചെയ്യുക.";
  String _summaryAssistantMessage = "ഇന്നത്തെ വിവരങ്ങൾ പറയുന്നു...";
  bool _isSpeaking = false;

  // Missed Medicine Tracking
  Map<String, int> _medicineMissedCount = {};
  Timer? _missedMedicineChecker;
  bool _isCallingInProgress = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer(); // Initialize audio player
    _loadHomeData();
    _initSpeech();
    _initAudioRecorder();
    _initEmergencyService();
    _startMedicineCheckTimer();
    _startMissedMedicineChecker();
    _initializeCamera();
  }

  @override
  void dispose() {
    _medicineCheckTimer?.cancel();
    _missedMedicineChecker?.cancel();
    _emergencyService.dispose();
    _emotionCaptureTimer?.cancel();
    _faceCheckTimer?.cancel();
    _cameraController?.dispose();
    _flutterTts.stop();
    _audioPlayer.dispose(); // Dispose audio player

    // Cancel all reminder timers
    _medicineReminderTimers.forEach((key, timer) {
      timer?.cancel();
    });

    super.dispose();
  }

  // ================================================
  // BEEP SOUND FUNCTION
  // ================================================

  Future<void> _playBeepSound() async {
    if (_isBeepPlaying) return;

    try {
      _isBeepPlaying = true;

      print('🔊 Attempting to play beep sound');

      // Try to play the sound file first
      try {
        // Check if asset exists by trying to load it
        await _audioPlayer.play(AssetSource('sounds/beep.mp3'));

        // Add a timeout to reset the flag
        Future.delayed(const Duration(seconds: 2), () {
          _isBeepPlaying = false;
        });

        // Also play haptic feedback for better user experience
        await HapticFeedback.heavyImpact();

      } catch (e) {
        print('⚠️ Sound file not found, using haptic feedback fallback: $e');

        // Fallback to haptic feedback (vibration) which creates a beep-like sound
        // Create a triple beep pattern
        for (int i = 0; i < 3; i++) {
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 100));
          await HapticFeedback.mediumImpact();
          await Future.delayed(const Duration(milliseconds: 100));
        }

        _isBeepPlaying = false;
      }

      // Show visual notification
      if (mounted && !_isDialogShowing('beep_notification')) {
        _showingDialogs.add('beep_notification');
        Fluttertoast.showToast(
          msg: "🔔 Time to take medicine!",
          backgroundColor: Colors.orange,
          textColor: Colors.white,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.TOP,
        );
        Future.delayed(const Duration(seconds: 2), () {
          _showingDialogs.remove('beep_notification');
        });
      }

    } catch (e) {
      print('❌ Error playing beep: $e');
      _isBeepPlaying = false;
    }
  }  // ================================================
  // MEDICINE TIME CHECKER FUNCTIONS
  // ================================================

  void _startMedicineCheckTimer() {
    _medicineCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkMedicineTimes();
    });
  }

  Future<void> _checkMedicineTimes() async {
    if (_todayMedicines.isEmpty) return;

    final now = DateTime.now();

    for (var medicine in _todayMedicines) {
      final medicineId = medicine['id'].toString();
      final scheduledTimeStr = medicine['scheduled_time']?.toString() ?? '';
      final isTaken = medicine['is_taken'] == true;

      if (isTaken) {
        _cancelReminderTimer(medicineId);
        continue;
      }

      final scheduledTime = _parseMedicineTime(scheduledTimeStr, now);

      if (scheduledTime != null) {
        final difference = now.difference(scheduledTime).inMinutes;

        // Start reminder timer when it's time for medicine (0-5 minutes)
        if (difference >= 0 && difference <= 5 && !_medicineReminderTimers.containsKey(medicineId)) {
          _startReminderTimer(medicine);
        }
      }
    }
  }

  void _startReminderTimer(Map<String, dynamic> medicine) {
    final medicineId = medicine['id'].toString();

    // Initialize reminder count and emergency called flag
    _reminderCount[medicineId] = 0;
    _emergencyCalled[medicineId] = false;

    // Show first reminder immediately
    _showMedicineTimeAlert(medicine);

    // Create timer to show reminder every minute (total 3 times)
    Timer reminderTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      // Check if medicine is still not taken
      final medicineStillPending = _todayMedicines.any(
              (m) => m['id'].toString() == medicineId && m['is_taken'] != true
      );

      if (medicineStillPending) {
        // Increment reminder count
        _reminderCount[medicineId] = (_reminderCount[medicineId] ?? 0) + 1;
        final currentCount = _reminderCount[medicineId]!;

        print('Reminder #$currentCount for medicine: ${medicine['medicine_name']}');

        // Show reminder
        _showMedicineTimeAlert(medicine);

        // Speak Malayalam alert for each reminder
        _speakMedicineAlertMalayalam(medicine);

        // After 3 reminders (3 minutes) with no response, trigger emergency
        if (currentCount >= 3 && !_emergencyCalled[medicineId]!) {
          print('⚠️ No response after 3 reminders - Triggering emergency for ${medicine['medicine_name']}');
          _emergencyCalled[medicineId] = true;
          _handleNoResponseEmergency(medicine);
        }
      } else {
        // Medicine taken, cancel timer
        print('✅ Medicine taken - cancelling reminders for ${medicine['medicine_name']}');
        timer.cancel();
        _medicineReminderTimers.remove(medicineId);
        _reminderCount.remove(medicineId);
        _emergencyCalled.remove(medicineId);
      }
    });

    _medicineReminderTimers[medicineId] = reminderTimer;
  }

  void _cancelReminderTimer(String medicineId) {
    if (_medicineReminderTimers.containsKey(medicineId)) {
      _medicineReminderTimers[medicineId]?.cancel();
      _medicineReminderTimers.remove(medicineId);
      _reminderCount.remove(medicineId);
      _emergencyCalled.remove(medicineId);
    }
  }

  void _handleNoResponseEmergency(Map<String, dynamic> medicine) {
    // Add to missed medicines list
    final now = DateTime.now();

    setState(() {
      if (!_missedMedicines.any((m) => m['id'].toString() == medicine['id'].toString())) {
        _missedMedicines.add({
          ...medicine,
          'missed_time': now,
          'missed_count': 1,
          'minutes_late': 3,
          'emergency_triggered': true
        });
      }
    });

    // Trigger emergency calls
    _triggerEmergencyCalls(medicine, 3);
  }

  DateTime? _parseMedicineTime(String timeStr, DateTime now) {
    try {
      timeStr = timeStr.trim().toUpperCase();

      int hour = 0;
      int minute = 0;

      if (timeStr.contains('PM') || timeStr.contains('AM')) {
        final isPM = timeStr.contains('PM');
        final timePart = timeStr.replaceAll('PM', '').replaceAll('AM', '').trim();

        final parts = timePart.contains(':') ? timePart.split(':') : timePart.split('.');
        if (parts.length >= 2) {
          hour = int.parse(parts[0]);
          minute = int.parse(parts[1].substring(0, 2));

          if (isPM && hour < 12) hour += 12;
          if (!isPM && hour == 12) hour = 0;
        }
      } else {
        final parts = timeStr.contains(':') ? timeStr.split(':') : timeStr.split('.');
        if (parts.length >= 2) {
          hour = int.parse(parts[0]);
          minute = int.parse(parts[1].substring(0, 2));
        }
      }

      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (e) {
      print('Error parsing time "$timeStr": $e');
      return null;
    }
  }

  void _showMedicineTimeAlert(Map<String, dynamic> medicine) {
    final medicineId = medicine['id'].toString();
    final medicineName = medicine['medicine_name'] ?? 'medicine';
    final dosage = medicine['dosage'] ?? '';
    final displayTime = _formatTimeForDisplay(medicine['scheduled_time'] ?? '');
    final reminderCount = _reminderCount[medicineId] ?? 0;

    // Play beep sound ONLY for the first reminder (reminderCount == 0)
    if (reminderCount == 0) {
      print('🔊 Playing beep sound for first reminder of ${medicineName}');
      _playBeepSound();
    }

    // Don't show dialog if already showing one for this medicine
    if (_isDialogShowing(medicineId)) {
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // Prevent back button dismissal
        child: AlertDialog(
          backgroundColor: reminderCount >= 3 ? Colors.red.shade50 : const Color(0xFFE8F5E9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
                color: reminderCount >= 3 ? Colors.red : const Color(0xFF2E7D32),
                width: 2
            ),
          ),
          title: Row(
            children: [
              Icon(
                  reminderCount >= 3 ? Icons.warning_amber_rounded : Icons.alarm_rounded,
                  color: reminderCount >= 3 ? Colors.red : const Color(0xFF2E7D32),
                  size: 28
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  reminderCount == 0 ? 'മരുന്ന് സമയം' : 'ഓർമ്മപ്പെടുത്തൽ #$reminderCount',
                  style: TextStyle(
                    color: reminderCount >= 3 ? Colors.red : const Color(0xFF1B5E20),
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                  reminderCount >= 3 ? 'assets/ani6.json' : 'assets/ani3.json',
                  width: 100,
                  height: 100
              ),
              const SizedBox(height: 16),
              Text(
                reminderCount == 0
                    ? 'മരുന്ന് കഴിക്കാനുള്ള സമയമായി:'
                    : reminderCount >= 3
                    ? 'അവസാന ഓർമ്മപ്പെടുത്തൽ! ഉടൻ മരുന്ന് കഴിക്കുക:'
                    : 'ദയവായി മരുന്ന് കഴിക്കുക:',
                style: TextStyle(
                    fontSize: 16,
                    color: reminderCount >= 3 ? Colors.red : Colors.grey[700],
                    fontWeight: reminderCount >= 3 ? FontWeight.bold : FontWeight.normal
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                medicineName,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: reminderCount >= 3 ? Colors.red : const Color(0xFF2E7D32),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                dosage,
                style: TextStyle(
                    fontSize: 18,
                    color: reminderCount >= 3 ? Colors.red : const Color(0xFF1B5E20)
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                displayTime,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              if (reminderCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'ഓർമ്മപ്പെടുത്തൽ $reminderCount/3',
                    style: TextStyle(
                      fontSize: 14,
                      color: reminderCount >= 3 ? Colors.red : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (reminderCount >= 3)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '⚠️ അവസാന മുന്നറിയിപ്പ്! പ്രതികരണമില്ലെങ്കിൽ എമർജൻസി കോൾ ചെയ്യും',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (medicine['instructions'] != null && medicine['instructions'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'നിർദ്ദേശങ്ങൾ: ${medicine['instructions']}',
                    style: const TextStyle(fontSize: 14, color: Colors.blueGrey),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _markMedicineAsTaken(medicine);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: reminderCount >= 3 ? Colors.red : const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
              ),
              child: Text(reminderCount >= 3 ? 'ഉടൻ കഴിച്ചു' : 'കഴിച്ചു'),
            ),
          ],
        ),
      ),
    ).then((_) {
      // Remove from showing dialogs set when dialog closes
      _showingDialogs.remove(medicineId);
    });

    // Track showing dialog
    _showingDialogs.add(medicineId);

    Fluttertoast.showToast(
      msg: reminderCount >= 3
          ? '⚠️ അവസാന മുന്നറിയിപ്പ്: $medicineName കഴിക്കുക'
          : '⏰ $medicineName കഴിക്കാനുള്ള സമയമായി',
      backgroundColor: reminderCount >= 3 ? Colors.red : const Color(0xFF2E7D32),
      textColor: Colors.white,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.TOP,
    );
  }

  bool _isDialogShowing(String medicineId) {
    return _showingDialogs.contains(medicineId);
  }

  Future<void> _speakMedicineAlertMalayalam(Map<String, dynamic> medicine) async {
    final medicineName = medicine['medicine_name'] ?? '';
    final dosage = medicine['dosage'] ?? '';
    final medicineId = medicine['id'].toString();
    final reminderCount = _reminderCount[medicineId] ?? 0;

    String malayalamMessage;

    if (reminderCount >= 3) {
      malayalamMessage = '''
      അടിയന്തര മുന്നറിയിപ്പ്!
      $medicineName എന്ന മരുന്ന് കഴിക്കാനുള്ള സമയമായി.
      ഇത് അവസാന ഓർമ്മപ്പെടുത്തലാണ്.
      ഉടൻ തന്നെ മരുന്ന് കഴിച്ചില്ലെങ്കിൽ, എമർജൻസി കോൾ ചെയ്യും.
      ''';
    } else if (reminderCount > 0) {
      malayalamMessage = '''
      ഓർമ്മപ്പെടുത്തൽ നമ്പർ $reminderCount.
      $medicineName എന്ന മരുന്ന് കഴിക്കുക.
      അളവ്: $dosage.
      ''';
    } else {
      malayalamMessage = '''
      ശ്രദ്ധിക്കുക!
      $medicineName എന്ന മരുന്ന് കഴിക്കാനുള്ള സമയമായി.
      അളവ്: $dosage.
      ദയവായി ഉടൻ തന്നെ മരുന്ന് കഴിക്കുക.
      ''';
    }

    await _flutterTts.setLanguage("ml-IN");
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.speak(malayalamMessage);

    print('🔊 Speaking Malayalam: $malayalamMessage');
  }

  // ================================================
  // MALAYALAM SUMMARY FUNCTIONS
  // ================================================

  Future<void> _speakSummaryInMalayalam() async {
    final now = DateTime.now();
    final formattedDate = DateFormat('EEEE, MMMM d').format(now);
    final formattedTime = DateFormat('hh:mm a').format(now);

    String greeting;
    final hour = now.hour;
    if (hour < 12) {
      greeting = "സുപ്രഭാതം";
    } else if (hour < 17) {
      greeting = "ശുഭ മദ്ധ്യാഹ്നം";
    } else {
      greeting = "ശുഭ സായാഹ്നം";
    }

    String summary = "$greeting $patientName. ";

    summary += "ഇന്ന് $formattedDate ആണ്. സമയം $formattedTime. ";

    if (_todayMedicines.isNotEmpty) {
      summary += "ഇന്ന് നിങ്ങൾക്ക് $_totalMedicinesToday മരുന്നുകൾ ഉണ്ട്. ";
      for (var medicine in _todayMedicines) {
        final medName = medicine['medicine_name'] ?? '';
        final medTime = _formatTimeForDisplay(medicine['scheduled_time'] ?? '');
        summary += "$medName, $medTime ന്. ";
      }
    } else {
      summary += "ഇന്ന് നിങ്ങൾക്ക് മരുന്നുകൾ ഒന്നും ഇല്ല. ";
    }

    if (_missedMedicines.isNotEmpty) {
      summary += "നിങ്ങൾ ${_missedMedicines.length} മരുന്നുകൾ കഴിക്കാൻ മറന്നു. ";
    }

    if (_upcomingAppointments.isNotEmpty) {
      summary += "ഇന്ന് നിങ്ങൾക്ക് $_pendingAppointments അപ്പോയിന്റ്മെന്റുകൾ ഉണ്ട്. ";
      for (var appointment in _upcomingAppointments) {
        final docName = appointment['doctor_name'] ?? '';
        final appTime = appointment['appointment_time'] ?? '';
        summary += "ഡോക്ടർ $docName, $appTime ന്. ";
      }
    }

    summary += "ഓർമ്മിക്കുക: സമയത്ത് മരുന്ന് കഴിക്കുകയും വിശ്രമിക്കുകയും ചെയ്യുക. നിങ്ങളുടെ ആരോഗ്യമാണ് ഞങ്ങളുടെ പ്രഥമ പരിഗണന.";

    print('📢 Speaking Malayalam summary: $summary');

    await _flutterTts.setLanguage("ml-IN");
    await _flutterTts.setSpeechRate(0.4);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.speak(summary);

    setState(() {
      _summaryAssistantMessage = summary;
    });
  }

  String _getTodaysSummary() {
    final now = DateTime.now();
    final formattedDate = DateFormat('EEEE, MMMM d').format(now);
    final formattedTime = DateFormat('hh:mm a').format(now);

    String greeting;
    final hour = now.hour;
    if (hour < 12) {
      greeting = "Good Morning";
    } else if (hour < 17) {
      greeting = "Good Afternoon";
    } else {
      greeting = "Good Evening";
    }

    String summary = "$greeting $patientName. Today is $formattedDate. Time is $formattedTime. ";

    if (_todayMedicines.isNotEmpty) {
      summary += "You have $_totalMedicinesToday medicines today. ";
      for (var medicine in _todayMedicines) {
        final medName = medicine['medicine_name'] ?? '';
        final medTime = _formatTimeForDisplay(medicine['scheduled_time'] ?? '');
        summary += "$medName at $medTime. ";
      }
    } else {
      summary += "No medicines scheduled for today. ";
    }

    if (_missedMedicines.isNotEmpty) {
      summary += "You missed ${_missedMedicines.length} medicines. ";
    }

    if (_upcomingAppointments.isNotEmpty) {
      summary += "You have $_pendingAppointments appointments today. ";
      for (var appointment in _upcomingAppointments) {
        final docName = appointment['doctor_name'] ?? '';
        final appTime = appointment['appointment_time'] ?? '';
        summary += "Dr. $docName at $appTime. ";
      }
    }

    return summary;
  }

  Future<void> _speakMessage(String message) async {
    setState(() {
      _isSpeaking = true;
    });

    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(message);
  }

  // ================================================
  // VOICE ASSISTANT FUNCTIONS
  // ================================================

  void _toggleMedicineAssistant() {
    setState(() {
      _showMedicineAssistant = !_showMedicineAssistant;
      _showSummaryAssistant = false;

      if (_showMedicineAssistant) {
        _speakMessageMalayalam("മരുന്ന് അസിസ്റ്റന്റ് തയ്യാറാണ്. മരുന്ന് സ്ഥിരീകരിക്കാൻ ശബ്ദം റെക്കോർഡ് ചെയ്യുക.");
      } else {
        _transcribedText = '';
        _hasRecordedAudio = false;
        _audioFilePath = null;
        _stopListening();
        if (_isRecordingAudio) {
          _stopAudioRecording();
        }
      }
    });
  }

  void _toggleSummaryAssistant() {
    setState(() {
      _showSummaryAssistant = !_showSummaryAssistant;
      _showMedicineAssistant = false;

      if (_showSummaryAssistant) {
        _speakSummaryInMalayalam();
      } else {
        _stopListening();
        _flutterTts.stop();
      }
    });
  }

  Future<void> _speakMessageMalayalam(String message) async {
    setState(() {
      _isSpeaking = true;
      if (_showSummaryAssistant) {
        _summaryAssistantMessage = message;
      }
      if (_showMedicineAssistant) {
        _medicineAssistantMessage = message;
      }
    });

    await _flutterTts.setLanguage("ml-IN");
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(message);
  }

  Future<void> _initSpeech() async {
    try {
      _speech = stt.SpeechToText();
      _flutterTts = FlutterTts();

      _speechEnabled = await _speech.initialize(
        onStatus: (status) {
          print('Speech status: $status');
          setState(() {
            _isListening = status == 'listening';
          });
        },
        onError: (error) {
          print('Speech error: $error');
          setState(() {
            _isListening = false;
          });
        },
      );

      await _flutterTts.setLanguage("ml-IN");
      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setVolume(1.0);

      Set<dynamic> languages = await _flutterTts.getLanguages;
      print("Available TTS languages: $languages");

      _flutterTts.setCompletionHandler(() {
        setState(() {
          _isSpeaking = false;
        });
      });

      _flutterTts.setErrorHandler((msg) {
        print("TTS Error: $msg");
        setState(() {
          _isSpeaking = false;
        });
      });

      print("Speech initialized: $_speechEnabled");
    } catch (e) {
      print("Error initializing speech: $e");
      setState(() {
        _speechEnabled = false;
      });
    }
  }

  // ================================================
  // DATA LOADING FUNCTIONS
  // ================================================

  Future<void> _loadHomeData() async {
    setState(() {
      _isLoading = true;
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    patientName = prefs.getString("uname") ?? "";
    await Future.wait([_loadTodayMedicines(), _loadUpcomingAppointments()]);

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadTodayMedicines() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String url = prefs.getString("url") ?? "";
    String lid = prefs.getString("lid") ?? "";

    try {
      final response = await http.get(
        Uri.parse('$url/today_medicines/?patient_id=$lid'),
      );

      print('📥 Today medicines response: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'ok') {
          setState(() {
            _todayMedicines = data['data'];
            _totalMedicinesToday = _todayMedicines.length;
          });
          print('✅ Loaded ${_todayMedicines.length} medicines for today');
        }
      }
    } catch (e) {
      print("❌ Error loading today's medicines: $e");
    }
  }

  String _formatTimeForDisplay(String databaseTime) {
    try {
      final now = DateTime.now();
      final parsedTime = _parseMedicineTime(databaseTime, now);
      if (parsedTime != null) {
        return DateFormat('hh:mm a').format(parsedTime);
      }
      return databaseTime;
    } catch (e) {
      return databaseTime;
    }
  }

  // ================================================
  // MEDICINE CONFIRMATION FUNCTIONS
  // ================================================

  Future<void> _confirmMedicineTaken(
      Map<String, dynamic> medicine,
      String method, [
        String? voiceTranscription,
        String? audioFilePath,
      ]) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String url = prefs.getString("url") ?? "";

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$url/mark_medicine_taken/'),
      );

      request.fields['plan_id'] = medicine['id'].toString();
      request.fields['taken_time'] = DateTime.now().toString();
      request.fields['method'] = method;
      request.fields['voice_transcription'] = voiceTranscription ?? _transcribedText ?? 'No transcription available';

      if (method == 'VOICE' && audioFilePath != null) {
        try {
          File audioFile = File(audioFilePath);
          if (await audioFile.exists()) {
            String extension = audioFilePath.split('.').last;
            if (extension.isEmpty) extension = 'm4a';

            var multipartFile = await http.MultipartFile.fromPath(
              'audio',
              audioFilePath,
              filename: 'medicine_voice_${medicine['id']}_${DateTime.now().millisecondsSinceEpoch}.$extension',
            );

            request.files.add(multipartFile);
            print("✅ Audio file added to request: $audioFilePath");
          } else {
            print("❌ Audio file does not exist: $audioFilePath");
          }
        } catch (e) {
          print("❌ Error adding audio file: $e");
        }
      }

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final data = json.decode(responseData);

      if (response.statusCode == 200 && data['status'] == 'success') {
        String message = method == 'VOICE' ? 'മരുന്ന് സ്ഥിരീകരിച്ചു!' : 'മരുന്ന് കഴിച്ചതായി രേഖപ്പെടുത്തി';

        Fluttertoast.showToast(
          msg: message,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );

        if (method == 'VOICE') {
          await _speakMessageMalayalam("നന്നായി. ${medicine['medicine_name']} മരുന്ന് കഴിച്ചതായി രേഖപ്പെടുത്തി.");
        }

        // Cancel reminder timer and remove from missed list
        _cancelReminderTimer(medicine['id'].toString());
        _resetMissedMedicineCount(medicine['id'].toString());
        _loadTodayMedicines();

        setState(() {
          _transcribedText = '';
          _hasRecordedAudio = false;
          _audioFilePath = null;
        });
      } else {
        String errorMsg = data['message'] ?? 'Error updating medicine status';
        Fluttertoast.showToast(
          msg: errorMsg,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print("❌ Network error: $e");
      Fluttertoast.showToast(
        msg: 'Error updating medicine status',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  void _markMedicineAsTaken(Map<String, dynamic> medicine) {
    // Cancel reminder timer immediately
    _cancelReminderTimer(medicine['id'].toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('മരുന്ന് സ്ഥിരീകരണം'),
        content: Text('${medicine['medicine_name']} എങ്ങനെ സ്ഥിരീകരിക്കണം?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('റദ്ദാക്കുക'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmMedicineTaken(medicine, 'MANUAL');
            },
            child: const Text('ബട്ടൺ', style: TextStyle(color: Color(0xFF2E7D32))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _toggleMedicineAssistant();
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.mic_rounded, color: Colors.blue),
                SizedBox(width: 4),
                Text('ശബ്ദം', style: TextStyle(color: Colors.blue)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmMedicineWithVoice(Map<String, dynamic> medicine) {
    if (_audioFilePath != null) {
      _confirmMedicineTaken(medicine, 'VOICE', _transcribedText, _audioFilePath);
    } else {
      Fluttertoast.showToast(
        msg: 'Please record your voice first',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
    }
  }

  // ================================================
  // MISSED MEDICINE TRACKING
  // ================================================

  void _startMissedMedicineChecker() {
    _missedMedicineChecker = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkMissedMedicines();
    });
  }

  void _checkMissedMedicines() {
    if (_todayMedicines.isEmpty) return;

    final now = DateTime.now();

    for (var medicine in _todayMedicines) {
      final scheduledTimeStr = medicine['scheduled_time']?.toString() ?? '';
      final medicineId = medicine['id'].toString();
      final isTaken = medicine['is_taken'] == true;

      if (!isTaken) {
        final scheduledTime = _parseMedicineTime(scheduledTimeStr, now);
        if (scheduledTime != null && now.isAfter(scheduledTime.add(const Duration(minutes: 15)))) {
          _handleMissedMedicine(medicine, now);
        }
      }
    }
  }

  void _handleMissedMedicine(Map<String, dynamic> medicine, DateTime missedTime) {
    final medicineId = medicine['id'].toString();
    final now = DateTime.now();
    final scheduledTimeStr = medicine['scheduled_time']?.toString() ?? '';
    final scheduledTime = _parseMedicineTime(scheduledTimeStr, now);

    if (scheduledTime == null) return;

    final minutesLate = now.difference(scheduledTime).inMinutes;

    _medicineMissedCount[medicineId] = (_medicineMissedCount[medicineId] ?? 0) + 1;

    if (!_missedMedicines.any((m) => m['id'].toString() == medicineId)) {
      setState(() {
        _missedMedicines.add({
          ...medicine,
          'missed_time': missedTime,
          'missed_count': _medicineMissedCount[medicineId],
          'minutes_late': minutesLate
        });
      });
    }

    if (minutesLate >= 30 && _medicineMissedCount[medicineId]! >= 3) {
      _triggerEmergencyCalls(medicine, minutesLate);
    }
  }

  void _viewMissedMedicines() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Missed Medicines'),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _missedMedicines.length,
            itemBuilder: (context, index) {
              final medicine = _missedMedicines[index];
              final emergencyTriggered = medicine['emergency_triggered'] == true;
              return ListTile(
                leading: Icon(
                    emergencyTriggered ? Icons.emergency_rounded : Icons.warning_amber_rounded,
                    color: emergencyTriggered ? Colors.red : Colors.orange
                ),
                title: Text(
                  medicine['medicine_name'] ?? 'Unknown',
                  style: TextStyle(
                      color: emergencyTriggered ? Colors.red : null,
                      fontWeight: emergencyTriggered ? FontWeight.bold : FontWeight.normal
                  ),
                ),
                subtitle: Text(
                  'Missed ${medicine['missed_count']} times${emergencyTriggered ? ' - Emergency Called' : ''}',
                  style: TextStyle(
                      color: emergencyTriggered ? Colors.red : Colors.grey[600]
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.check_circle, color: Colors.green),
                  onPressed: () {
                    Navigator.pop(context);
                    _markMedicineAsTaken(medicine);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerEmergencyCalls(Map<String, dynamic> medicine, int missedCount) async {
    if (_isCallingInProgress) return;

    _isCallingInProgress = true;

    // Show emergency alert
    await _showEmergencyAlert('MISSED_MEDICINE_EMERGENCY');

    // Call emergency contacts
    await _callEmergencyContacts(medicine, missedCount);

    _isCallingInProgress = false;
  }

  void _resetMissedMedicineCount(String medicineId) {
    _medicineMissedCount.remove(medicineId);
    setState(() {
      _missedMedicines.removeWhere((m) => m['id'].toString() == medicineId);
    });
  }

  // ================================================
  // EMERGENCY CALL FUNCTIONS
  // ================================================

  Future<void> _callEmergencyContacts(Map<String, dynamic> medicine, int missedCount) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String patientName = prefs.getString("uname") ?? "the patient";
    final medicineName = medicine['medicine_name'] ?? 'medicine';

    final List<String> emergencyContacts = await _getEmergencyContacts();

    if (emergencyContacts.isEmpty) {
      _showNoContactsDialog();
      return;
    }

    _showCallingDialog(emergencyContacts, medicine, missedCount);

    for (final contact in emergencyContacts) {
      if (!_isCallingInProgress) break;
      await _makeEmergencyCall(contact, patientName, medicineName, missedCount);
      await Future.delayed(const Duration(seconds: 5));
    }

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<List<String>> _getEmergencyContacts() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String url = prefs.getString("url") ?? "";
    final String patientId = prefs.getString("lid") ?? "";

    try {
      final response = await http.get(
        Uri.parse('$url/emergency_contacts/?patient_id=$patientId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' || data['status'] == 'ok') {
          List<String> contacts = [];

          if (data['contacts'] is List) {
            contacts = List<String>.from(data['contacts'] ?? []);
          } else if (data['data'] is List) {
            final contactList = data['data'] as List;
            contacts = contactList.map((contact) {
              if (contact is String) return contact;
              if (contact is Map) return contact['phone']?.toString() ?? contact['contact_number']?.toString() ?? '';
              return '';
            }).where((phone) => phone.isNotEmpty).toList();
          }

          return contacts;
        }
      }
    } catch (e) {
      print('❌ Error fetching emergency contacts: $e');
    }

    return prefs.getStringList('emergency_contacts') ?? [];
  }

  Future<void> _makeEmergencyCall(String phoneNumber, String patientName, String medicineName, int missedCount) async {
    try {
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      if (cleanNumber.isEmpty) return;

      await FlutterPhoneDirectCaller.callNumber(cleanNumber);
    } catch (e) {
      print('Error making emergency call: $e');
    }
  }

  void _showCallingDialog(List<String> contacts, Map<String, dynamic> medicine, int missedCount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red.shade50,
        title: Row(
          children: [
            const Icon(Icons.emergency_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            const Text('Emergency Calls', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset('assets/ani6.json', width: 80, height: 80),
            const SizedBox(height: 12),
            const Text('Calling emergency contacts...'),
            const SizedBox(height: 8),
            Text(
              'No response for ${medicine['medicine_name']} after 3 reminders',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _isCallingInProgress = false;
              Navigator.pop(context);
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showNoContactsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No Emergency Contacts'),
        content: const Text('Please add emergency contacts in your profile settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ================================================
  // EMERGENCY SERVICES FUNCTIONS
  // ================================================

  void _initEmergencyService() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _emergencyFeaturesEnabled = prefs.getBool('emergency_features') ?? true;

    _emergencyService = EmergencyService();

    if (_emergencyFeaturesEnabled) {
      await _emergencyService.initialize(
        alertCallback: _showEmergencyAlert,
        faceCheckCallback: checkFaceEmotionBeforeAlert,
      );
      _updateEmergencyStatus();
    }
  }

  void _updateEmergencyStatus() {
    setState(() {
      _emergencyStatus = _emergencyService.getStatus();
    });
  }

  Future<void> _showEmergencyAlert(String type) async {
    final emotionResult = await checkFaceEmotionBeforeAlert(type);

    if (emotionResult == 'ok') {
      Fluttertoast.showToast(
        msg: 'You seem okay. Emergency alert cancelled.',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
      return;
    } else {
      await _sendEmergencyAlertToFamily(type);
    }
  }

  Future<void> _sendEmergencyAlertToFamily(String type) async {
    setState(() {
      _lastAlert = '${type.replaceAll('_', ' ')} - ${DateFormat('HH:mm:ss').format(DateTime.now())}';
    });

    _updateEmergencyStatus();
    _showAlertDialog(type);

    await _sendEmergencyNotification(type);

    Fluttertoast.showToast(
      msg: 'Emergency alert sent to family members!',
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
  }

  Future<void> _sendEmergencyNotification(String type) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String url = prefs.getString("url") ?? "";
    final String patientId = prefs.getString("lid") ?? "";
    final String patientName = prefs.getString("uname") ?? "Patient";

    try {
      await http.post(
        Uri.parse('$url/send_emergency_alert/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'patient_id': patientId,
          'patient_name': patientName,
          'alert_type': type,
          'timestamp': DateTime.now().toIso8601String(),
          'message': 'Emergency alert triggered: $type',
        }),
      );
    } catch (e) {
      print('Error sending emergency notification: $e');
    }
  }

  void _showAlertDialog(String type) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.red.shade50,
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Emergency Alert Sent',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            type == 'MISSED_MEDICINE_EMERGENCY'
                ? 'Emergency alert has been sent to your family members due to no response after 3 medicine reminders.'
                : 'Emergency alert has been sent to your family members.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // ================================================
  // FACE EMOTION CHECK FUNCTIONS
  // ================================================

  Future<String> checkFaceEmotionBeforeAlert(String alertType) async {
    if (!_isCameraInitialized || _cameraController == null) {
      return 'not_ok';
    }

    Completer<String> completer = Completer<String>();

    setState(() {
      _isCheckingEmotionForAlert = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildEmotionCheckDialog(alertType, completer),
    );

    _performEmotionCheckSequence(completer);

    _faceCheckTimer = Timer(const Duration(seconds: 25), () {
      if (!completer.isCompleted) {
        completer.complete('timeout');
        if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
    });

    return completer.future;
  }

  Widget _buildEmotionCheckDialog(String alertType, Completer<String> completer) {
    int timeRemaining = 25;

    return StatefulBuilder(
      builder: (context, setState) {
        Timer.periodic(const Duration(seconds: 1), (timer) {
          if (timeRemaining > 0) {
            setState(() => timeRemaining--);
          } else {
            timer.cancel();
          }
        });

        return AlertDialog(
          backgroundColor: Colors.orange.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.face_retouching_natural_rounded, color: Colors.orange, size: 28),
              const SizedBox(width: 8),
              const Text('Emergency Face Check', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isCameraInitialized && _cameraController != null)
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: timeRemaining / 25,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  timeRemaining > 15 ? Colors.green : timeRemaining > 5 ? Colors.orange : Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Text('Time remaining: $timeRemaining seconds'),
              if (_lastEmotionForAlert.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Detected: $_lastEmotionForAlert',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getEmotionColor(_lastEmotionForAlert),
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _faceCheckTimer?.cancel();
                completer.complete('ok');
                Navigator.of(context).pop();
              },
              child: const Text("I'm OK", style: TextStyle(color: Colors.green)),
            ),
            ElevatedButton(
              onPressed: () {
                _faceCheckTimer?.cancel();
                completer.complete('not_ok');
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('I Need Help'),
            ),
          ],
        );
      },
    );
  }

  void _performEmotionCheckSequence(Completer<String> completer) async {
    for (int attempt = 0; attempt < 3; attempt++) {
      if (completer.isCompleted) break;

      if (_isCameraInitialized && _cameraController != null) {
        try {
          final XFile image = await _cameraController!.takePicture();
          final emotion = await _analyzeFaceEmotionForAlert(image);

          if (emotion.isNotEmpty) {
            setState(() {
              _lastEmotionForAlert = emotion;
            });

            if (_isEmotionOkay(emotion)) {
              if (!completer.isCompleted) {
                completer.complete('ok');
              }
              break;
            }
          }
        } catch (e) {
          print('Error in emotion check: $e');
        }
      }

      await Future.delayed(const Duration(seconds: 2));
    }

    if (!completer.isCompleted) {
      completer.complete('not_ok');
    }
  }

  bool _isEmotionOkay(String emotion) {
    final okayEmotions = ['happy', 'neutral', 'surprised'];
    return okayEmotions.any((ok) => emotion.toLowerCase().contains(ok));
  }

  Color _getEmotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy': return Colors.green;
      case 'neutral': return Colors.blue;
      case 'sad': return Colors.blueGrey;
      case 'angry': return Colors.red;
      case 'surprised': return Colors.orange;
      default: return Colors.grey;
    }
  }

  Future<String> _analyzeFaceEmotionForAlert(XFile image) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String url = prefs.getString("url") ?? "";
    final String patientId = prefs.getString("lid") ?? "";

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$url/analyze_emotion/'));
      request.fields['patient_id'] = patientId;
      request.fields['is_emergency_check'] = 'true';

      var multipartFile = await http.MultipartFile.fromPath('image', image.path);
      request.files.add(multipartFile);

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final data = json.decode(responseData);

      if (response.statusCode == 200 && data['status'] == 'success') {
        return data['emotion']?.toString().toLowerCase() ?? 'unknown';
      }
    } catch (e) {
      print('❌ Error analyzing emotion: $e');
    }
    return 'unknown';
  }

  // ================================================
  // CAMERA FUNCTIONS
  // ================================================

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();

      if (_cameras != null && _cameras!.isNotEmpty) {
        final frontCamera = _cameras!.firstWhere(
              (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras!.first,
        );

        _cameraController = CameraController(
          frontCamera,
          ResolutionPreset.medium,
          enableAudio: false,
        );

        await _cameraController!.initialize();

        setState(() {
          _isCameraInitialized = true;
        });

        _startEmotionCapture();
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  void _startEmotionCapture() {
    if (!_isCameraInitialized || _isEmotionCaptureActive) return;

    setState(() {
      _isEmotionCaptureActive = true;
    });

    _captureAndSendEmotion();

    _emotionCaptureTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      _captureAndSendEmotion();
    });
  }

  void _stopEmotionCapture() {
    _emotionCaptureTimer?.cancel();
    setState(() {
      _isEmotionCaptureActive = false;
    });
  }

  Future<void> _captureAndSendEmotion() async {
    if (!_isCameraInitialized || _cameraController == null) return;

    try {
      final XFile image = await _cameraController!.takePicture();
      await _sendImageToPython(image);
      _captureCount++;
      if (mounted) {
        setState(() {
          _lastEmotionResult = 'Last capture: ${DateFormat('HH:mm:ss').format(DateTime.now())}';
        });
      }
    } catch (e) {
      print('❌ Error capturing emotion: $e');
    }
  }

  Future<void> _sendImageToPython(XFile image) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String url = prefs.getString("url") ?? "";
    final String patientId = prefs.getString("lid") ?? "";

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$url/analyze_emotion/'));
      request.fields['patient_id'] = patientId;
      request.fields['timestamp'] = DateTime.now().toIso8601String();

      var multipartFile = await http.MultipartFile.fromPath('image', image.path);
      request.files.add(multipartFile);

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final data = json.decode(responseData);

      if (response.statusCode == 200 && data['status'] == 'success') {
        final emotion = data['emotion'] ?? 'Unknown';
        final confidence = data['confidence'] ?? 0.0;

        if (mounted) {
          setState(() {
            _lastEmotionResult = 'Emotion: $emotion (${(confidence * 100).toStringAsFixed(1)}%)';
          });
        }

        if (emotion.toLowerCase() == 'sad' || emotion.toLowerCase() == 'angry') {
          _showEmotionAlert(emotion, confidence);
        }
      }
    } catch (e) {
      print('❌ Error sending image: $e');
    }
  }

  void _showEmotionAlert(String emotion, double confidence) {
    Fluttertoast.showToast(
      msg: 'Detected $emotion emotion. Would you like to talk?',
      backgroundColor: Colors.orange,
      textColor: Colors.white,
    );
  }

  // ================================================
  // AUDIO RECORDING FUNCTIONS
  // ================================================

  Future<void> _initAudioRecorder() async {
    _audioRecorder = AudioRecorder();
    await Permission.microphone.request();
  }

  Future<void> _startAudioRecording() async {
    try {
      final directory = await getTemporaryDirectory();
      _audioFilePath = '${directory.path}/medicine_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(const RecordConfig(), path: _audioFilePath!);
      setState(() {
        _isRecordingAudio = true;
        _hasRecordedAudio = false;
        _transcribedText = '';
      });

      _speakMessageMalayalam("റെക്കോർഡിംഗ് ആരംഭിച്ചു. ദയവായി നിങ്ങളുടെ ശബ്ദം റെക്കോർഡ് ചെയ്യുക.");
    } catch (e) {
      print("❌ Error starting audio recording: $e");
    }
  }

  Future<void> _stopAudioRecording() async {
    try {
      String? recordedPath = await _audioRecorder.stop();

      setState(() {
        _isRecordingAudio = false;
        _audioFilePath = recordedPath ?? _audioFilePath;
        _hasRecordedAudio = true;
      });

      _startListeningForTranscription();
    } catch (e) {
      print("❌ Error stopping audio recording: $e");
    }
  }

  void _startListening() {
    _startListeningForTranscription();
  }

  Future<void> _startListeningForTranscription() async {
    if (!_speechEnabled) return;

    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }

    if (status.isGranted) {
      setState(() {
        _isListening = true;
        _transcribedText = '';
      });

      _speech.listen(
        onResult: (result) {
          setState(() {
            _transcribedText = result.recognizedWords;
          });

          if (result.finalResult) {
            setState(() {
              _isListening = false;
            });
          }
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: 'en-US',
      );
    }
  }

  void _stopListening() {
    setState(() => _isListening = false);
    _speech.stop();
  }

  // ================================================
  // UI BUILD METHODS
  // ================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FDF8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1B5E20),
        elevation: 2,
        title: const Text(
          'MindCare Connect',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
        ),
        actions: [
          if (_missedMedicines.isNotEmpty)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.warning_amber_rounded),
                  onPressed: _viewMissedMedicines,
                  tooltip: 'Missed Medicines',
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _missedMedicines.length.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: _toggleSummaryAssistant,
            tooltip: 'Today\'s Summary',
          ),
          IconButton(
            icon: const Icon(Icons.mic_rounded),
            onPressed: _toggleMedicineAssistant,
            tooltip: 'Medicine Confirmation',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadHomeData,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout')
                _logout();
              else if (value == 'profile')
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => UserProfileViewPage()),
                );
              else if (value == 'missed_medicines')
                _viewMissedMedicines();
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_rounded, color: const Color(0xFF1B5E20)),
                    const SizedBox(width: 8),
                    const Text('My Profile'),
                  ],
                ),
              ),
              if (_missedMedicines.isNotEmpty)
                PopupMenuItem(
                  value: 'missed_medicines',
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text('Missed Medicines (${_missedMedicines.length})'),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, color: Colors.red),
                    const SizedBox(width: 8),
                    const Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: _isLoading ? _buildLoadingState() : _buildHomeContent(),
          ),
          _buildVoiceAssistant(),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset('assets/ani7.json', width: 150, height: 150),
          const SizedBox(height: 20),
          Text(
            'Loading your health dashboard...',
            style: TextStyle(fontSize: 16, color: const Color(0xFF1B5E20)),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(),
          const SizedBox(height: 24),
          _buildQuickStats(),
          const SizedBox(height: 24),
          _buildEmotionCaptureSection(),
          const SizedBox(height: 24),
          _buildMissedMedicinesSection(),
          _buildEmergencySettings(),
          const SizedBox(height: 24),
          _buildMedicineReminders(),
          const SizedBox(height: 24),
          _buildAppointmentReminders(),
          const SizedBox(height: 24),
          _buildHealthTips(),
          const SizedBox(height: 24),
          _buildEmergencySection(),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    final now = DateTime.now();
    final formattedDate = DateFormat('EEEE, MMMM d').format(now);
    final greeting = _getGreeting(now);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, $patientName!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your health is our priority',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                if (_speechEnabled) const SizedBox(height: 8),
                if (_speechEnabled)
                  const Text(
                    'Tap the info or microphone icon for voice assistance',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
              ],
            ),
          ),
          Lottie.asset('assets/ani3.json', width: 100, height: 150),
        ],
      ),
    );
  }

  String _getGreeting(DateTime time) {
    final hour = time.hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        _buildStatCard(
          'Today\'s Medicines',
          _totalMedicinesToday.toString(),
          Icons.medication_rounded,
          const Color(0xFF2E7D32),
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          'Upcoming Appointments',
          _pendingAppointments.toString(),
          Icons.calendar_today_rounded,
          const Color(0xFF1976D2),
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          'Missed Medicines',
          _missedMedicines.length.toString(),
          Icons.warning_amber_rounded,
          _missedMedicines.isEmpty ? Colors.grey : Colors.orange,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceAssistant() {
    if (!_showMedicineAssistant && !_showSummaryAssistant) {
      return const SizedBox.shrink();
    }

    final isMedicine = _showMedicineAssistant;
    final assistantTitle = isMedicine ? 'Medicine Assistant' : 'Today\'s Summary';
    final assistantColor = isMedicine ? Colors.blue : const Color(0xFF2E7D32);

    return Positioned(
      bottom: 80,
      right: 20,
      child: Container(
        width: isMedicine ? 300 : 350,
        height: isMedicine ? 400 : 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: isMedicine
            ? _buildMedicineAssistant(assistantTitle, assistantColor)
            : _buildSummaryAssistant(assistantTitle, assistantColor),
      ),
    );
  }

  Widget _buildSummaryAssistant(String title, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.today_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.today_rounded, size: 12, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM d, yyyy').format(DateTime.now()),
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.access_time_rounded, size: 12, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('hh:mm a').format(DateTime.now()),
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    height: 60,
                    child: Lottie.asset('assets/ani3.json', fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 8),

                  if (_summaryAssistantMessage.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withOpacity(0.2)),
                      ),
                      child: Text(
                        _summaryAssistantMessage,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildStatChip(
                        'Medicines',
                        _totalMedicinesToday.toString(),
                        Icons.medication_rounded,
                        _totalMedicinesToday > 0 ? Colors.orange : Colors.grey,
                      ),
                      _buildStatChip(
                        'Appointments',
                        _pendingAppointments.toString(),
                        Icons.calendar_today_rounded,
                        _pendingAppointments > 0 ? Colors.blue : Colors.grey,
                      ),
                      _buildStatChip(
                        'Missed',
                        _missedMedicines.length.toString(),
                        Icons.warning_amber_rounded,
                        _missedMedicines.length > 0 ? Colors.red : Colors.grey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          final summary = _getTodaysSummary();
                          _speakMessage(summary);
                        },
                        icon: const Icon(Icons.volume_up_rounded, size: 16),
                        label: const Text('Speak'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                      ),

                      ElevatedButton.icon(
                        onPressed: _toggleSummaryAssistant,
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Close'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  const Text(
                    'You can say:',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _buildVoiceCommandChip('"Medicines"', color),
                      _buildVoiceCommandChip('"Appointments"', color),
                      _buildVoiceCommandChip('"Time"', color),
                      _buildVoiceCommandChip('"Date"', color),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$value $label',
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceCommandChip(String command, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Text(
        command,
        style: TextStyle(
          fontSize: 9,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMedicineAssistant(String title, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.medication_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),

        Container(
          height: 100,
          child: Lottie.asset('assets/ani8.json', fit: BoxFit.contain),
        ),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Text(
                    _medicineAssistantMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 12),

                  if (_isRecordingAudio)
                    _buildStatusIndicator('Recording audio...', Colors.red, Icons.radio_button_checked),
                  if (_transcribedText.isNotEmpty)
                    _buildStatusIndicator('"$_transcribedText"', Colors.green, Icons.transcribe_rounded),
                  if (_hasRecordedAudio && _audioFilePath != null)
                    _buildAudioFileStatus(),
                ],
              ),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              ElevatedButton.icon(
                onPressed: _isRecordingAudio ? _stopAudioRecording : _startAudioRecording,
                icon: Icon(
                  _isRecordingAudio ? Icons.stop : Icons.mic,
                  size: 20,
                ),
                label: Text(_isRecordingAudio ? 'Stop Recording' : 'Record Voice'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRecordingAudio ? Colors.red : color,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 45),
                ),
              ),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton.small(
                    onPressed: _isListening ? _stopListening : _startListening,
                    child: Icon(_isListening ? Icons.mic_off : Icons.mic),
                    backgroundColor: _isListening ? Colors.red : Colors.blue,
                    tooltip: 'Speech Recognition',
                  ),

                  if (_hasRecordedAudio && _todayMedicines.isNotEmpty)
                    FloatingActionButton(
                      onPressed: () => _confirmMedicineWithVoice(_todayMedicines.first),
                      child: const Icon(Icons.check_rounded),
                      backgroundColor: Colors.green,
                      tooltip: 'Confirm Medicine',
                    ),

                  FloatingActionButton.small(
                    onPressed: _toggleMedicineAssistant,
                    child: const Icon(Icons.close),
                    backgroundColor: Colors.grey,
                    tooltip: 'Close',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAudioFileStatus() {
    if (_audioFilePath == null || !_hasRecordedAudio) {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          const Icon(Icons.audio_file_rounded, color: Colors.blue, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Audio Recorded',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                FutureBuilder<int>(
                  future: File(_audioFilePath!).length(),
                  builder: (context, snapshot) {
                    return Text(
                      snapshot.hasData ? '${(snapshot.data! / 1024).toStringAsFixed(1)} KB' : 'Calculating size...',
                      style: TextStyle(
                        color: Colors.blue.shade600,
                        fontSize: 10,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String text, Color color, IconData icon) {
    Color backgroundColor;
    Color borderColor;
    Color textColor;

    if (color == Colors.red) {
      backgroundColor = Colors.red.shade50;
      borderColor = Colors.red.shade100;
      textColor = Colors.red.shade700;
    } else if (color == Colors.green) {
      backgroundColor = Colors.green.shade50;
      borderColor = Colors.green.shade100;
      textColor = Colors.green.shade700;
    } else if (color == Colors.blue) {
      backgroundColor = Colors.blue.shade50;
      borderColor = Colors.blue.shade100;
      textColor = Colors.blue.shade700;
    } else {
      backgroundColor = color.withOpacity(0.1);
      borderColor = color.withOpacity(0.3);
      textColor = color;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: textColor, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildMissedMedicinesSection() {
    if (_missedMedicines.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              'Missed Medicines Alert',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._missedMedicines.map((medicine) => _buildMissedMedicineCard(medicine)).toList(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMissedMedicineCard(Map<String, dynamic> medicine) {
    final missedCount = medicine['missed_count'] ?? 0;
    final emergencyTriggered = medicine['emergency_triggered'] == true;
    final displayTime = _formatTimeForDisplay(medicine['scheduled_time'] ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: emergencyTriggered ? Colors.red.shade50 : (missedCount >= 3 ? Colors.red.shade50 : Colors.orange.shade50),
      child: ListTile(
        leading: Icon(
          Icons.medication_rounded,
          color: emergencyTriggered ? Colors.red : (missedCount >= 3 ? Colors.red : Colors.orange),
        ),
        title: Text(
          medicine['medicine_name'],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: emergencyTriggered ? Colors.red : (missedCount >= 3 ? Colors.red : Colors.orange),
          ),
        ),
        subtitle: Text(
          'Missed $missedCount time${missedCount > 1 ? 's' : ''} • $displayTime${emergencyTriggered ? ' - Emergency Called' : ''}',
          style: TextStyle(color: emergencyTriggered ? Colors.red : (missedCount >= 3 ? Colors.red : Colors.orange)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emergencyTriggered)
              const Icon(Icons.emergency_rounded, color: Colors.red),
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: () => _markMedicineAsTaken(medicine),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineReminders() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.notifications_active_rounded, color: const Color(0xFF2E7D32)),
            const SizedBox(width: 8),
            Text(
              'Medicine Reminders',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1B5E20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_todayMedicines.isEmpty)
          _buildEmptyState(
            'No medicines scheduled for today',
            'assets/ani4.json',
            'All caught up! Enjoy your day.',
          )
        else
          ..._todayMedicines.map((medicine) => _buildMedicineCard(medicine)).toList(),
      ],
    );
  }

  Widget _buildMedicineCard(Map<String, dynamic> medicine) {
    final medicineId = medicine['id'].toString();
    final missedCount = _medicineMissedCount[medicineId] ?? 0;
    final reminderCount = _reminderCount[medicineId] ?? 0;
    final displayTime = _formatTimeForDisplay(medicine['scheduled_time'] ?? 'N/A');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: reminderCount >= 3 ? Colors.red.shade50 :
      (missedCount > 0 ? (missedCount >= 3 ? Colors.red.shade50 : Colors.orange.shade50) : Colors.white),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: reminderCount >= 3 ? Colors.red.withOpacity(0.1) :
                missedCount >= 3 ? Colors.red.withOpacity(0.1) :
                missedCount > 0 ? Colors.orange.withOpacity(0.1) :
                const Color(0xFF2E7D32).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                  Icons.medication_rounded,
                  color: reminderCount >= 3 ? Colors.red :
                  missedCount >= 3 ? Colors.red :
                  missedCount > 0 ? Colors.orange :
                  const Color(0xFF2E7D32)
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicine['medicine_name'] ?? 'Unknown Medicine',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: reminderCount >= 3 ? Colors.red :
                      missedCount >= 3 ? Colors.red :
                      missedCount > 0 ? Colors.orange :
                      const Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${medicine['dosage'] ?? 'N/A'} • $displayTime',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  if (reminderCount > 0)
                    Text(
                      'Reminder $reminderCount/3',
                      style: TextStyle(
                        color: reminderCount >= 3 ? Colors.red : Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (missedCount > 0 && reminderCount == 0)
                    Text(
                      'Missed $missedCount time${missedCount > 1 ? 's' : ''}',
                      style: TextStyle(
                        color: missedCount >= 3 ? Colors.red : Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
            Row(
              children: [
                if (reminderCount >= 3 || missedCount >= 3)
                  const Icon(Icons.emergency_rounded, color: Colors.red, size: 20),
                IconButton(
                  icon: const Icon(Icons.info_outline_rounded, size: 20),
                  onPressed: () => _showMedicineDetails(medicine),
                  color: const Color(0xFF2E7D32),
                ),
                IconButton(
                  icon: const Icon(Icons.mic_rounded, size: 20),
                  onPressed: () {
                    _toggleMedicineAssistant();
                    Future.delayed(const Duration(milliseconds: 500), () {
                      _speakMessageMalayalam("Record your voice to confirm ${medicine['medicine_name']}.");
                    });
                  },
                  color: Colors.blue,
                ),
                IconButton(
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                  onPressed: () => _markMedicineAsTaken(medicine),
                  color: Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showMedicineDetails(Map<String, dynamic> medicinePlan) {
    final displayTime = _formatTimeForDisplay(medicinePlan['scheduled_time'] ?? 'N/A');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.medication_rounded,
                    color: Color(0xFF2E7D32),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Medicine Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Medicine', medicinePlan['medicine_name'] ?? 'N/A'),
              _buildDetailRow('Dosage', medicinePlan['dosage'] ?? 'N/A'),
              _buildDetailRow('Time', displayTime),
              _buildDetailRow('Frequency', medicinePlan['frequency'] ?? 'N/A'),
              _buildDetailRow('Instructions', medicinePlan['instructions'] ?? 'No special instructions'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Close'),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final hasResponded = appointment['responded'] == true;
    final response = appointment['response'];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: hasResponded
            ? BorderSide(
          color: response == 'go' ? Colors.green : Colors.orange,
          width: 2,
        )
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: hasResponded
                    ? (response == 'go' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1))
                    : const Color(0xFF1976D2).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasResponded
                    ? (response == 'go' ? Icons.check_circle : Icons.cancel)
                    : Icons.medical_services_rounded,
                color: hasResponded
                    ? (response == 'go' ? Colors.green : Colors.orange)
                    : const Color(0xFF1976D2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Dr. ${appointment['doctor_name'] ?? 'Unknown'}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: hasResponded
                                ? (response == 'Visited' ? Colors.green : Colors.orange)
                                : const Color(0xFF1B5E20),
                          ),
                        ),
                      ),
                      if (hasResponded)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: response == 'Visited' ? Colors.green : Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            response == 'Visited' ? 'Confirmed' : 'Declined',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    appointment['hospital_name'] ?? 'Clinic',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        _formatAppointmentDate(appointment['appointment_date'] ?? ''),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        appointment['appointment_time'] ?? 'N/A',
                        style: const TextStyle(
                          color: Color(0xFF1976D2),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

// Update the _loadUpcomingAppointments function to handle response status
  Future<void> _loadUpcomingAppointments() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String url = prefs.getString("url") ?? "";
    String lid = prefs.getString("lid") ?? "";

    try {
      final response = await http.get(
        Uri.parse('$url/upcoming_appointments/?patient_id=$lid'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'ok') {
          // Convert the data to a mutable list
          final List<dynamic> appointments = List.from(data['data']);

          // Add responded flag to each appointment (you might want to load this from backend)
          for (var appointment in appointments) {
            appointment['responded'] = false; // Default to not responded
          }

          setState(() {
            _upcomingAppointments = appointments;
            _pendingAppointments = _upcomingAppointments.length;
          });
        }
      }
    } catch (e) {
      print("❌ Error loading upcoming appointments: $e");
    }
  }

// Add this helper function to handle appointment responses
  void _handleAppointmentResponse(dynamic appointment, String response) {
    setState(() {
      final index = _upcomingAppointments.indexWhere((a) =>
      a['id'] == appointment['id'] ||
          (a['appointment_date'] == appointment['appointment_date'] &&
              a['appointment_time'] == appointment['appointment_time'])
      );

      if (index != -1) {
        _upcomingAppointments[index]['responded'] = true;
        _upcomingAppointments[index]['response'] = response;
      }
    });

    // Show confirmation message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response == 'Visited'
            ? 'You have confirmed to attend the appointment'
            : 'You have declined the appointment'),
        backgroundColor: response == 'gVisitedo' ? Colors.green : Colors.orange,
      ),
    );

    // Optionally send to backend
    _sendAppointmentResponseToServer(appointment, response);
  }

// Optional: Send response to backend
  Future<void> _sendAppointmentResponseToServer(dynamic appointment, String response) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      String url = prefs.getString("url") ?? "";
      String patientId = prefs.getString("lid") ?? "";

      await http.post(
        Uri.parse('$url/appointment_response/'),
        body: {
          'appointment_id': appointment['id']?.toString() ?? '',
          'patient_id': patientId,
          'response': response,
          'response_time': DateTime.now().toIso8601String(),
        },
      );

      print('✅ Appointment response sent successfully');
    } catch (e) {
      print('❌ Error sending appointment response: $e');
    }
  }

// Update _buildAppointmentReminders to include the response buttons
  Widget _buildAppointmentReminders() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today_rounded, color: const Color(0xFF1976D2)),
            const SizedBox(width: 8),
            Text(
              'Upcoming Appointments',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1B5E20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_upcomingAppointments.isEmpty)
          _buildEmptyState(
            'No upcoming appointments',
            'assets/ani5.json',
            'Schedule your next checkup when needed.',
          )
        else
          ..._upcomingAppointments.map((appointment) => Column(
            children: [
              _buildAppointmentCard(appointment),
              if (appointment['responded'] != true)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () => _handleAppointmentResponse(appointment, 'Visited'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Visited'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _handleAppointmentResponse(appointment, 'not_Visited'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('NOT Visited'),
                      ),
                    ],
                  ),
                ),
              if (appointment['responded'] == true)
                const SizedBox(height: 16),
            ],
          )).toList(),
      ],
    );
  }

  Color _getAppointmentStatusColor(String appointmentDate) {
    final now = DateTime.now();
    final appointment = DateTime.tryParse(appointmentDate);
    if (appointment == null) return Colors.grey;
    if (appointment.isBefore(now)) return Colors.green;
    if (appointment.difference(now).inDays <= 1) return Colors.orange;
    return const Color(0xFF1976D2);
  }

  String _getAppointmentStatusText(String appointmentDate) {
    final now = DateTime.now();
    final appointment = DateTime.tryParse(appointmentDate);
    if (appointment == null) return 'Unknown';
    final difference = appointment.difference(now);
    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Tomorrow';
    if (difference.inDays < 0) return 'Past';
    return '${difference.inDays}d';
  }

  String _formatAppointmentDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM d').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildHealthTips() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.health_and_safety_rounded, color: const Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              const Text(
                'Dementia Care Tips',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5E20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTipItem('Establish a daily routine for consistency'),
          _buildTipItem('Use reminders and notes for important tasks'),
          _buildTipItem('Stay physically active with gentle exercises'),
          _buildTipItem('Engage in mentally stimulating activities'),
          _buildTipItem('Maintain social connections and interactions'),
        ],
      ),
    );
  }

  Widget _buildTipItem(String tip) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded, size: 16, color: const Color(0xFF2E7D32)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFEE5A52)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Lottie.asset('assets/ani6.json', width: 60, height: 100),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Emergency Contact',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Need immediate help? Contact your caregiver or emergency services',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.phone_rounded, color: Colors.white),
            onPressed: () {
              _makeEmergencyCall('112', patientName, 'Emergency', 1);
              Fluttertoast.showToast(
                msg: 'Calling emergency services...',
                backgroundColor: Colors.red,
                textColor: Colors.white,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String lottieAsset, String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Lottie.asset(lottieAsset, width: 100, height: 100),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmotionCaptureSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.face_retouching_natural_rounded, color: Colors.purple),
              const SizedBox(width: 8),
              Text(
                'Emotion Monitoring',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
              const Spacer(),
              if (_isCheckingEmotionForAlert)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.emergency_rounded, color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      const Text(
                        'Emergency Check',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isEmotionCaptureActive ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        color: Colors.white,
                        size: 8,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isEmotionCaptureActive ? 'Active' : 'Inactive',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (_isCameraInitialized && _cameraController != null)
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CameraPreview(_cameraController!),
              ),
            )
          else
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_rounded, color: Colors.grey, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    'Camera Initializing...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.purple.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_rounded, color: Colors.purple, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Status',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _lastEmotionResult.isEmpty
                      ? 'Monitoring your emotions automatically every 20 seconds'
                      : _lastEmotionResult,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
                const SizedBox(height: 4),
                Text(
                  'Captures: $_captureCount images',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isCameraInitialized
                      ? (_isEmotionCaptureActive ? _stopEmotionCapture : _startEmotionCapture)
                      : null,
                  icon: Icon(
                    _isEmotionCaptureActive ? Icons.stop : Icons.play_arrow,
                    size: 20,
                  ),
                  label: Text(_isEmotionCaptureActive ? 'Stop Monitoring' : 'Start Monitoring'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isEmotionCaptureActive ? Colors.orange : Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _isCameraInitialized ? _captureAndSendEmotion : null,
                icon: const Icon(Icons.camera_alt_rounded),
                tooltip: 'Capture Now',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          const Text(
            'Your facial expressions are automatically analyzed to help monitor your emotional well-being.',
            style: TextStyle(
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencySettings() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emergency_rounded, color: Colors.red),
              const SizedBox(width: 8),
              const Text(
                'Emergency Features',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_emergencyStatus.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('Last Activity: ${_getLastActivityTime()}', style: const TextStyle(fontSize: 10)),
                  Text('Contacts: ${_emergencyStatus['emergencyContacts'] ?? 'Unknown'}', style: const TextStyle(fontSize: 10)),
                  Text('Threshold: ${_emergencyStatus['inactivityThreshold'] ?? 'Unknown'} min', style: const TextStyle(fontSize: 10)),
                ],
              ),
            ),
          const SizedBox(height: 8),

          if (_lastAlert.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Last Alert: $_lastAlert',
                      style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),

          if (_isCheckingEmotionForAlert)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.face_retouching_natural_rounded, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Emergency Face Check in Progress',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Checking if you\'re okay before sending alert',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),

          _buildEmergencySettingItem(
            'Shake to Alert',
            'Shake phone to send emergency alert (with face check)',
            _emergencyFeaturesEnabled,
                (value) => _toggleEmergencyFeatures(value),
          ),
          _buildEmergencySettingItem(
            'Inactivity Monitoring',
            'Alert if phone inactive for 30+ minutes (with face check)',
            _emergencyFeaturesEnabled,
                (value) => _toggleEmergencyFeatures(value),
          ),
          const SizedBox(height: 8),
          const Text(
            'Before sending alerts, face emotion will be checked. If no face detected within 25 seconds, alert will be sent.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _emergencyFeaturesEnabled ? _testEmergencyAlert : null,
                  icon: const Icon(Icons.emergency_rounded, size: 20),
                  label: const Text('Test Alert'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _emergencyFeaturesEnabled ? _simulateActivity : null,
                  icon: const Icon(Icons.directions_walk_rounded, size: 20),
                  label: const Text('Simulate Activity'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getLastActivityTime() {
    final lastActivity = _emergencyStatus['lastActivity'];
    if (lastActivity == null) return 'Unknown';

    try {
      final parts = lastActivity.split(' ');
      return parts.length > 1 ? parts[1] : parts[0];
    } catch (e) {
      return 'Unknown';
    }
  }

  Widget _buildEmergencySettingItem(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.red,
          ),
        ],
      ),
    );
  }

  Future<void> _toggleEmergencyFeatures(bool enabled) async {
    setState(() {
      _emergencyFeaturesEnabled = enabled;
    });

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('emergency_features', enabled);

    if (enabled) {
      await _emergencyService.initialize(
        alertCallback: _showEmergencyAlert,
        faceCheckCallback: checkFaceEmotionBeforeAlert,
      );
      _updateEmergencyStatus();
    } else {
      _emergencyService.dispose();
      setState(() {
        _emergencyStatus = {};
        _lastAlert = '';
      });
    }

    Fluttertoast.showToast(
      msg: enabled ? 'Emergency features enabled' : 'Emergency features disabled',
      backgroundColor: enabled ? Colors.green : Colors.orange,
    );
  }

  void _testEmergencyAlert() {
    _emergencyService.triggerManualEmergency();
  }

  void _simulateActivity() {
    _emergencyService.simulateActivity();
    _updateEmergencyStatus();
    Fluttertoast.showToast(
      msg: 'Activity simulated - timer reset',
      backgroundColor: Colors.green,
    );
  }

  void _showCameraErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Not Available'),
        content: const Text('Face emotion capture requires camera access. Please enable camera permissions in your device settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => IPPage(title: '')),
              );
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}