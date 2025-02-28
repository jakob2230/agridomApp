import json
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.cache import never_cache
from django.contrib.auth import login
from .models import CustomerUser

@csrf_exempt
@never_cache
def login_view(request):
    if request.method == "POST":
        try:
            data = json.loads(request.body)
        except json.JSONDecodeError:
            return JsonResponse({"success": False, "message": "Invalid JSON"})

        # Retrieve credentials from the request body
        employee_id = data.get("username")
        pin = data.get("password")

        try:
            # Check if the user exists and is active
            user = CustomerUser.objects.get(employee_id=employee_id)
            if not user.is_active:
                return JsonResponse({"success": False, "message": "This account is inactive"})

            # Try to authenticate using the provided PIN
            auth_result = CustomerUser.authenticate_by_pin(employee_id, pin)
            if auth_result:
                # If authenticate_by_pin returns a CustomerUser or a dict containing the user
                user = auth_result if isinstance(auth_result, CustomerUser) else auth_result["user"]
                login(request, user)  # Establish the session if needed

                # Return a JSON response with a redirect indicator for your Flutter app
                return JsonResponse({
                    "success": True,
                    "message": "Login successful",
                    "redirect": "maindash"
                })
            else:
                return JsonResponse({"success": False, "message": "Incorrect PIN"})
        except CustomerUser.DoesNotExist:
            return JsonResponse({"success": False, "message": "Employee ID not found"})
    else:
        return JsonResponse({"success": False, "message": "Only POST requests are allowed"})