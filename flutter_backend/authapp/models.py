# authapp/models.py
from django.db import models
from django.core.validators import MinLengthValidator

class Company(models.Model):
    name = models.CharField(max_length=255)
    # Add other fields as needed

    def __str__(self):
        return self.name
    
    class Meta:
        db_table = "django_companies"

class Position(models.Model):
    title = models.CharField(max_length=255)
    # Add other fields as needed

    def __str__(self):
        return self.title
    
    class Meta:
        db_table = "django_positions"

class CustomerUser(models.Model):
    employee_id = models.CharField(unique=True, max_length=6)
    first_name = models.CharField(max_length=100, null=True, blank=True)
    surname = models.CharField(max_length=100, null=True, blank=True)
    company = models.ForeignKey(Company, on_delete=models.SET_NULL, null=True, blank=True)
    position = models.ForeignKey(Position, on_delete=models.SET_NULL, null=True, blank=True)
    birth_date = models.DateField(null=True, blank=True)
    date_hired = models.DateField(null=True, blank=True)
    pin = models.CharField(max_length=4, validators=[MinLengthValidator(4)], null=True, blank=True)
    preset_name = models.CharField(max_length=100, null=True, blank=True)
    is_staff = models.BooleanField(default=False)
    is_superuser = models.BooleanField(default=False)
    is_guard = models.BooleanField(default=False)
    if_first_login = models.BooleanField(default=True)
    is_active = models.BooleanField(default=True)

    

    def __str__(self):
        return self.employee_id

    @classmethod
    def authenticate_by_pin(cls, employee_id, pin):
        try:
            user = cls.objects.get(employee_id=employee_id)
            if user.pin == pin:
                return user
            else:
                return None
        except cls.DoesNotExist:
            return None
    
    class Meta:
        db_table = "django_users"