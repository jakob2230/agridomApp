from django.http import JsonResponse, HttpResponse
from django.views.decorators.csrf import csrf_exempt
import json
from .models import CustomUser, TimeEntry
from django.utils import timezone
from datetime import datetime, timedelta
from .utils import get_company_logo
import os
from django.core.files.base import ContentFile
from django.core.files.storage import default_storage
import base64

@csrf_exempt
def api_clock_in(request):
    # Handle OPTIONS request (CORS preflight)
    if request.method == 'OPTIONS':
        response = HttpResponse()
        response["Access-Control-Allow-Origin"] = "*"
        response["Access-Control-Allow-Methods"] = "POST, OPTIONS"
        response["Access-Control-Allow-Headers"] = "Content-Type, X-CSRFToken, Authorization"
        response["Access-Control-Max-Age"] = "86400"
        return response

    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            employee_id = data.get("employee_id")
            pin = data.get("pin")
            location = data.get("location", {})  # Get location data from request
            image_data = data.get("image_data")  # Base64 encoded image

            # Authentication
            auth_result = CustomUser.authenticate_by_pin(employee_id, pin)

            if not auth_result:
                return JsonResponse({"success": False, "error": "Authentication failed"})

            # Handle first login cases
            if isinstance(auth_result, dict) and auth_result["status"] == "first_login":
                new_pin = data.get("new_pin")
                if new_pin:
                    user = auth_result["user"]
                    user.pin = new_pin
                    user.if_first_login = False
                    user.save()
                    return JsonResponse({"success": True, "message": "PIN updated successfully"})
                else:
                    return JsonResponse({
                        "success": False,
                        "error": "first_login",
                        "message": "First login detected. Please set a new PIN."
                    })

            # Regular clock in
            user = auth_result

            # Save the image if provided
            image_path = None
            if image_data:
                image_path = save_image_from_base64(image_data, user)

            # Create time entry
            entry = TimeEntry.clock_in(user)

            # Save image path
            if image_path:
                entry.image_path = image_path

            # Save location data
            if location:
                entry.latitude = location.get("latitude")
                entry.longitude = location.get("longitude")
                entry.location_accuracy = location.get("accuracy")
                entry.location_address = location.get("address", "")

            entry.save()

            # Get company logo
            user_company = user.company.name if user.company else ""
            company_logo = get_company_logo(user_company)

            # Return response
            return JsonResponse({
                "success": True,
                "employee_id": user.employee_id,
                "name": f"{user.first_name} {user.surname}",
                "time": entry.time_in.strftime("%Y-%m-%d %H:%M:%S"),
                "is_late": entry.is_late,
                "company_logo": company_logo
            })

        except Exception as e:
            return JsonResponse({"success": False, "error": str(e)})

    return JsonResponse({"success": False, "error": "Method not allowed"})


@csrf_exempt
def api_clock_out(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            employee_id = data.get("employee_id")
            pin = data.get("pin")
            location = data.get("location", {})  # Get location data

            # Authentication
            user = CustomUser.authenticate_by_pin(employee_id, pin)

            if not user:
                return JsonResponse({"success": False, "error": "Authentication failed"})

            # Handle first login cases (in case they try to clock out first time)
            if isinstance(user, dict) and user["status"] == "first_login":
                return JsonResponse({
                    "success": False,
                    "error": "first_login",
                    "message": "First login detected. Please set a new PIN and clock in first."
                })

            try:
                # Find the open time entry for today
                now = timezone.now()
                today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
                today_end = today_start + timedelta(days=1)

                open_entry = TimeEntry.objects.filter(
                    user=user,
                    time_out__isnull=True,
                    time_in__gte=today_start,
                    time_in__lt=today_end,
                ).latest("time_in")

                # Clock out
                open_entry.clock_out()

                # Save location data for clock out
                if location:
                    open_entry.checkout_latitude = location.get("latitude")
                    open_entry.checkout_longitude = location.get("longitude")
                    open_entry.checkout_location_accuracy = location.get("accuracy")
                    open_entry.checkout_location_address = location.get("address", "")
                    open_entry.save()

                # Get company logo
                user_company = user.company.name if user.company else ""
                company_logo = get_company_logo(user_company)

                # Return success response
                return JsonResponse({
                    "success": True,
                    "employee_id": user.employee_id,
                    "name": f"{user.first_name} {user.surname}",
                    "time_in": open_entry.time_in.strftime("%Y-%m-%d %H:%M:%S"),
                    "time_out": open_entry.time_out.strftime("%Y-%m-%d %H:%M:%S"),
                    "duration": format_duration(open_entry.time_in, open_entry.time_out),
                    "company_logo": company_logo
                })

            except TimeEntry.DoesNotExist:
                return JsonResponse({"success": False, "error": "No active clock in found for today."})

        except Exception as e:
            return JsonResponse({"success": False, "error": str(e)})

    return JsonResponse({"success": False, "error": "Method not allowed"})


@csrf_exempt
def api_user_info(request, employee_id):
    """Endpoint to get basic user info for the mobile app"""
    # Handle OPTIONS request (CORS preflight)
    if request.method == 'OPTIONS':
        response = HttpResponse()
        response["Access-Control-Allow-Origin"] = "*"
        response["Access-Control-Allow-Methods"] = "POST, OPTIONS"
        response["Access-Control-Allow-Headers"] = "Content-Type, X-CSRFToken, Authorization"
        response["Access-Control-Max-Age"] = "86400"  # 24 hours
        return response

    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            pin = data.get("pin")

            # Authenticate the user
            user = CustomUser.authenticate_by_pin(employee_id, pin)

            if not user:
                return JsonResponse({"success": False, "error": "Authentication failed"})

            # Check if first login
            if isinstance(user, dict) and user["status"] == "first_login":
                return JsonResponse({
                    "success": False,
                    "error": "first_login",
                    "message": "First login detected. Please set a new PIN."
                })

            # Get company logo
            user_company = user.company.name if user.company else ""
            company_logo = get_company_logo(user_company)

            # Get today's entry if any
            now = timezone.now()
            today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
            today_end = today_start + timedelta(days=1)

            try:
                todays_entry = TimeEntry.objects.filter(
                    user=user,
                    time_in__gte=today_start,
                    time_in__lt=today_end
                ).latest("time_in")

                clocked_in = True
                clocked_out = todays_entry.time_out is not None
                time_in = todays_entry.time_in.strftime("%Y-%m-%d %H:%M:%S")
                time_out = todays_entry.time_out.strftime("%Y-%m-%d %H:%M:%S") if todays_entry.time_out else None

            except TimeEntry.DoesNotExist:
                clocked_in = False
                clocked_out = False
                time_in = None
                time_out = None

            # Return user info
            return JsonResponse({
                "success": True,
                "employee_id": user.employee_id,
                "name": f"{user.first_name} {user.surname}",
                "company": user_company,
                "department": user.department,
                "company_logo": company_logo,
                "status": {
                    "clocked_in": clocked_in,
                    "clocked_out": clocked_out,
                    "time_in": time_in,
                    "time_out": time_out
                }
            })

        except Exception as e:
            return JsonResponse({"success": False, "error": str(e)})

    return JsonResponse({"success": False, "error": "Method not allowed"})


@csrf_exempt
def api_upload_image(request):
    """Standalone endpoint to upload an image"""
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            employee_id = data.get("employee_id")
            pin = data.get("pin")
            image_data = data.get("image_data")  # Base64 encoded image

            if not image_data:
                return JsonResponse({"success": False, "error": "No image data provided"})

            # Authenticate user
            user = CustomUser.authenticate_by_pin(employee_id, pin)

            if not user:
                return JsonResponse({"success": False, "error": "Authentication failed"})

            if isinstance(user, dict) and user["status"] == "first_login":
                return JsonResponse({"success": False, "error": "Please complete first login process"})

            # Save the image
            image_path = save_image_from_base64(image_data, user)

            return JsonResponse({
                "success": True,
                "file_path": image_path
            })

        except Exception as e:
            return JsonResponse({"success": False, "error": str(e)})

    return JsonResponse({"success": False, "error": "Method not allowed"})


@csrf_exempt
def api_test(request):
    """Simple test endpoint to verify CORS is working"""
    if request.method == 'OPTIONS':
        response = HttpResponse()
        response["Access-Control-Allow-Origin"] = "*"
        response["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
        response["Access-Control-Allow-Headers"] = "Content-Type, X-CSRFToken, Authorization"
        response["Access-Control-Max-Age"] = "86400"
        return response

    return JsonResponse({
        "success": True,
        "message": "API is working! CORS is properly configured.",
        "method": request.method,
    })


# Helper functions
def save_image_from_base64(base64_data, user):
    """Save base64 image data to file system"""
    try:
        # Remove the data:image/jpeg;base64, part if present
        if ';base64,' in base64_data:
            base64_data = base64_data.split(';base64,')[1]

        # Decode base64 data
        image_data = base64.b64decode(base64_data)

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
        file_name = f"{timestamp}_{user.employee_id}_{user.surname}{user.first_name}.jpg"
        file_path = os.path.join(directory, file_name)

        # Save the file
        file_path = default_storage.save(file_path, ContentFile(image_data))

        return file_path

    except Exception as e:
        print(f"Error saving image: {str(e)}")
        return None


def format_duration(time_in, time_out):
    """Format the duration between time_in and time_out"""
    if not time_in or not time_out:
        return "N/A"

    duration = time_out - time_in
    hours, remainder = divmod(duration.total_seconds(), 3600)
    minutes, seconds = divmod(remainder, 60)

    return f"{int(hours)}h {int(minutes)}m"