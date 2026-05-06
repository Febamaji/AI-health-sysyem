from django.contrib.auth.models import User
from django.db import models

# Create your models here.
class FamilyMember(models.Model):
    LOGIN=models.OneToOneField(User,on_delete=models.CASCADE)
    NAME = models.CharField(max_length=100)
    GENDER = models.CharField(max_length=100)
    PHONE_NUMBER = models.CharField(max_length=20)
    EMAIL = models.EmailField()
    ADDRESS=models.CharField(max_length=100)
class Patient(models.Model):
    LOGIN=models.OneToOneField(User,on_delete=models.CASCADE)
    FAMILYMEMBER=models.OneToOneField(FamilyMember,on_delete=models.CASCADE)
    NAME = models.CharField(max_length=100)
    PHONE_NUMBER = models.CharField(max_length=20)
    DATE_OF_BIRTH = models.CharField(max_length=100)
    GENDER = models.CharField(max_length=100)
    ADDRESS = models.TextField()
    sleep_start_time = models.TimeField(default='22:00')
    sleep_end_time = models.TimeField(default='06:00')
    face_encoding = models.TextField(null=True, blank=True)
    face_image = models.ImageField(upload_to='face_images/', null=True, blank=True)
    EMAIL=models.CharField(max_length=100)
    relationship = models.CharField(max_length=20)
    AGE=models.CharField(max_length=100)


class Medicine(models.Model):
    PATIENT=models.OneToOneField(Patient,on_delete=models.CASCADE)
    name = models.CharField(max_length=100)
    description = models.TextField(blank=True)
    medicine_type = models.CharField(max_length=20, default='TABLET')
    dosage_strength = models.CharField(max_length=50, blank=True)  # e.g., "500mg", "10mg/mL"
    stock_quantity = models.IntegerField(default=0)
    low_stock_threshold = models.IntegerField(default=10)

class MedicinePlan(models.Model):
    PATIENT=models.OneToOneField(Patient,on_delete=models.CASCADE)
    MEDICINE=models.OneToOneField(Medicine,on_delete=models.CASCADE)
    dosage = models.CharField(max_length=50)  # e.g., "1 tablet", "5ml"
    scheduled_time = models.CharField(max_length=100)
    frequency = models.CharField(max_length=20, default='DAILY')

    days_of_week = models.CharField(
        max_length=13,
        default='1,2,3,4,5,6,7',  # Monday-Sunday
        help_text="Comma separated days (1=Monday, 7=Sunday)"
    )

    is_active = models.BooleanField(default=True)
    start_date = models.CharField(max_length=100)
    end_date = models.CharField(max_length=100)
    instructions = models.TextField(blank=True)

class MedicationLog(models.Model):
    MEDICINEPLAN=models.OneToOneField(MedicinePlan,on_delete=models.CASCADE)
    scheduled_time = models.CharField(max_length=100)
    taken_time = models.DateTimeField(null=True, blank=True)
    status = models.CharField(max_length=10,  default='PENDING')
    method = models.CharField(max_length=10, null=True, blank=True)
    voice_transcription = models.TextField(blank=True)
    voice_audio_file = models.ImageField()  # Store file path as string
    notes = models.TextField(blank=True)

class SleepMonitoring(models.Model):
    PATIENT=models.OneToOneField(Patient,on_delete=models.CASCADE)
    sleep_start_time = models.DateTimeField()
    sleep_end_time = models.DateTimeField(null=True, blank=True)
    sleep_duration = models.IntegerField(null=True, blank=True)  # in minutes
    sleep_quality_score = models.IntegerField(null=True, blank=True)  # 1-10 scale
    wake_up_count = models.IntegerField(default=0)
    notes = models.TextField(blank=True)

class Appointment(models.Model):
    PATIENT=models.OneToOneField(Patient,on_delete=models.CASCADE)
    doctor_name = models.CharField(max_length=100)
    doctor_specialization = models.CharField(max_length=100, blank=True)
    hospital_name = models.CharField(max_length=200, blank=True)
    appointment_date = models.CharField(max_length=100)
    appointment_time = models.CharField(max_length=100)
    contact_phone = models.CharField(max_length=20, blank=True)
    purpose = models.TextField(blank=True)
    notes = models.TextField(blank=True)
    response=models.CharField(max_length=100)


class EmergencyContact(models.Model):
    patient = models.ForeignKey(Patient, on_delete=models.CASCADE)
    name = models.CharField(max_length=100)
    phone_number = models.CharField(max_length=20)
    relationship = models.CharField(max_length=50)
    is_active = models.BooleanField(default=True)




class EmergencyAlert(models.Model):
    ALERT_TYPES = [
        ('SHAKE_DETECTED', 'Shake Detected'),
        ('INACTIVITY', 'Inactivity'),
        ('MANUAL', 'Manual'),
        ('TEST', 'Test'),
    ]

    patient = models.ForeignKey(Patient, on_delete=models.CASCADE)
    contact_number = models.CharField(max_length=20)
    alert_type = models.CharField(max_length=20, choices=ALERT_TYPES)
    message = models.TextField()
    location = models.TextField(blank=True, null=True)
    timestamp = models.DateTimeField()
    is_sent = models.BooleanField(default=False)
    status=models.CharField(max_length=100)
class EmotionRecord(models.Model):
    patient = models.ForeignKey(Patient, on_delete=models.CASCADE)
    emotion = models.CharField(max_length=20)
    confidence = models.FloatField()
    time = models.DateTimeField(auto_now_add=True)
class review(models.Model):
    FamilyMember = models.ForeignKey(FamilyMember, on_delete=models.CASCADE)
    review=models.CharField(max_length=100)
    rate=models.CharField(max_length=100)
    date=models.CharField(max_length=100)
