from django.urls import path
from . import views
from django.conf import settings
from django.conf.urls.static import static
from . import api_views  # Create this file for API-specific views

urlpatterns = [
    path('', views.login_view, name='login_page'),  # Login page
    path('login/', views.login_view, name='login'),  # Handles the login form submission
    path('user_page/', views.user_page, name='user_page'),  # Corrected to use views.user_page
    path('logout/', views.logout_view, name='logout'),
    path('clock_in/', views.clock_in_view, name='clock_in'),
    path('clock_out/', views.clock_out_view, name='clock_out'),
    path('get_todays_entries/', views.get_todays_entries, name='get_todays_entries'),
    path('custom_admin_page/', views.custom_admin_page, name='custom_admin_page'),
    path('upload_image/', views.upload_image, name='upload_image'),
    path('announcements/', views.announcements_list_create, name='announcements_list_create'),
    path('announcements/<int:pk>/', views.announcement_detail, name='announcement_detail'),
    path('announcements/<int:pk>/delete/', views.announcement_delete, name='announcement_delete'),
    path('announcements/<int:pk>/post/', views.announcement_post, name='announcement_post'),
    path('announcements/posted/', views.posted_announcements_list, name='posted_announcements_list'),
    path("superadmin/", views.superadmin_redirect, name="superadmin_redirect"),
    path("get_special_dates/", views.get_special_dates, name="get_special_dates"),
    path('attendance_list_json/', views.attendance_list_json, name='attendance_list_json'),
    path('dashboard-data/', views.dashboard_data, name='dashboard_data'),


]+ static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)

# API for mobile

urlpatterns += [
    path('api/clock_in/', api_views.api_clock_in, name='api_clock_in'),
    path('api/clock_out/', api_views.api_clock_out, name='api_clock_out'),
    path('api/user_info/<str:employee_id>/', api_views.api_user_info, name='api_user_info'),
    path('api/upload_image/', api_views.api_upload_image, name='api_upload_image'),
    path('api/test/', api_views.api_test, name='api_test'),
]

