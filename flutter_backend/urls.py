from django.urls import path
from django.contrib import admin
from django.views.generic import RedirectView
from .authapp import views


urlpatterns = [
    # Redirect root to your Flutter app's static page
    path('', RedirectView.as_view(url='/static/flutter_app/index.html', permanent=False)),
    
    # Define the API endpoint for login
    path('api/login/', views.login_view, name='api_login'),
    
    # Admin route
    path('admin/', admin.site.urls),
]
