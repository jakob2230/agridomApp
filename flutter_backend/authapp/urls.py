from django.urls import path
from . import views
from django.contrib import admin
from django.urls import path, include
from django.views.generic import RedirectView


urlpatterns = [
    path('', RedirectView.as_view(url='/static/flutter_app/index.html', permanent=False)),
    path('/login/', views.login_view, name='api_login'),
    path('login/', views.login_view),
    path('admin/', admin.site.urls),
]