from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth import login, logout
from django.urls import reverse
from .models import CustomUser, TimeEntry, Announcement
from django.views.decorators.cache import never_cache
from django.contrib.auth.decorators import login_required
import json
from django.http import JsonResponse, HttpResponseBadRequest
from django.views.decorators.http import require_POST, require_GET
from django.utils import timezone
from django.core.files.base import ContentFile
from django.core.files.storage import default_storage
import os
from datetime import datetime, timedelta
from django.views.decorators.csrf import csrf_exempt
from django.contrib import messages
from .models import CustomUser
from django.db.models import Q
from .utils import COMPANY_CHOICES, DEPARTMENT_CHOICES, get_day_code, format_minutes, COMPANY_LOGO_MAPPING, get_company_logo

@never_cache
def login_view(request):
    if request.method == "POST":
        employee_id = request.POST.get("employee_id")
        pin = request.POST.get("pin")

        try:
            # First check if user exists and is active
            user = CustomUser.objects.get(employee_id=employee_id)

            if not user.is_active:
                return render(request, "login_page.html",
                            {"error": "This account is inactive"})

            # Try to authenticate
            auth_result = CustomUser.authenticate_by_pin(employee_id, pin)

            if auth_result:  # Successful login
                user = auth_result if isinstance(auth_result, CustomUser) else auth_result["user"]
                login(request, user)

                if user.is_guard:
                    return redirect("user_page")
                elif user.is_staff or user.is_superuser:
                    return redirect("custom_admin_page")
                else:
                    return render(request, "login_page.html",
                                {"error": "You do not have permission to log in"})
            else:
                return render(request, "login_page.html",
                            {"error": "Incorrect PIN"})

        except CustomUser.DoesNotExist:
            return render(request, "login_page.html",
                        {"error": "Employee ID not found"})

    return render(request, "login_page.html")


@login_required
def user_page(request):
    # Force a refresh from the DB so that the latest value of is_guard is loaded
    request.user.refresh_from_db()
    print(
        "USER_PAGE VIEW: request.user:",
        request.user,
        "is_guard:",
        request.user.is_guard,
    )

    if not request.user.is_guard:
        messages.error(
            request, "Access denied. You do not have permission to access this page."
        )
        return redirect("custom_admin_page")

    now = timezone.now()
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    today_end = today_start + timedelta(days=1)
    todays_entries = TimeEntry.objects.filter(
        time_in__gte=today_start, time_in__lt=today_end
    ).order_by("-last_modified")

    return render(
        request,
        "user_page.html",
        {
            "all_entries": todays_entries,
            "partner_logo": "default_logo.png",
            "user_company": "",
        },
    )


def logout_view(request):
    logout(request)
    return redirect("login")


@require_POST
def clock_in_view(request):
    data = json.loads(request.body)
    employee_id = data.get("employee_id")
    pin = data.get("pin")
    new_pin = data.get("new_pin")
    image_path = data.get("image_path")
    first_login_check = data.get("first_login_check", False)

    auth_result = CustomUser.authenticate_by_pin(employee_id, pin)

    # Handle first login cases
    if isinstance(auth_result, dict) and auth_result["status"] == "first_login":
        if new_pin:
            # Update PIN for first time login
            user = auth_result["user"]
            user.pin = new_pin
            user.if_first_login = False
            user.save()
            return JsonResponse(
                {"success": True, "message": "PIN updated successfully"}
            )
        else:
            # Prompt for new PIN
            return JsonResponse(
                {
                    "success": False,
                    "error": "first_login",
                    "message": "Please set your new PIN",
                }
            )

    # For first login check only
    if first_login_check:
        if isinstance(auth_result, dict) and auth_result["status"] == "first_login":
            return JsonResponse(
                {
                    "success": False,
                    "error": "first_login",
                    "message": "Please set your new PIN",
                }
            )
        return JsonResponse({"success": True})

    if not isinstance(auth_result, dict) and auth_result:
        user = auth_result

        if not user:
            try:
                CustomUser.objects.get(employee_id=employee_id)
                error_message = "Incorrect PIN"
            except CustomUser.DoesNotExist:
                error_message = "Employee ID not found"
            return JsonResponse({"success": False, "error": error_message})

        # Handle company logo using the utility function
        user_company = user.company.name if user.company else ""
        company_logo = get_company_logo(user_company)

        # Create time entry
        entry = TimeEntry.clock_in(user)
        if image_path:
            entry.image_path = image_path
            entry.save()

        # Fetch updated attendance list
        now = timezone.now()
        today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        today_end = today_start + timedelta(days=1)
        todays_entries = TimeEntry.objects.filter(
            time_in__gte=today_start, time_in__lt=today_end
        ).order_by("-last_modified")

        attendance_list = [
            {
                "employee_id": entry.user.employee_id,
                "first_name": entry.user.first_name,
                "surname": entry.user.surname,
                "company": entry.user.company.name if entry.user.company else "",
                "time_in": entry.time_in.strftime("%I:%M %p"),
                "time_out": (
                    entry.time_out.strftime("%I:%M %p") if entry.time_out else None
                ),
                "image_path": entry.image_path,
            }
            for entry in todays_entries
        ]

        return JsonResponse(
            {
                "success": True,
                "employee_id": user.employee_id,
                "first_name": user.first_name,
                "surname": user.surname,
                "company": user.company.name if user.company else "",
                "time_in": entry.time_in.strftime("%I:%M %p"),
                "time_out": None,
                "image_path": entry.image_path,
                "new_logo": company_logo,
                "attendance_list": attendance_list,
            }
        )

@require_POST
def clock_out_view(request):
    data = json.loads(request.body)
    employee_id = data.get("employee_id")
    pin = data.get("pin")

    user = CustomUser.authenticate_by_pin(employee_id, pin)

    if user:
        try:
            now = timezone.now()
            today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
            today_end = today_start + timedelta(days=1)

            open_entry = TimeEntry.objects.filter(
                user=user,
                time_out__isnull=True,
                time_in__gte=today_start,
                time_in__lt=today_end,
            ).latest("time_in")

            open_entry.clock_out()

            time_in_formatted = open_entry.time_in.strftime("%I:%M %p")
            time_out_formatted = open_entry.time_out.strftime("%I:%M %p")

            # Handle None company value
            user_company = user.company.name if user.company else ""
            company_logo = get_company_logo(user_company)

            # Fetch updated attendance list
            todays_entries = TimeEntry.objects.filter(
                time_in__gte=today_start, time_in__lt=today_end
            ).order_by("-last_modified")

            attendance_list = [
                {
                    "employee_id": entry.user.employee_id,
                    "first_name": entry.user.first_name,
                    "surname": entry.user.surname,
                    "company": entry.user.company.name if entry.user.company else "",
                    "time_in": entry.time_in.strftime("%I:%M %p"),
                    "time_out": (
                        entry.time_out.strftime("%I:%M %p") if entry.time_out else None
                    ),
                    "image_path": entry.image_path,
                }
                for entry in todays_entries
            ]

            return JsonResponse(
                {
                    "success": True,
                    "employee_id": user.employee_id,
                    "first_name": user.first_name or "",
                    "surname": user.surname or "",
                    "company": user.company.name if user.company else "",
                    "time_in": time_in_formatted,
                    "time_out": time_out_formatted,
                    "new_logo": company_logo,
                    "attendance_list": attendance_list,
                }
            )
        except TimeEntry.DoesNotExist:
            return JsonResponse(
                {"success": False, "error": "No active clock in found."}
            )
        except Exception as e:
            return JsonResponse(
                {"success": False, "error": f"An error occurred: {str(e)}"}
            )
    else:
        try:
            CustomUser.objects.get(employee_id=employee_id)
            error_message = "Incorrect PIN"
        except CustomUser.DoesNotExist:
            error_message = "Employee ID not found"
        return JsonResponse({"success": False, "error": error_message})


@require_GET
@login_required
def get_todays_entries(request):
    now = timezone.now()
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    today_end = today_start + timedelta(days=1)

    # Make sure entries are ordered by last_modified in descending order
    entries = TimeEntry.objects.filter(
        time_in__gte=today_start, time_in__lt=today_end
    ).order_by(
        "-last_modified"
    )  # This is correct

    entries_data = []
    for entry in entries:
        entries_data.append(
            {
                "employee_id": entry.user.employee_id,
                "first_name": entry.user.first_name,
                "surname": entry.user.surname,
                "company": entry.user.company.name if entry.user.company else "",
                "time_in": entry.time_in.strftime("%I:%M %p"),
                "time_out": (
                    entry.time_out.strftime("%I:%M %p") if entry.time_out else None
                ),
            }
        )

    return JsonResponse({"entries": entries_data})


@require_POST
def upload_image(request):
    image_data = request.FILES.get("image")
    employee_id = request.POST.get("employee_id")

    if image_data:
        try:
            user = CustomUser.objects.get(employee_id=employee_id)
        except CustomUser.DoesNotExist:
            return JsonResponse({"success": False, "error": "User not found"})

        # Get the current date
        now = datetime.now()
        year = now.strftime("%Y")
        month = now.strftime("%m")
        day = now.strftime("%d")
        timestamp = now.strftime("%H%M%S")

        # Create directories based on the current date
        directory = os.path.join("attendance_images", year, month, day)
        if not os.path.exists(directory):
            os.makedirs(directory)

        # Create a unique file name
        file_name = (
            f"{timestamp}_{user.employee_id}_{user.surname}{user.first_name}.jpg"
        )
        file_path = os.path.join(directory, file_name)

        # Save the file
        file_path = default_storage.save(file_path, ContentFile(image_data.read()))
        return JsonResponse({"success": True, "file_path": file_path})
    return JsonResponse({"success": False, "error": "No image uploaded"})


@csrf_exempt
def announcements_list_create(request):
    """
    GET  -> Return a list of all announcements (JSON)
    POST -> Create a new announcement (expects JSON body { content: "..."} )
    """
    if request.method == "GET":
        announcements = Announcement.objects.all().order_by("-created_at")
        data = [
            {
                "id": ann.id,
                "content": ann.content,
                "created_at": ann.created_at.isoformat(),
                "is_posted": ann.is_posted,
            }
            for ann in announcements
        ]
        return JsonResponse(data, safe=False)

    elif request.method == "POST":
        try:
            body = json.loads(request.body)
            content = body.get("content", "")
            announcement = Announcement.objects.create(content=content)
            return JsonResponse(
                {"message": "Announcement created", "id": announcement.id}
            )
        except:
            return HttpResponseBadRequest("Invalid data")

    return HttpResponseBadRequest("Unsupported method")


@csrf_exempt
def announcement_detail(request, pk):
    """
    GET -> Return details of a single announcement by ID.
    """
    announcement = get_object_or_404(Announcement, pk=pk)

    if request.method == "GET":
        data = {
            "id": announcement.id,
            "content": announcement.content,
            "created_at": announcement.created_at.isoformat(),
            "is_posted": announcement.is_posted,
        }
        return JsonResponse(data)

    return HttpResponseBadRequest("Unsupported method")


@csrf_exempt
def announcement_delete(request, pk):
    """
    DELETE -> Delete an announcement by ID.
    """
    if request.method == "DELETE":
        announcement = get_object_or_404(Announcement, pk=pk)
        announcement.delete()
        return JsonResponse({"message": "Announcement deleted"})
    return HttpResponseBadRequest("Unsupported method")


@csrf_exempt
def announcement_post(request, pk):
    """
    POST -> Mark an announcement as posted (is_posted = True).
    """
    if request.method == "POST":
        announcement = get_object_or_404(Announcement, pk=pk)
        announcement.is_posted = True
        announcement.save()
        return JsonResponse({"message": "Announcement posted"})
    return HttpResponseBadRequest("Unsupported method")


@csrf_exempt
def posted_announcements_list(request):
    """
    GET -> Return a list of posted announcements (is_posted=True).
    """
    if request.method == "GET":
        # Filter to only posted announcements
        announcements = Announcement.objects.filter(is_posted=True).order_by(
            "-created_at"
        )
        data = [
            {
                "id": ann.id,
                "content": ann.content,
                "created_at": ann.created_at.isoformat(),
                "is_posted": ann.is_posted,
            }
            for ann in announcements
        ]
        return JsonResponse(data, safe=False)

    return HttpResponseBadRequest("Unsupported method")


def custom_admin_page(request):
    # Only allow users that are staff or superusers to access this page.
    if not (request.user.is_staff or request.user.is_superuser):
        # Redirect non-admin users to the regular user page (or another page)
        return redirect("user_page")

    # Otherwise, render the custom admin page
    return render(request, "custom_admin_page.html")


@login_required
def superadmin_redirect(request):
    if request.user.is_superuser:
        return redirect(reverse("admin:index"))
    else:
        messages.error(
            request, "You do not have permission to access the super admin page."
        )
        return redirect("custom_admin_page")

def get_special_dates(request):
    today = timezone.now().date()

    # Get users with birthdays today based on 'birth_date'
    birthday_users = list(
        CustomUser.objects.filter(
            birth_date__month=today.month,
            birth_date__day=today.day
        ).values("employee_id", "first_name", "surname")
    )

    # Get users with hiring anniversaries today based on 'date_hired'
    milestone_users = []
    for user in CustomUser.objects.filter(
        date_hired__month=today.month,
        date_hired__day=today.day
    ):
        years = today.year - user.date_hired.year
        if years >= 1:
            milestone_users.append({
                "employee_id": user.employee_id,
                "first_name": user.first_name,
                "surname": user.surname,
                "years": years
            })

    return JsonResponse({
        "birthdays": birthday_users,
        "milestones": milestone_users
    })


def attendance_list_json(request):
    attendance_type = request.GET.get('attendance_type', 'time-log')
    company_code = request.GET.get('attendance_company', 'all')
    department_code = request.GET.get('attendance_department', 'all')
    search_query = request.GET.get('search', '').strip()

    print(f"Filtering: type={attendance_type}, company={company_code}, dept={department_code}, search={search_query}")

    if attendance_type == 'time-log':
        qs = TimeEntry.objects.select_related('user', 'user__company', 'user__position')\
            .all().order_by('-time_in')

        if company_code != 'all':
            companies_to_filter = []
            # Check if company_code is directly in COMPANY_CHOICES
            if company_code in COMPANY_CHOICES:
                companies_to_filter = COMPANY_CHOICES[company_code]
            else:
                # Check if company_code is an alias in any tuple
                for key, names_tuple in COMPANY_CHOICES.items():
                    if company_code in names_tuple:
                        companies_to_filter = names_tuple
                        break

            if companies_to_filter:
                query = Q()
                for company_name in companies_to_filter:
                    query |= Q(user__company__name__iexact=company_name)
                qs = qs.filter(query)
            else:
                # If no match was found, still filter by the provided code
                # This handles custom company codes not in the mapping
                qs = qs.filter(user__company__name__iexact=company_code)

        if department_code != 'all':
            if department_code in DEPARTMENT_CHOICES:
                dept_name = DEPARTMENT_CHOICES[department_code]
                qs = qs.filter(user__position__name=dept_name)
            else:
                # If not in the mapping, use the code directly
                qs = qs.filter(user__position__name=department_code)

        # Filter by search term if provided
        if search_query:
            qs = qs.filter(
                Q(user__first_name__icontains=search_query) |
                Q(user__surname__icontains=search_query)
            )

        data = [
            {
                'employee_id': entry.user.employee_id,
                'name': f"{entry.user.first_name} {entry.user.surname}",
                'time_in': entry.time_in.strftime("%Y-%m-%d %H:%M:%S"),
                'time_out': entry.time_out.strftime("%Y-%m-%d %H:%M:%S") if entry.time_out else '',
                'hours_worked': entry.hours_worked,
            }
            for entry in qs
        ]

    elif attendance_type == 'users-active' or attendance_type == 'users-inactive':
        # Same fix for these sections...
        # ... (similar changes for other attendance types)
        if attendance_type == 'users-active':
            qs = CustomUser.objects.filter(timeentry__time_out__isnull=True).distinct()
        else:  # users-inactive
            qs = CustomUser.objects.exclude(timeentry__time_out__isnull=True).distinct()

        if company_code != 'all':
            companies_to_filter = []
            if company_code in COMPANY_CHOICES:
                companies_to_filter = COMPANY_CHOICES[company_code]
            else:
                for key, names_tuple in COMPANY_CHOICES.items():
                    if company_code in names_tuple:
                        companies_to_filter = names_tuple
                        break

            if companies_to_filter:
                query = Q()
                for company_name in companies_to_filter:
                    query |= Q(company__name__iexact=company_name)
                qs = qs.filter(query)
            else:
                qs = qs.filter(company__name__iexact=company_code)

        if department_code != 'all':
            qs = qs.filter(position__name=department_code)

        # Filter by search term
        if search_query:
            qs = qs.filter(
                Q(first_name__icontains=search_query) |
                Q(surname__icontains=search_query)
            )

        data = [
            {
                'employee_id': user.employee_id,
                'name': f"{user.first_name} {user.surname}",
            }
            for user in qs
        ]
    else:
        data = []

    return JsonResponse({'attendance_list': data, 'attendance_type': attendance_type})

@login_required
@require_GET
def dashboard_data(request):
    """Return data for dashboard"""
    now = timezone.now()
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    today_end = today_start + timedelta(days=1)

    # Get all entries for today
    todays_entries = TimeEntry.objects.filter(
        time_in__gte=today_start,
        time_in__lt=today_end
    ).select_related('user', 'user__company', 'user__schedule_group')

    processed_entries = []
    late_count = 0

    for entry in todays_entries:
        user = entry.user
        time_in_local = entry.time_in

        # Get user name or default to ID
        first_name = user.first_name or ""
        surname = user.surname or ""
        full_name = f"{first_name} {surname}".strip()
        if not full_name:
            full_name = f"User {user.employee_id}"

        # Use the stored minutes_late value
        if entry.is_late:
            late_count += 1

        processed_entries.append({
            'employee_id': user.employee_id,
            'name': full_name,
            'company': user.company.name if user.company else "",
            'time_in': time_in_local.strftime("%I:%M %p"),
            'time_out': entry.time_out.strftime("%I:%M %p") if entry.time_out else None,
            'minutes_diff': entry.minutes_late,  # Use the stored value
            'is_late': entry.is_late
        })

    # Sort entries - late ones by how late they are (descending)
    late_entries = sorted(
        [e for e in processed_entries if e['is_late']],
        key=lambda x: x['minutes_diff'],
        reverse=True
    )[:5]

    # Sort entries - early ones by how early they are (ascending)
    early_entries = sorted(
        [e for e in processed_entries if not e['is_late']],
        key=lambda x: x['minutes_diff']
    )[:5]

    return JsonResponse({
        'today_entries': processed_entries,
        'top_late': late_entries,
        'top_early': early_entries,
        'late_count': late_count
    })