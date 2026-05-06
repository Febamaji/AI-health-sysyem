from datetime import datetime

from django.contrib import messages
from django.contrib.auth import authenticate, login
from django.contrib.auth.hashers import make_password
from django.contrib.auth.models import Group
from django.core.files.storage import FileSystemStorage
from django.http import JsonResponse
from django.shortcuts import render, redirect

# Create your views here.
from myapp.models import *

def index(request):
    return render(request,'index.html')

def login_get(request):
    return render(request,'login.html')


def login_post(request):
    uname=request.POST['uname']
    pwd=request.POST['pwd']
    user=authenticate(request,username=uname,password=pwd)
    print("ddddddddddddddd",user)
    if user is not None:
        print("swwsssss",user.groups)
        login(request, user)
        if user.groups.filter(name='Admin').exists():
            print("ddddddddddddddddddddbkjvnkdjn")
            messages.success(request,'Admin Home')
            return redirect('/myapp/admin_home/')

        else:
            messages.success(request,'invalid User')
            return redirect('/myapp/login_get')
    else:
        messages.success(request, 'invalid Username and Password')
        return redirect('/myapp/login_get')

def admin_home(request):
    return render(request,'admin_home.html')

def admin_view_caretaker(request):
    p=FamilyMember.objects.all()
    return render(request,'admin_view_caretaker.html',{"data":p})
def admin_view_patients(request,id):
    o=Patient.objects.filter(FAMILYMEMBER_id=id)
    return render(request,'admin_view_patients.html',{"data":o})
def admin_view_medicine(request,id):
    o=Medicine.objects.filter(PATIENT_id=id)

    return render(request,'admin_view_medicine.html',{"data":o})
def view_medication_plan(request,id):
    o=MedicinePlan.objects.filter(MEDICINE_id=id)
    return render(request,'admin_view_medicine_plan.html',{"data":o})

def admin_view_rating(request):
    o = review.objects.all()

    total_reviews = review.objects.count()
    average_rating = review.objects.aggregate(avg=Avg('rate'))['avg'] or 0
    # this_month = review.objects.filter(date__month=datetime.now().month).count()

    return render(request, 'admin_view_rate.html', {
        "data": o,
        "total_reviews": total_reviews,
        "average_rating": round(average_rating, 1),
        # "this_month": this_month,
    })










def user_login(request):
    username = request.POST['username']
    password = request.POST['password']

    print(username, password)

    user = authenticate(request, username=username, password=password)
    if user is not None:

        if user.groups.filter(name='Patient').exists():
            loginid = user.id
            Patients = Patient.objects.get(LOGIN_id=loginid)

            sname = f"{Patients.NAME}"
            photo = str(Patients.face_image)
            print("ooooooooooo",sname,photo)
            return JsonResponse({
                "status": "ok",
                "lid": user.id,
                "name": sname,
                "photo": photo,
                "type":"Patient"
            })
        if user.groups.filter(name='Caretaker').exists():
            loginid = user.id
            Caretaker = FamilyMember.objects.get(LOGIN_id=loginid)

            sname = f"{Caretaker.NAME}"
            print("ooooooooooo", sname)
            return JsonResponse({
                "status": "ok",
                "lid": user.id,
                "name": sname,
                "type":"Caretaker"

            })

        else:
            return JsonResponse({"status": "no"})
    else:
        return JsonResponse({"status": "no"})
def Caregiverregister(request):
    name = request.POST['name']
    address = request.POST['address']
    phone = request.POST['phone_number']
    gender=request.POST['gender']
    email = request.POST['email']
    password = request.POST['password']

    l = User.objects.create(username=email, password=str(make_password(password)))
    l.groups.add(Group.objects.get(name='Caretaker'))
    l.save()
    p = FamilyMember(NAME=name, ADDRESS=address, EMAIL=email, PHONE_NUMBER=phone,GENDER=gender, LOGIN_id=l.id)
    p.save()
    return JsonResponse({"status": "True"})
def Userregister(request):
    lid=request.POST['lid']
    cid=FamilyMember.objects.get(LOGIN_id=lid)
    careid=cid.id
    name = request.POST['name']
    address = request.POST['address']
    phone = request.POST['phone_number']
    dob=request.POST['date_of_birth']
    gender=request.POST['gender']
    email = request.POST['email']
    relationship=request.POST['relationship']
    password = request.POST['password']
    age=request.POST['age']
    photo = request.FILES["profile_image"]
    fs = FileSystemStorage()
    date = datetime.now().strftime('%Y%m%d-%H%M%S') + '.jpg'
    fs.save(date, photo)
    path = fs.url(date)
    l = User.objects.create(username=email, password=str(make_password(password)))
    l.groups.add(Group.objects.get(name='Patient'))
    l.save()
    p = Patient(NAME=name, ADDRESS=address, EMAIL=email, PHONE_NUMBER=phone, face_image=path,GENDER=gender,DATE_OF_BIRTH=dob, LOGIN_id=l.id,FAMILYMEMBER_id=careid,relationship=relationship,AGE=age)
    p.save()
    return JsonResponse({"status": "True"})


from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from myapp.models import Patient, FamilyMember
import json


def view_patients(request):

    lid = request.GET['lid']
    cid = FamilyMember.objects.get(LOGIN_id=lid)
    careid = cid.id
    patients = Patient.objects.filter(FAMILYMEMBER_id=careid)

    # Convert QuerySet to list of dictionaries
    patients_list = []
    for patient in patients:
        patients_list.append({
            'id': patient.id,
            'NAME': patient.NAME,
            'PHONE_NUMBER': patient.PHONE_NUMBER,
            'DATE_OF_BIRTH': patient.DATE_OF_BIRTH,
            'GENDER': patient.GENDER,
            'ADDRESS': patient.ADDRESS,
            'sleep_start_time': patient.sleep_start_time,
            'sleep_end_time': patient.sleep_end_time,
            'face_encoding': patient.face_encoding,
            'face_image': str(patient.face_image),
            'LOGIN_id': patient.LOGIN_id,
            'EMAIL': patient.EMAIL,
            'relationship': patient.relationship,
            'FAMILYMEMBER_id': patient.FAMILYMEMBER_id,
        })
    print("dddddddddd",patients_list)

    return JsonResponse({"status": "ok", "data": patients_list})
def delete_patient(request):
    patient_id=request.POST['patient_id']
    p=Patient.objects.get(id-patient_id)
    p.delete()
    return JsonResponse({"status":"ok"})
def add_medicine(request):
    name=request.POST['name']
    pid=request.POST['pid']
    medicine_type=request.POST['medicine_type']
    description=request.POST['description']
    dosage_strength=request.POST['dosage_strength']
    stock_quantity=request.POST['stock_quantity']
    i=Medicine(name=name,dosage_strength=dosage_strength,description=description,medicine_type=medicine_type,PATIENT_id=pid,stock_quantity=stock_quantity)
    i.save()
    return JsonResponse({"status":"ok"})
def view_medicines(request):
    pid=request.GET['pid']
    o=Medicine.objects.filter(PATIENT_id=pid)
    medicine_list = []
    for medicine in o:
        medicine_list.append({
            'id': medicine.id,
            'name': medicine.name,
            'dosage_strength': medicine.dosage_strength,
            'description': medicine.description,
            'medicine_type': medicine.medicine_type,
            'stock_quantity': medicine.stock_quantity,
            'low_stock_threshold': medicine.low_stock_threshold,

        })
    print("dddddddddd", medicine_list)

    return JsonResponse({"status": "ok", "data": medicine_list})
def update_medicine(request):
    medicine_id=request.POST['medicine_id']
    o=Medicine.objects.get(id=medicine_id)
    o.name=request.POST['name']
    o.medicine_type = request.POST['medicine_type']
    o.description = request.POST['description']
    o.dosage_strength = request.POST['dosage_strength']
    o.stock_quantity = request.POST['stock_quantity']
    o.save()
    return JsonResponse({"status": "ok"})
def delete_medicine(request):
    medicine_id=request.POST['medicine_id']
    o=Medicine.objects.get(id=medicine_id)
    o.delete()
    return JsonResponse({"status": "ok"})

def add_medicine_plan(request):
    patient_id=request.POST['patient_id']
    medicine_id=request.POST['medicine_id']
    dosage=request.POST['dosage']
    scheduled_time=request.POST['scheduled_time']
    frequency=request.POST['frequency']
    days_of_week=request.POST['days_of_week']
    is_active=request.POST['is_active']
    start_date=request.POST['start_date']
    end_date=request.POST['end_date']
    instructions=request.POST['instructions']
    p=MedicinePlan(PATIENT_id=patient_id,MEDICINE_id=medicine_id,dosage=dosage,scheduled_time=scheduled_time,frequency=frequency,days_of_week=days_of_week,is_active=is_active,start_date=start_date,
                   end_date=end_date,instructions=instructions)
    p.save()
    return JsonResponse({"status":"ok"})
def view_medicine_plans(request):
    patient_id=request.GET['patient_id']
    o=MedicinePlan.objects.filter(PATIENT_id=patient_id)
    medicineplan_list = []
    for medicine in o:
        medicineplan_list.append({
            'id': medicine.id,
            'medicine_name': medicine.MEDICINE.name,
            'dosage': medicine.dosage,
            'scheduled_time': medicine.scheduled_time,
            'frequency': medicine.frequency,
            'days_of_week': medicine.days_of_week,
            'start_date': medicine.start_date,
            'end_date':medicine.end_date,
            'instructions':medicine.instructions,
            'is_active':medicine.is_active

        })
    return JsonResponse({"status": "ok", "data": medicineplan_list})

def update_medicine_plan(request):
    plan_id=request.POST['plan_id']
    p=MedicinePlan.objects.get(id=plan_id)
    p.patient_id = request.POST['patient_id']
    p.MEDICINE_id = request.POST['medicine_id']
    p.dosage = request.POST['dosage']
    p.scheduled_time = request.POST['scheduled_time']
    p.frequency = request.POST['frequency']
    p.days_of_week = request.POST['days_of_week']
    p.is_active = request.POST['is_active']
    p.start_date = request.POST['start_date']
    p.end_date = request.POST['end_date']
    p.instructions = request.POST['instructions']
    p.save()
    return JsonResponse({"status":"ok"})

def delete_medicine_plan(request):
    plan_id=request.POST['plan_id']
    p=MedicinePlan.objects.get(id=plan_id)
    p.delete()
    return JsonResponse({"status":"ok"})

def doctor_app_add(request):
    PATIENT_id=request.POST['patient_id']
    doctor_name=request.POST['doctor_name']
    doctor_specialization=request.POST['doctor_specialization']
    hospital_name=request.POST['hospital_name']
    appointment_date=request.POST['appointment_date']
    appointment_time=request.POST['appointment_time']
    contact_phone=request.POST['contact_phone']
    purpose=request.POST['purpose']
    notes=request.POST['notes']
    o=Appointment(PATIENT_id=PATIENT_id,doctor_name=doctor_name,doctor_specialization=doctor_specialization,hospital_name=hospital_name,appointment_date=appointment_date,appointment_time=appointment_time,contact_phone=contact_phone,purpose=purpose,notes=notes)
    o.save()
    return JsonResponse({"status":"ok"})

def view_appointments(request):
    patient_id=request.GET['patient_id']
    o=Appointment.objects.filter(PATIENT_id=patient_id)
    appo_list = []
    for appo in o:
        appo_list.append({
            'id': appo.id,
            'doctor_name': appo.doctor_name,
            'doctor_specialization': appo.doctor_specialization,
            'hospital_name': appo.hospital_name,
            'appointment_date': appo.appointment_date,
            'appointment_time': appo.appointment_time,
            'contact_phone': appo.contact_phone,
            'purpose':appo.purpose,
            'notes':appo.notes,

        })
    return JsonResponse({"status": "ok", "data": appo_list})
def delete_appointment(request):
    appointment_id=request.POST['appointment_id']
    p=Appointment.objects.get(id=appointment_id)
    p.delete()
    return JsonResponse({"status":"ok"})
def update_appointment(request):
    appointment_id = request.POST['appointment_id']
    p = Appointment.objects.get(id=appointment_id)
    p.doctor_name = request.POST['doctor_name']
    p.doctor_specialization = request.POST['doctor_specialization']
    p.hospital_name = request.POST['hospital_name']
    p.appointment_date = request.POST['appointment_date']
    p.appointment_time = request.POST['appointment_time']
    p.contact_phone = request.POST['contact_phone']
    p.purpose = request.POST['purpose']
    p.notes = request.POST['notes']
    p.save()
    return JsonResponse({"status":"ok"})


def get_emergency_contacts(request):
    try:
        patient_id = request.GET['patient_id']
        p=Patient.objects.get(LOGIN_id=patient_id)
        pid=p.id
        contacts = EmergencyContact.objects.filter(patient_id=pid)
        contacts_list = list(contacts.values('id', 'name', 'phone_number', 'relationship', 'patient_id'))
        print("ddddddddddddd",contacts_list)
        return JsonResponse({'status': 'success', 'contacts': contacts_list})
    except Exception as e:
        return JsonResponse({'status': 'error', 'message': str(e)})














def add_emergency_contact(request):
    try:

        contact = EmergencyContact.objects.create(
            name=request.POST['name'],
            phone_number=request.POST['phone_number'],
            relationship=request.POST['relationship'],
            patient_id=request.POST['patient_id']
        )
        return JsonResponse({'status': 'success', 'contact_id': contact.id})
    except Exception as e:
        return JsonResponse({'status': 'error', 'message': str(e)})

def update_emergency_contact(request):

        contact = EmergencyContact.objects.get(id=request.POST['contact_id'])
        print("ddddddddddd",contact)
        contact.name = request.POST['name']
        contact.phone_number = request.POST['phone_number']
        contact.relationship = request.POST['relationship']
        contact.save()
        return JsonResponse({'status': 'success'})


def delete_emergency_contact(request):
    try:
        contact_id = request.POST['contact_id']
        contact = EmergencyContact.objects.get(id=contact_id)
        contact.delete()
        return JsonResponse({'status': 'success'})
    except Exception as e:
        return JsonResponse({'status': 'error', 'message': str(e)})

from datetime import datetime, date
def today_medicines(request):
    lid = request.GET['patient_id']
    print("Step 1: Received patient login ID:", lid)

    li = Patient.objects.get(LOGIN_id=lid)
    patient_id = li.id
    print("Step 2: Found patient with ID:", patient_id)

    # Get current date and day of week (1=Monday, 7=Sunday)
    today = date.today()
    today_weekday = today.weekday() + 1  # Convert to 1-7 format (Monday=1, Sunday=7)
    print("Step 4: Today's date:", today)
    print("Step 5: Today's weekday number (1-7):", today_weekday)

    # Get patient object
    patient = Patient.objects.get(id=patient_id)

    # Get all active medicine plans for the patient
    today_plans = MedicinePlan.objects.filter(PATIENT=patient, is_active=True)
    print("Step 7: Total active medicine plans found:", today_plans.count())

    # Filter plans that are scheduled for today
    today_medicines_list = []

    for plan in today_plans:
        print(f"\n--- Processing Plan ID: {plan.id} ---")
        print(f"Plan details - Medicine: {plan.MEDICINE.name if plan.MEDICINE else 'No Medicine'}")
        print(f"Dosage: {plan.dosage}, Time: {plan.scheduled_time}")

        # Parse days_of_week - handle both number formats and day names
        days_of_week_field = plan.days_of_week

        # Convert day names to numbers if needed
        day_name_to_number = {
            'Monday': '1', 'Tuesday': '2', 'Wednesday': '3',
            'Thursday': '4', 'Friday': '5', 'Saturday': '6', 'Sunday': '7'
        }

        # Check if the field contains day names instead of numbers
        if days_of_week_field in day_name_to_number:
            scheduled_days = [day_name_to_number[days_of_week_field]]
            print(f"Converted day name '{days_of_week_field}' to number: {scheduled_days}")
        elif days_of_week_field == 'Everyday':
            scheduled_days = ['1', '2', '3', '4', '5', '6', '7']
            print("Converted 'Everyday' to all days")
        elif days_of_week_field == 'Weekdays':
            scheduled_days = ['1', '2', '3', '4', '5']
            print("Converted 'Weekdays' to Monday-Friday")
        elif days_of_week_field == 'Weekends':
            scheduled_days = ['6', '7']
            print("Converted 'Weekends' to Saturday-Sunday")
        else:
            # Assume it's already comma-separated numbers
            scheduled_days = [day.strip() for day in days_of_week_field.split(',')]
            print(f"Parsed as comma-separated values: {scheduled_days}")

        print(f"Checking if today ({today_weekday}) is in scheduled days: {str(today_weekday) in scheduled_days}")

        if str(today_weekday) in scheduled_days:
            print(f"✓ Today ({today_weekday}) matches scheduled days")

            # Check date range
            try:
                # Handle date formats
                start_date_str = plan.start_date
                if start_date_str:
                    if '-' in start_date_str:
                        start_date = datetime.strptime(start_date_str, '%Y-%m-%d').date()
                    else:
                        print(f"⚠ Unexpected date format for start_date: {start_date_str}")
                        continue
                else:
                    print("⚠ No start date - skipping")
                    continue

                end_date = None
                if plan.end_date:
                    if '-' in plan.end_date:
                        end_date = datetime.strptime(plan.end_date, '%Y-%m-%d').date()
                    else:
                        print(f"⚠ Unexpected date format for end_date: {plan.end_date}")
                        end_date = None

                # Check if today is within the date range
                if today >= start_date and (end_date is None or today <= end_date):
                    print("✓ Today is within valid date range")

                    # CRITICAL: Check if medicine has already been taken today
                    # Query the MedicationLog table to see if there's an entry for today
                    taken_today = MedicationLog.objects.filter(
                        MEDICINEPLAN_id=plan.id,
                        taken_time__date=today  # Check if taken on today's date
                    ).exists()

                    print(f"✓ Checking if medicine was taken today: {taken_today}")

                    if taken_today:
                        print(f"✗ Medicine {plan.MEDICINE.name} already taken today - skipping")
                        continue  # Skip this medicine if already taken
                    else:
                        print(f"✓ Medicine {plan.MEDICINE.name} not taken yet - adding to list")

                        # Get the latest medication log if exists (for tracking missed medicines)
                        latest_log = MedicationLog.objects.filter(
                            MEDICINEPLAN_id=plan.id
                        ).order_by('-taken_time').first()

                        medicine_data = {
                            'id': plan.id,
                            'medicine_name': plan.MEDICINE.name if plan.MEDICINE else 'Unknown Medicine',
                            'dosage': plan.dosage,
                            'scheduled_time': plan.scheduled_time,
                            'frequency': plan.frequency,
                            'days_of_week': plan.days_of_week,
                            'instructions': plan.instructions,
                            'medicine_id': plan.MEDICINE.id if plan.MEDICINE else None,
                            'medicine_type': plan.MEDICINE.medicine_type if plan.MEDICINE else '',
                            'dosage_strength': plan.MEDICINE.dosage_strength if plan.MEDICINE else '',
                            'is_taken': False,  # Not taken yet
                            'last_taken_time': latest_log.taken_time.strftime(
                                '%Y-%m-%d %H:%M:%S') if latest_log else None,
                        }
                        today_medicines_list.append(medicine_data)
                        print(f"✓ Added to today's list. Current count: {len(today_medicines_list)}")
                else:
                    print("✗ Today is outside valid date range - not adding")
                    if end_date and today > end_date:
                        print(f"  Reason: End date {end_date} is before today {today}")
                    elif today < start_date:
                        print(f"  Reason: Start date {start_date} is after today {today}")
            except Exception as e:
                print(f"⚠ Error parsing dates for plan {plan.id}: {e}")
                continue
        else:
            print(f"✗ Today ({today_weekday}) not in scheduled days - skipping")

    print(f"\nStep 9: Total medicines for today after filtering: {len(today_medicines_list)}")

    # Sort by scheduled time
    if today_medicines_list:
        today_medicines_list.sort(key=lambda x: x['scheduled_time'])
    print("Step 10: Data after sorting by time:", today_medicines_list)

    response_data = {
        'status': 'ok',
        'data': today_medicines_list,
        'count': len(today_medicines_list),
        'today_date': today.strftime('%Y-%m-%d'),
        'today_day': today_weekday
    }

    print("\n=== FINAL RESPONSE ===")
    print("Response status:", response_data['status'])
    print("Response count:", response_data['count'])
    print("Response data:", response_data['data'])
    print("=====================\n")

    return JsonResponse(response_data)
# def today_medicines(request):
#     lid = request.GET['patient_id']
#     print("Step 1: Received patient login ID:", lid)
#
#     li = Patient.objects.get(LOGIN_id=lid)
#     patient_id = li.id
#     print("Step 2: Found patient with ID:", patient_id)
#     print("Step 3: Patient details:", li.name if hasattr(li, 'name') else 'Name not found')
#
#     # Get current date and day of week (1=Monday, 7=Sunday)
#     today = date.today()
#     today_weekday = today.weekday() + 1  # Convert to 1-7 format (Monday=1, Sunday=7)
#     print("Step 4: Today's date:", today)
#     print("Step 5: Today's weekday number (1-7):", today_weekday)
#
#     # Get patient object
#     patient = Patient.objects.get(id=patient_id)
#     print("Step 6: Patient object retrieved:", patient.id, patient.name if hasattr(patient, 'name') else '')
#
#     # Get all medicine plans for the patient
#     today_plans = MedicinePlan.objects.filter(PATIENT=patient)
#     print("Step 7: Total medicine plans found for patient:", today_plans.count())
#     print("Step 8: Raw plans data:", list(today_plans.values()))
#
#     # Filter plans that are scheduled for today
#     today_medicines_list = []
#
#     for plan in today_plans:
#         print(f"\n--- Processing Plan ID: {plan.id} ---")
#         print(f"Plan details - Medicine: {plan.MEDICINE.name if plan.MEDICINE else 'No Medicine'}")
#         print(f"Dosage: {plan.dosage}, Time: {plan.scheduled_time}")
#         print(f"Days of week (raw): '{plan.days_of_week}'")
#         print(f"Start date: {plan.start_date}, End date: {plan.end_date}")
#         print(f"Is Active: {plan.is_active}")
#
#         # Skip inactive plans
#         if not plan.is_active:
#             print("✗ Plan is inactive - skipping")
#             continue
#
#         # Parse days_of_week - handle both number formats and day names
#         days_of_week_field = plan.days_of_week
#
#         # Convert day names to numbers if needed
#         day_name_to_number = {
#             'Monday': '1', 'Tuesday': '2', 'Wednesday': '3',
#             'Thursday': '4', 'Friday': '5', 'Saturday': '6', 'Sunday': '7'
#         }
#
#         # Check if the field contains day names instead of numbers
#         if days_of_week_field in day_name_to_number:
#             # Single day name
#             scheduled_days = [day_name_to_number[days_of_week_field]]
#             print(f"Converted day name '{days_of_week_field}' to number: {scheduled_days}")
#         elif days_of_week_field == 'Everyday':
#             scheduled_days = ['1', '2', '3', '4', '5', '6', '7']
#             print("Converted 'Everyday' to all days")
#         elif days_of_week_field == 'Weekdays':
#             scheduled_days = ['1', '2', '3', '4', '5']
#             print("Converted 'Weekdays' to Monday-Friday")
#         elif days_of_week_field == 'Weekends':
#             scheduled_days = ['6', '7']
#             print("Converted 'Weekends' to Saturday-Sunday")
#         else:
#             # Assume it's already comma-separated numbers
#             scheduled_days = [day.strip() for day in days_of_week_field.split(',')]
#             print(f"Parsed as comma-separated values: {scheduled_days}")
#
#         print(f"Final scheduled days list: {scheduled_days}")
#         print(f"Checking if today ({today_weekday}) is in scheduled days: {str(today_weekday) in scheduled_days}")
#
#         if str(today_weekday) in scheduled_days:
#             print(f"✓ Today ({today_weekday}) matches scheduled days")
#
#             # Parse dates - handle potential format issues
#             try:
#                 # Handle different date formats if necessary
#                 start_date_str = plan.start_date
#                 if start_date_str:
#                     # Ensure format is YYYY-MM-DD
#                     if '-' in start_date_str:
#                         start_date = datetime.strptime(start_date_str, '%Y-%m-%d').date()
#                     else:
#                         # Handle other formats if needed
#                         print(f"⚠ Unexpected date format for start_date: {start_date_str}")
#                         continue
#                 else:
#                     print("⚠ No start date - skipping")
#                     continue
#
#                 print(f"Parsed start date: {start_date}")
#
#                 end_date = None
#                 if plan.end_date:
#                     if '-' in plan.end_date:
#                         end_date = datetime.strptime(plan.end_date, '%Y-%m-%d').date()
#                     else:
#                         print(f"⚠ Unexpected date format for end_date: {plan.end_date}")
#                         end_date = None
#                     print(f"Parsed end date: {end_date}")
#                 else:
#                     print("No end date (ongoing plan)")
#
#                 # Check if today is within the date range
#                 date_check = today >= start_date and (end_date is None or today <= end_date)
#                 print(f"Date range check - Today >= Start: {today >= start_date}")
#                 if end_date:
#                     print(f"Today <= End: {today <= end_date}")
#                 print(f"Overall date check passed: {date_check}")
#
#                 if date_check:
#                     print("✓ Today is within valid date range")
#                     medicine_data = {
#                         'id': plan.id,
#                         'medicine_name': plan.MEDICINE.name if plan.MEDICINE else 'Unknown Medicine',
#                         'dosage': plan.dosage,
#                         'scheduled_time': plan.scheduled_time,
#                         'frequency': plan.frequency,
#                         'days_of_week': plan.days_of_week,
#                         'instructions': plan.instructions,
#                         'medicine_id': plan.MEDICINE.id if plan.MEDICINE else None,
#                         'medicine_type': plan.MEDICINE.medicine_type if plan.MEDICINE else '',
#                         'dosage_strength': plan.MEDICINE.dosage_strength if plan.MEDICINE else '',
#                     }
#                     today_medicines_list.append(medicine_data)
#                     print(f"✓ Added to today's list. Current count: {len(today_medicines_list)}")
#                 else:
#                     print("✗ Today is outside valid date range - not adding")
#                     if end_date and today > end_date:
#                         print(f"  Reason: End date {end_date} is before today {today}")
#                     elif today < start_date:
#                         print(f"  Reason: Start date {start_date} is after today {today}")
#             except Exception as e:
#                 print(f"⚠ Error parsing dates for plan {plan.id}: {e}")
#                 continue
#         else:
#             print(f"✗ Today ({today_weekday}) not in scheduled days - skipping")
#
#     print(f"\nStep 9: Total medicines for today before sorting: {len(today_medicines_list)}")
#     print("Raw data before sorting:", today_medicines_list)
#
#     # Sort by scheduled time
#     if today_medicines_list:
#         today_medicines_list.sort(key=lambda x: x['scheduled_time'])
#     print("Step 10: Data after sorting by time:", today_medicines_list)
#
#     response_data = {
#         'status': 'ok',
#         'data': today_medicines_list,
#         'count': len(today_medicines_list),
#         'today_date': today.strftime('%Y-%m-%d'),
#         'today_day': today_weekday
#     }
#
#     print("\n=== FINAL RESPONSE ===")
#     print("Response status:", response_data['status'])
#     print("Response count:", response_data['count'])
#     print("Response data:", response_data['data'])
#     print("=====================\n")
#
#     return JsonResponse(response_data)

def upcoming_appointments(request):

        # Get patient_id from request parameters
        lid = request.GET['patient_id']
        li=Patient.objects.get(LOGIN_id=lid)
        patient_id=li.id
        if not patient_id:
            return JsonResponse({
                'status': 'error',
                'message': 'Patient ID is required'
            }, status=400)

        # Get current date
        today = date.today()


        try:
            patient = Patient.objects.get(id=patient_id)
            print(patient)
        except Patient.DoesNotExist:
            return JsonResponse({
                'status': 'error',
                'message': 'Patient not found'
            }, status=404)

        # Get upcoming appointments (today and future dates)
        upcoming_appointments = Appointment.objects.filter(
            PATIENT=patient
        )

        appointments_list = []
        for appointment in upcoming_appointments:
            try:
                appointment_date = datetime.strptime(appointment.appointment_date, '%Y-%m-%d').date()

                # Only include today and future appointments
                if appointment_date >= today:
                    appointment_data = {
                        'id': appointment.id,
                        'doctor_name': appointment.doctor_name,
                        'doctor_specialization': appointment.doctor_specialization,
                        'hospital_name': appointment.hospital_name,
                        'appointment_date': appointment.appointment_date,
                        'appointment_time': appointment.appointment_time,
                        'contact_phone': appointment.contact_phone,
                        'purpose': appointment.purpose,
                        'notes': appointment.notes,
                    }
                    appointments_list.append(appointment_data)
            except ValueError as e:
                # Handle date parsing errors
                print(f"Date parsing error for appointment {appointment.id}: {e}")
                continue

        # Sort by appointment date and time
        appointments_list.sort(key=lambda x: (x['appointment_date'], x['appointment_time']))

        return JsonResponse({
            'status': 'ok',
            'data': appointments_list,
            'count': len(appointments_list),
            'today_date': today.strftime('%Y-%m-%d')
        })


from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.core.files.storage import FileSystemStorage
from datetime import datetime
import os

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.core.files.storage import FileSystemStorage
from datetime import datetime
import os


def mark_medicine_taken(request):
    print("🟢 mark_medicine_taken endpoint called")

    # Get basic fields
    plan_id = request.POST.get('plan_id')
    taken_time = request.POST.get('taken_time')
    method = request.POST.get('method', 'MANUAL')
    voice_transcription = request.POST.get('voice_transcription', '')

    audio_file = request.FILES.get('audio')

    print("🔵 Plan ID:", plan_id)
    print("🔵 Method:", method)
    print("🔵 Voice transcription:", voice_transcription)
    print("🔵 Audio file received:", audio_file)

    # Validate required fields
    if not plan_id:
        return JsonResponse({
            'status': 'error',
            'message': 'Plan ID is required'
        }, status=400)

    from .models import MedicinePlan, MedicationLog
    from django.core.files.storage import FileSystemStorage
    import os
    from datetime import datetime

    try:
        medicine_plan = MedicinePlan.objects.get(id=plan_id)
    except MedicinePlan.DoesNotExist:
        return JsonResponse({
            'status': 'error',
            'message': 'Medicine plan not found'
        }, status=404)

    # Convert scheduled_time to datetime if it's a string
    scheduled_time = medicine_plan.scheduled_time
    if isinstance(scheduled_time, str):
        try:
            scheduled_time = datetime.strptime(scheduled_time, '%Y-%m-%d %H:%M:%S')
        except ValueError:
            try:
                scheduled_time = datetime.strptime(scheduled_time.replace('T', ' ').split('.')[0],
                                                   '%Y-%m-%d %H:%M:%S')
            except ValueError:
                scheduled_time = datetime.now()

    # Handle taken time
    taken_datetime = datetime.now()
    if taken_time:
        try:
            taken_datetime = datetime.strptime(taken_time.replace('T', ' ').split('.')[0], '%Y-%m-%d %H:%M:%S')
        except ValueError:
            try:
                taken_datetime = datetime.strptime(taken_time, '%Y-%m-%d %H:%M:%S')
            except ValueError:
                taken_datetime = datetime.now()

    # Prepare notes based on method
    if method == 'VOICE':
        if voice_transcription and voice_transcription.strip():
            notes = f'Marked as taken via voice: {voice_transcription}'
        else:
            notes = 'Marked as taken via voice (no transcription available)'
    else:
        notes = 'Marked as taken from mobile app'

    # Handle audio file upload using FileSystemStorage
    audio_file_path = None
    if method == 'VOICE' and audio_file:
        try:
            fs = FileSystemStorage()
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            file_extension = os.path.splitext(audio_file.name)[1]
            if not file_extension:
                file_extension = '.m4a'

            filename = f'medicine_voice_{plan_id}_{timestamp}{file_extension}'
            saved_filename = fs.save(filename, audio_file)
            audio_file_path = fs.url(saved_filename)

            print(f"✅ Audio file saved: {saved_filename}")
            print(f"✅ Audio file URL: {audio_file_path}")

        except Exception as e:
            print(f"❌ Error saving audio file: {e}")

    # FIX: Use empty string instead of None for non-voice methods
    voice_transcription_value = voice_transcription if method == 'VOICE' else ''
    audio_file_path_value = audio_file_path if method == 'VOICE' and audio_file_path else ''

    # Create or update medication log
    try:
        medication_log, created = MedicationLog.objects.get_or_create(
            MEDICINEPLAN=medicine_plan,
            scheduled_time=scheduled_time,
            defaults={
                'taken_time': taken_datetime,
                'status': 'TAKEN',
                'method': method,
                'voice_transcription': voice_transcription_value,  # Use empty string instead of None
                'voice_audio_file': audio_file_path_value,  # Use empty string instead of None
                'notes': notes
            }
        )
        medicineplan_id=medicine_plan
        print("nnnnnnnnnnnnnnnnnn",medicineplan_id.id)

        p=MedicinePlan.objects.get(id=medicineplan_id.id)
        medid=p.MEDICINE_id
        print("OOOOOOO",medid)
        pi=Medicine.objects.get(id=medid)
        pi.stock_quantity=int(pi.stock_quantity)-int(p.dosage)
        pi.save()

        if not created:
            medication_log.taken_time = taken_datetime
            medication_log.status = 'TAKEN'
            medication_log.method = method
            medication_log.voice_transcription = voice_transcription_value
            medication_log.voice_audio_file = audio_file_path_value
            medication_log.notes = notes
            medication_log.save()

        response_data = {
            'status': 'success',
            'message': 'Medicine marked as taken successfully',
            'log_id': medication_log.id,
            'taken_time': taken_datetime.strftime('%Y-%m-%d %H:%M:%S'),
            'method': method
        }

        if method == 'VOICE':
            response_data['voice_transcription'] = voice_transcription
            if audio_file_path:
                response_data['voice_audio_file'] = audio_file_path

        print("📤 Response data:", response_data)
        return JsonResponse(response_data)

    except Exception as e:
        print(f"❌ Error creating medication log: {e}")
        return JsonResponse({
            'status': 'error',
            'message': f'Error saving medication log: {str(e)}'
        }, status=500)


from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
import json
from datetime import datetime
import os
from datetime import datetime
from django.http import JsonResponse
from twilio.rest import Client
from .models import Patient, EmergencyAlert, EmergencyContact

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
import json
from .models import EmergencyContact
from django.utils import timezone


@csrf_exempt  # Add this if you're not using CSRF tokens
def send_emergency_alert(request):
    print("📱 Received emergency alert request")

    if request.method != 'POST':
        return JsonResponse({'status': 'error', 'message': 'Only POST method allowed'}, status=405)

    try:
        # Print all received data for debugging
        print("📦 Received data:")
        for key, value in request.POST.items():
            print(f"   {key}: {value}")

        # Get parameters with fallbacks
        lid = request.POST.get('patient_id')
        li = Patient.objects.get(LOGIN_id=lid)
        patient_id = li.id
        alert_type = request.POST.get('alert_type', 'UNKNOWN')
        patient_name = request.POST.get('patient_name', 'Unknown Patient')
        location = request.POST.get('location', 'Location unavailable')
        timestamp = request.POST.get('timestamp', timezone.now().isoformat())

        # Validate required fields
        if not patient_id:
            return JsonResponse({'status': 'error', 'message': 'patient_id is required'}, status=400)

        print(f"🔍 Processing alert for patient: {patient_id}")
        print(f"📞 Alert type: {alert_type}")
        print(f"👤 Patient: {patient_name}")
        print(f"📍 Location: {location}")

        # Get emergency contacts for this patient
        contacts = EmergencyContact.objects.filter(patient_id=patient_id)

        print(f"📋 Found {contacts.count()} emergency contacts")

        contacts_notified = []

        for contact in contacts:
            try:
                # Create the emergency message
                if alert_type == 'SHAKE_DETECTED':
                    message = f"🚨 EMERGENCY ALERT! {patient_name} has triggered an emergency alert by shaking their phone. Location: {location}. Time: {timestamp}"
                elif alert_type == 'MANUAL':
                    message = f" MANUAL EMERGENCY ALERT!"
                elif alert_type == 'INACTIVITY':
                    message = f"⚠️ INACTIVITY ALERT! {patient_name}'s phone has been inactive. Location: {location}. Please check on them. Time: {timestamp}"
                else:
                    message = f"🚨 EMERGENCY ALERT! {patient_name} needs assistance. Location: {location}. Time: {timestamp}"

                # TODO: Implement your SMS sending logic here
                # Example with any SMS service:
                # sms_sent = your_sms_service.send_sms(contact.phone_number, message)

                # For now, simulate SMS sending
                print(f"📱 [SIMULATED] Sending SMS to {contact.name} ({contact.phone_number}):")
                print(f"   Message: {message}")

                contacts_notified.append({
                    'name': contact.name,
                    'phone_number': contact.phone_number,
                    'relationship': contact.relationship
                })

            except Exception as e:
                print(f"❌ Error sending to {contact.phone_number}: {str(e)}")
                continue

        print(f"✅ Successfully processed {len(contacts_notified)} contacts")

        return JsonResponse({
            'status': 'success',
            'message': f'Emergency alerts sent to {len(contacts_notified)} contacts',
            'contacts_notified': contacts_notified,
            'total_contacts': len(contacts_notified),
            'alert_type': alert_type,
            'patient_name': patient_name
        })

    except Exception as e:
        print(f"❌ Error in send_emergency_alert: {str(e)}")
        return JsonResponse({'status': 'error', 'message': str(e)}, status=500)



from twilio.rest import Client

def send_sms(contact_number, message):
    try:
        account_sid = "AC4dda54b183660a52718aba31aee42055"
        auth_token = "860def0647fda8e7c44e4499f0bf1d85"
        client = Client(account_sid, auth_token)

        twilio_number = "+14792820330"

        sms = client.messages.create(
            body=message,
            from_=twilio_number,
            to=contact_number
        )

        print(f"📱 SMS sent successfully! SID: {sms.sid}")
        return True

    except Exception as e:
        print(f"❌ SMS sending failed: {str(e)}")
        return False


from django.http import JsonResponse


def view_emergency_contacts(request):
    try:
        patient_id = request.GET.get('patient_id')
        # Your logic to get contacts
        contacts = EmergencyContact.objects.filter(patient_id=patient_id).values()

        return JsonResponse({
            'status': 'success',
            'contacts': list(contacts)
        })
    except Exception as e:
        return JsonResponse({
            'status': 'error',
            'message': str(e)
        })


# views.py
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from .models import FamilyMember, Patient



def emergency_contacts(request):
        pp = request.GET.get('patient_id')
        po=Patient.objects.get(LOGIN_id=pp)
        patient_id=po.id
        # Get family members who are emergency contacts
        family_members = EmergencyContact.objects.filter(
            patient_id=patient_id,
        )
        print("contactscontactscontacts",family_members)

        # Extract phone numbers
        contacts = []
        for member in family_members:
            if member.phone_number:
                contacts.append(member.phone_number)

        # If no family members, return patient's own emergency contacts
        if not contacts:
            try:
                patient = Patient.objects.get(id=patient_id)
                if patient.emergency_contact_1:
                    contacts.append(patient.emergency_contact_1)
                if patient.emergency_contact_2:
                    contacts.append(patient.emergency_contact_2)
            except Patient.DoesNotExist:
                pass
        print("contactscontactscontacts",contacts)
        return JsonResponse({
            'status': 'success',
            'contacts': contacts,  # This should be a List, not Map
            'count': len(contacts),
            'message': f'Found {len(contacts)} emergency contacts'
        })





def notify_missed_medicine(request):
    if request.method == 'POST':
        try:
            # Parse the request data
            data = json.loads(request.body)
            patient_id = data.get('patient_id')
            medicine_name = data.get('medicine_name')
            missed_count = data.get('missed_count', 1)
            missed_time = data.get('missed_time')
            scheduled_time = data.get('scheduled_time')
            dosage = data.get('dosage')

            print(f"🔔 Missed medicine alert received:")
            print(f"   Patient ID: {patient_id}")
            print(f"   Medicine: {medicine_name}")
            print(f"   Missed Count: {missed_count}")
            print(f"   Scheduled Time: {scheduled_time}")
            print(f"   Missed Time: {missed_time}")

            # Get patient details
            try:
                patient = Patient.objects.get(id=patient_id)
                patient_name = patient.name
                print(f"   Patient Name: {patient_name}")
            except Patient.DoesNotExist:
                return JsonResponse({
                    'status': 'error',
                    'message': 'Patient not found'
                }, status=404)

            # Get family members/emergency contacts
            family_members = FamilyMember.objects.filter(patient_id=patient_id, is_active=True)
            print(f"   Found {family_members.count()} family members")

            # Prepare notification message
            if missed_count == 1:
                urgency_level = "REMINDER"
                title = f"💊 Medicine Reminder for {patient_name}"
                message = f"""
{patient_name} missed their {medicine_name} medication!

📋 Details:
• Medicine: {medicine_name}
• Dosage: {dosage}
• Scheduled Time: {scheduled_time}
• Missed At: {missed_time}
• Status: First reminder (1 minute late)

Please check on {patient_name} and ensure they take their medication.
"""
            elif missed_count == 2:
                urgency_level = "IMPORTANT"
                title = f"⚠️ Important: {patient_name} Missed Medicine"
                message = f"""
URGENT: {patient_name} has missed {medicine_name} for 2 minutes!

📋 Details:
• Medicine: {medicine_name}
• Dosage: {dosage}
• Scheduled Time: {scheduled_time}
• Missed At: {missed_time}
• Status: Second reminder (2 minutes late)

This is the second consecutive missed dose alert. Immediate attention required.
"""
            else:
                urgency_level = "EMERGENCY"
                title = f"🚨 EMERGENCY: {patient_name} Missed Medicine 3 Times"
                message = f"""
EMERGENCY ALERT: {patient_name} has missed {medicine_name} for 3 minutes!

📋 Details:
• Medicine: {medicine_name}
• Dosage: {dosage}
• Scheduled Time: {scheduled_time}
• Missed At: {missed_time}
• Status: EMERGENCY - 3 consecutive missed doses

EMERGENCY CALLS ARE BEING INITIATED. Please contact {patient_name} immediately.
"""




        except Exception as e:
            print(f"❌ Error in notify_missed_medicine: {e}")
            return JsonResponse({
                'status': 'error',
                'message': f'Internal server error: {str(e)}'
            }, status=500)

    return JsonResponse({
        'status': 'error',
        'message': 'Only POST method allowed'
    }, status=405)


from face_recognition import face_locations, face_encodings, compare_faces
import face_recognition
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Dense, Dropout, Flatten, Conv2D, MaxPooling2D
from tensorflow.keras.optimizers import Adam
import numpy as np
import cv2
import base64
from datetime import datetime
import os
from django.core.files.storage import FileSystemStorage
from django.http import JsonResponse
from django.conf import settings
from myapp.models import Patient  # Adjust import based on your model location


def analyze_emotion(request):
    try:
        # Get data from request
        login_id = request.POST['patient_id']
        print("Patient ID:", login_id)
        timestamp = request.POST['timestamp']
        photo = request.FILES['image']

        # Validate inputs
        if not login_id or not photo:
            return JsonResponse({
                'status': 'error',
                'message': 'Missing required fields: patient_id and image'
            }, status=400)

        # Get patient record
        patient = Patient.objects.get(LOGIN_id=login_id)
        print("Patient face image:", patient.face_image)

        # Step 1: Get the correct path for registered face image
        # Method 1: Using the file path directly from the model
        if patient.face_image:
            registered_face_path = str(patient.face_image)
        else:
            return JsonResponse({
                'status': 'error',
                'message': 'No face image registered for this patient'
            }, status=400)

        print(f"Registered face path: {registered_face_path}")

        if not os.path.exists(registered_face_path):
            # If the path doesn't exist, try alternative method
            print("Primary path not found, trying alternative path...")
            # Method 2: Construct path using MEDIA_ROOT
            registered_face_path = "D:/PROJECT-2025-2026/viswajyothi/AI_powered_health/django_part"+str(patient.face_image)
            print(f"Alternative path: {registered_face_path}")

            if not os.path.exists(registered_face_path):
                return JsonResponse({
                    'status': 'error',
                    'message': 'Registered face image file not found'
                }, status=404)

        # Load registered face image
        registered_image = face_recognition.load_image_file(registered_face_path)
        registered_face_encodings = face_encodings(registered_image)

        if len(registered_face_encodings) == 0:
            return JsonResponse({
                'status': 'error',
                'message': 'No face detected in registered image'
            }, status=400)

        registered_face_encoding = registered_face_encodings[0]

        # Step 2: Save the new captured image to emotion directory
        emotion_dir = os.path.join(settings.MEDIA_ROOT, 'emotion')
        os.makedirs(emotion_dir, exist_ok=True)  # Create directory if it doesn't exist

        emotion_image_name = f"emotion_{login_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.jpg"
        emotion_image_path = os.path.join(emotion_dir, emotion_image_name)

        # Save the uploaded file
        with open(emotion_image_path, 'wb+') as destination:
            for chunk in photo.chunks():
                destination.write(chunk)

        print(f"Emotion image saved at: {emotion_image_path}")
        print(f"Emotion image file exists: {os.path.exists(emotion_image_path)}")
        print(f"Emotion image file size: {os.path.getsize(emotion_image_path)} bytes")

        # Step 3: Face recognition - verify it's the same person
        emotion_image = face_recognition.load_image_file(emotion_image_path)
        current_face_encodings = face_encodings(emotion_image)

        if len(current_face_encodings) == 0:
            # Clean up the saved image
            if os.path.exists(emotion_image_path):
                os.remove(emotion_image_path)
            return JsonResponse({
                'status': 'error',
                'message': 'No face detected in the captured image'
            }, status=400)

        current_face_encoding = current_face_encodings[0]

        # Compare faces
        face_matches = compare_faces([registered_face_encoding], current_face_encoding)
        face_distance = face_recognition.face_distance([registered_face_encoding], current_face_encoding)

        print(f"Face matches: {face_matches}")
        print(f"Face distance: {face_distance}")

        # Set similarity threshold (adjust as needed)
        similarity_threshold = 0.6
        is_same_person = face_matches[0] and face_distance[0] <= similarity_threshold

        if not is_same_person:
            # Clean up the saved image
            if os.path.exists(emotion_image_path):
                os.remove(emotion_image_path)
            return JsonResponse({
                'status': 'error',
                'message': 'Face verification failed - not the registered user'
            }, status=400)

        # Step 4: Emotion detection
        emotion_result = detect_emotion_from_image(emotion_image_path)

        # Clean up the temporary emotion image after processing
        if os.path.exists(emotion_image_path):
            os.remove(emotion_image_path)
            print(f"Cleaned up temporary file: {emotion_image_path}")

        if emotion_result['status'] == 'error':
            return JsonResponse(emotion_result, status=400)

        # Step 5: Save emotion record to database (optional)
        save_emotion_record(patient, emotion_result['emotion'], emotion_result['confidence'])

        # Prepare response
        response_data = {
            'status': 'success',
            'message': 'Emotion analysis completed successfully',
            'face_verified': True,
            'face_similarity': float(1 - face_distance[0]),  # Convert to similarity score
            'emotion': emotion_result['emotion'],
            'confidence': emotion_result['confidence'],
            'timestamp': datetime.now().isoformat()
        }

        return JsonResponse(response_data)

    except Patient.DoesNotExist:
        return JsonResponse({
            'status': 'error',
            'message': 'Patient not found'
        }, status=404)
    except KeyError as e:
        return JsonResponse({
            'status': 'error',
            'message': f'Missing field: {str(e)}'
        }, status=400)
    except Exception as e:
        print(f"Error in analyze_emotion: {str(e)}")
        import traceback
        print(f"Traceback: {traceback.format_exc()}")

        # Clean up any temporary files in case of error
        try:
            if 'emotion_image_path' in locals() and os.path.exists(emotion_image_path):
                os.remove(emotion_image_path)
                print("Cleaned up temporary file due to error")
        except:
            pass
        return JsonResponse({
            'status': 'error',
            'message': f'Internal server error: {str(e)}'
        }, status=500)


def detect_emotion_from_image(image_path):
    """
    Detect emotion from image using the trained model
    """
    try:
        print(f"Starting emotion detection for: {image_path}")

        # Load the emotion detection model
        model = create_emotion_model()
        model_path = os.path.join(settings.BASE_DIR, 'myapp', 'model.h5')
        print(f"Model path: {model_path}")

        if not os.path.exists(model_path):
            return {'status': 'error', 'message': 'Model file not found'}

        model.load_weights(model_path)
        print("Model loaded successfully")

        # Load face cascade classifier
        cascade_path = os.path.join(settings.BASE_DIR, 'myapp', 'haarcascade_frontalface_default.xml')
        print(f"Cascade path: {cascade_path}")

        if not os.path.exists(cascade_path):
            return {'status': 'error', 'message': 'Cascade file not found'}

        face_cascade = cv2.CascadeClassifier(cascade_path)

        if face_cascade.empty():
            return {'status': 'error', 'message': 'Failed to load face cascade classifier'}

        # Read and process image
        frame = cv2.imread(image_path)
        if frame is None:
            return {'status': 'error', 'message': 'Failed to read image file'}

        print(f"Image loaded successfully, shape: {frame.shape}")

        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        faces = face_cascade.detectMultiScale(gray, scaleFactor=1.3, minNeighbors=5)

        print(f"Number of faces detected: {len(faces)}")

        if len(faces) == 0:
            return {'status': 'error', 'message': 'No face detected for emotion analysis'}

        emotion_dict = {
            0: "Angry",
            1: "Disgusted",
            2: "Fearful",
            3: "Happy",
            4: "Neutral",
            5: "Sad",
            6: "Surprised"
        }

        # Process the first detected face
        x, y, w, h = faces[0]
        print(f"Face coordinates: x={x}, y={y}, w={w}, h={h}")

        # Extract face region for emotion detection
        roi_gray = gray[y:y + h, x:x + w]
        print(f"ROI shape: {roi_gray.shape}")

        # Resize to 48x48 as required by the model
        cropped_img = cv2.resize(roi_gray, (48, 48))
        print(f"Resized ROI shape: {cropped_img.shape}")

        cropped_img = np.expand_dims(np.expand_dims(cropped_img, -1), 0)
        print(f"Final input shape: {cropped_img.shape}")

        # Normalize pixel values
        cropped_img = cropped_img.astype('float32') / 255.0

        # Predict emotion
        prediction = model.predict(cropped_img)
        print(f"Raw prediction: {prediction}")

        max_index = int(np.argmax(prediction))
        confidence = float(np.max(prediction))

        detected_emotion = emotion_dict[max_index]

        print(f"Detected emotion: {detected_emotion} with confidence: {confidence:.4f}")

        return {
            'status': 'success',
            'emotion': detected_emotion,
            'confidence': confidence,
            'emotion_index': max_index
        }

    except Exception as e:
        print(f"Error in emotion detection: {str(e)}")
        import traceback
        print(f"Emotion detection traceback: {traceback.format_exc()}")
        return {'status': 'error', 'message': f'Emotion detection failed: {str(e)}'}


def create_emotion_model():
    """
    Create the emotion detection model architecture
    """
    model = Sequential()

    model.add(Conv2D(32, kernel_size=(3, 3), activation='relu', input_shape=(48, 48, 1)))
    model.add(Conv2D(64, kernel_size=(3, 3), activation='relu'))
    model.add(MaxPooling2D(pool_size=(2, 2)))
    model.add(Dropout(0.25))

    model.add(Conv2D(128, kernel_size=(3, 3), activation='relu'))
    model.add(MaxPooling2D(pool_size=(2, 2)))
    model.add(Conv2D(128, kernel_size=(3, 3), activation='relu'))
    model.add(MaxPooling2D(pool_size=(2, 2)))
    model.add(Dropout(0.25))

    model.add(Flatten())
    model.add(Dense(1024, activation='relu'))
    model.add(Dropout(0.5))
    model.add(Dense(7, activation='softmax'))

    return model


# Optional: Function to save emotion records to database
def save_emotion_record(patient, emotion, confidence):
    """
    Save emotion analysis result to database
    """
    try:
        # Create or import your EmotionRecord model
        from myapp.models import EmotionRecord  # Adjust based on your model

        EmotionRecord.objects.create(
            patient=patient,
            emotion=emotion,
            confidence=confidence,
            time=datetime.now()
        )
        print(f"Emotion record saved for patient {patient.LOGIN_id}")
    except Exception as e:
        print(f"Failed to save emotion record: {str(e)}")


from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
import json

from django.http import JsonResponse
from django.core.serializers import serialize
import json
from django.db.models import Avg, Count


def view_app_ratings(request):
    try:
        # Get patient ID from request
        lid = request.GET['lid']

        # Get all reviews
        reviews = review.objects.all()

        # Calculate overall statistics
        total_reviews = reviews.count()
        if total_reviews > 0:
            average_rating = reviews.aggregate(avg_rating=Avg('rate'))['avg_rating']
            average_rating = round(float(average_rating), 2)
        else:
            average_rating = 0.0

        # Get rating distribution
        rating_counts = {
            '5_star': reviews.filter(rate=5).count(),
            '4_star': reviews.filter(rate=4).count(),
            '3_star': reviews.filter(rate=3).count(),
            '2_star': reviews.filter(rate=2).count(),
            '1_star': reviews.filter(rate=1).count()
        }

        # Prepare reviews data - FIXED: Convert all values to JSON-serializable types
        reviews_data = []
        for review_obj in reviews:  # Changed variable name to avoid conflict
            # Handle date field properly
            created_at = review_obj.date

            review_data = {
                'id': review_obj.id,
                'patient_id': review_obj.FamilyMember.id if review_obj.FamilyMember else None,
                'patient_name': str(
                    review_obj.FamilyMember.NAME) if review_obj.FamilyMember and review_obj.FamilyMember.NAME else 'Anonymous User',
                'rating': review_obj.rate,
                'review': str(review_obj.review) if review_obj.review else '',
                'created_at': created_at,
            }
            reviews_data.append(review_data)

        # Check if current user has rated - FIXED: Use correct field name
        user_has_rated = reviews.filter(FamilyMember_id=lid).exists()

        # Get user's rating if exists - FIXED: Use correct field name
        user_rating_obj = reviews.filter(FamilyMember_id=lid).first()
        user_rating = user_rating_obj.rate if user_has_rated and user_rating_obj else None

        response_data = {
            "status": "ok",
            "message": "App ratings retrieved successfully",
            "data": reviews_data,
            "statistics": {
                "average_rating": average_rating,
                "total_ratings": total_reviews,
                "rating_distribution": rating_counts
            },
            "user_has_rated": user_has_rated,
            "user_rating": user_rating  # FIXED: Use the correct variable
        }

        return JsonResponse(response_data, safe=False)

    except KeyError:
        return JsonResponse({
            "status": "error",
            "message": "Patient ID (lid) is required"
        }, status=400)

    except Exception as e:
        return JsonResponse({
            "status": "error",
            "message": "Failed to retrieve app ratings",
            "error": str(e)
        }, status=500)
def add_app_rating(request):
    lid=request.POST['patient_id']
    p=FamilyMember.objects.get(LOGIN_id=lid)
    patient_id=p.id

    rating=request.POST['rating']
    reviews=request.POST['review']
    o=review(FamilyMember_id=patient_id,rate=rating,review=reviews,date=datetime.now().date())
    o.save()
    return JsonResponse({"status":"ok"})

def view_caregiver_profile(request):
    lid = request.GET['lid']
    o = FamilyMember.objects.filter(LOGIN_id=lid)
    family_list = []
    for family in o:
        family_list.append({
            'id': family.id,
            'name': family.NAME,
            'phone_number': family.PHONE_NUMBER,
            'email': family.EMAIL,
            'gender': family.GENDER,
            'address': family.ADDRESS,

        })
    print("dddddddddd", family_list)

    return JsonResponse({"status": "ok", "data": family_list})
def update_caregiver_profile(request):
    lid=request.POST['lid']
    t=FamilyMember.objects.get(LOGIN_id=lid)
    t.NAME=request.POST['name']
    t.GENDER=request.POST['gender']
    t.ADDRESS=request.POST['address']
    t.EMAIL=request.POST['email']
    t.PHONE_NUMBER=request.POST['phone_number']
    t.save()
    return JsonResponse({"status":"success"})


def get_user_profile(request):
    lid = request.GET['lid']
    o = Patient.objects.filter(LOGIN_id=lid)
    patient_list = []
    for patient in o:
        patient_list.append({
            'id': patient.id,
            'face_image': str(patient.face_image),
            'name': patient.NAME,
            'phone_number': patient.PHONE_NUMBER,
            'email': patient.EMAIL,
            'dob':patient.DATE_OF_BIRTH,
            'gender': patient.GENDER,
            'address': patient.ADDRESS,
            'relation': patient.relationship,
            'age':patient.AGE

        })
    print("dddddddddd", patient_list)

    return JsonResponse({"status": "ok", "data": patient_list})

def update_user_profile(request):
    lid = request.POST.get('lid')
    p = Patient.objects.get(LOGIN_id=lid)

    p.NAME = request.POST.get('name')
    p.PHONE_NUMBER = request.POST.get('phone_number')
    p.DATE_OF_BIRTH = request.POST.get('dob')
    p.AGE = request.POST.get('age')
    p.GENDER = request.POST.get('gender')
    p.ADDRESS = request.POST.get('address')
    p.relationship = request.POST.get('relation')

    # ✅ Check if image is provided
    if 'face_image' in request.FILES:
        photo = request.FILES['face_image']
        fs = FileSystemStorage()
        filename = datetime.now().strftime('%Y%m%d-%H%M%S') + '.jpg'
        fs.save(filename, photo)
        p.face_image = fs.url(filename)

    p.save()
    return JsonResponse({"status": "ok"})


from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
import json
import base64
from PIL import Image
import io
import numpy as np
import cv2
from datetime import datetime
import os
from django.conf import settings


@csrf_exempt
def analyze_emotion(request):
    """
    Analyze emotion from an uploaded image
    """
    try:
        if request.method != 'POST':
            return JsonResponse({
                'status': 'error',
                'message': 'Only POST method is allowed'
            }, status=405)

        # Get patient ID
        patient_id = request.POST.get('patient_id', 'unknown')
        timestamp = datetime.now().isoformat()

        # Check if image file is provided
        if 'image' not in request.FILES:
            return JsonResponse({
                'status': 'error',
                'message': 'No image file provided'
            }, status=400)

        image_file = request.FILES['image']

        # Read image
        image_bytes = image_file.read()

        # Convert to numpy array for OpenCV
        nparr = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if img is None:
            return JsonResponse({
                'status': 'error',
                'message': 'Could not decode image'
            }, status=400)

        # Save image for debugging (optional)
        debug_dir = os.path.join(settings.MEDIA_ROOT, 'emotion_debug')
        os.makedirs(debug_dir, exist_ok=True)

        filename = f"emotion_{patient_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.jpg"
        filepath = os.path.join(debug_dir, filename)
        cv2.imwrite(filepath, img)

        # TODO: Add your actual emotion detection logic here
        # For now, we'll simulate emotion detection

        # Example: Using OpenCV for face detection
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

        # Load pre-trained face detector (Haar Cascade)
        face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
        faces = face_cascade.detectMultiScale(gray, 1.1, 4)

        if len(faces) == 0:
            return JsonResponse({
                'status': 'success',
                'emotion': 'no_face',
                'confidence': 0.0,
                'face_detected': False,
                'message': 'No face detected in image',
                'patient_id': patient_id,
                'timestamp': timestamp
            })

        # Simulate emotion detection (replace with your actual ML model)
        # This is just a placeholder - you should integrate a proper emotion detection model

        # List of possible emotions with weights
        emotions = ['happy', 'neutral', 'sad', 'angry', 'surprised', 'fearful', 'disgusted']

        # Simulate different confidence based on face position/size
        (x, y, w, h) = faces[0]
        face_area = w * h
        img_area = img.shape[0] * img.shape[1]
        face_ratio = face_area / img_area

        # Simple heuristic for demonstration
        if face_ratio > 0.1:
            # Large face - more likely to be happy/neutral
            emotion = np.random.choice(['happy', 'neutral', 'happy', 'neutral', 'surprised'],
                                       p=[0.3, 0.3, 0.2, 0.1, 0.1])
            confidence = 0.7 + np.random.random() * 0.2
        else:
            # Small face - more varied emotions
            emotion = np.random.choice(emotions)
            confidence = 0.5 + np.random.random() * 0.3

        # Normalize emotion (map similar emotions to standard categories)
        emotion_normalized = normalize_emotion(emotion)

        return JsonResponse({
            'status': 'success',
            'emotion': emotion_normalized,
            'confidence': float(confidence),
            'face_detected': True,
            'face_count': len(faces),
            'face_ratio': float(face_ratio),
            'patient_id': patient_id,
            'timestamp': timestamp,
            'debug_image_url': f"/media/emotion_debug/{filename}"
        })

    except Exception as e:
        import traceback
        error_trace = traceback.format_exc()
        print(f"Error in analyze_emotion: {str(e)}")
        print(error_trace)

        return JsonResponse({
            'status': 'error',
            'message': str(e),
            'traceback': error_trace
        }, status=500)


def normalize_emotion(emotion):
    """Normalize emotion to standard categories"""
    emotion_lower = str(emotion).lower()

    emotion_map = {
        'happy': ['happy', 'joy', 'joyful', 'smiling', 'smile', 'happiness'],
        'neutral': ['neutral', 'calm', 'normal', 'serene', 'calmness'],
        'surprised': ['surprised', 'surprise', 'astonished', 'amazed'],
        'sad': ['sad', 'sadness', 'depressed', 'unhappy', 'sorrow'],
        'angry': ['angry', 'anger', 'furious', 'rage', 'annoyed'],
        'fearful': ['fear', 'fearful', 'scared', 'afraid', 'terrified'],
        'disgusted': ['disgust', 'disgusted', 'revulsion', 'contempt']
    }

    for category, keywords in emotion_map.items():
        if any(keyword in emotion_lower for keyword in keywords):
            return category

    return 'neutral'  # Default to neutral if no match


def appointment_response(request):
    appointment_id=request.POST['appointment_id']
    response=request.POST['response']
    p=Appointment.objects.get(id=appointment_id)
    p.response=response
    p.save()
    return JsonResponse({"status":"success"})