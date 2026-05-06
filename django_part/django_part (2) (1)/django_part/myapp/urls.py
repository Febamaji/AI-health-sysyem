
from django.contrib import admin
from django.urls import path,include

from myapp import views

urlpatterns = [

  path('index/',views.index),
  path('login_get/',views.login_get),
  path('login_post/',views.login_post),
  path('admin_home/',views.admin_home),
  path('admin_view_caretaker/',views.admin_view_caretaker),
  path('admin_view_patients/<id>',views.admin_view_patients),
  path('admin_view_medicine/<id>',views.admin_view_medicine),
  path('view_medication_plan/<id>',views.view_medication_plan),
  path('admin_view_rating/',views.admin_view_rating),
  path('user_login/',views.user_login),
  path('Userregister/',views.Userregister),
  path('Caregiverregister/',views.Caregiverregister),
  path('view_patients/',views.view_patients),
  path('delete_patient/',views.delete_patient),
  path('add_medicine/',views.add_medicine),
  path('view_medicines/',views.view_medicines),
  path('update_medicine/',views.update_medicine),
  path('delete_medicine/',views.delete_medicine),
  path('add_medicine_plan/',views.add_medicine_plan),
  path('view_medicine_plans/',views.view_medicine_plans),
  path('update_medicine_plan/',views.update_medicine_plan),
  path('delete_medicine_plan/',views.delete_medicine_plan),
  path('add_appointment/',views.doctor_app_add),
  path('view_appointments/',views.view_appointments),
  path('delete_appointment/',views.delete_appointment),
  path('update_appointment/',views.update_appointment),
  path('delete_emergency_contact/',views.delete_emergency_contact),
  path('update_emergency_contact/',views.update_emergency_contact),
  path('add_emergency_contact/',views.add_emergency_contact),
  path('view_emergency_contacts/',views.view_emergency_contacts),

  path('today_medicines/',views.today_medicines),
  path('upcoming_appointments/',views.upcoming_appointments),
  path('mark_medicine_taken/',views.mark_medicine_taken),
  path('send_emergency_alert/',views.send_emergency_alert),
  path('view_emergency_contacts/',views.view_emergency_contacts),
  path('get_emergency_contacts/',views.get_emergency_contacts),
  path('emergency_contacts/',views.emergency_contacts),
  path('notify_missed_medicine/',views.notify_missed_medicine),
  path('analyze_emotion/',views.analyze_emotion),
  path('view_app_ratings/',views.view_app_ratings),
  path('add_app_rating/',views.add_app_rating),
  path('view_caregiver_profile/',views.view_caregiver_profile),
  path('update_caregiver_profile/',views.update_caregiver_profile),
  path('get_user_profile/',views.get_user_profile),
  path('update_user_profile/',views.update_user_profile),
  path('appointment_response/',views.appointment_response)

]
