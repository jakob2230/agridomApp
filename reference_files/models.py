import datetime
from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.db import models
from django.db.models import Max
from django.conf import settings
from django.core.validators import MinLengthValidator
from django.forms import ValidationError
from django.utils import timezone
from django.utils.html import format_html
from .utils import get_day_code, format_minutes, create_default_time_preset  # Import from utils.py


class CustomUserManager(BaseUserManager):
    def get_next_employee_id(self):
        # Get the highest employee ID currently in use
        highest_id = self.model.objects.aggregate(Max("employee_id"))[
            "employee_id__max"
        ]

        if not highest_id:
            return "000001"  # First employee

        next_id = int(highest_id) + 1

        # If next ID would exceed 999999, look for gaps
        if next_id > 999999:
            # Get all employee IDs sorted
            existing_ids = set(self.model.objects.values_list("employee_id", flat=True))

            # Find first available gap
            for i in range(1, 1000000):  # From 000001 to 999999
                candidate = str(i).zfill(6)
                if candidate not in existing_ids:
                    return candidate

            raise ValueError("No available employee IDs - all slots filled")

        # Normal case - return next highest ID
        return str(next_id).zfill(6)

    def create_user(self, employee_id=None, password=None, **extra_fields):
        if not employee_id:
            employee_id = self.get_next_employee_id()

        # Validate employee_id is numeric and 6 digits
        if not employee_id.isdigit() or len(employee_id) != 6:
            raise ValidationError("Employee ID must be a 6-digit number")

        user = self.model(employee_id=employee_id, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, employee_id=None, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("is_active", True)

        if extra_fields.get("is_staff") is not True:
            raise ValueError("Superuser must have is_staff=True.")
        if extra_fields.get("is_superuser") is not True:
            raise ValueError("Superuser must have is_superuser=True.")

        return self.create_user(employee_id, password, **extra_fields)


class Company(models.Model):
    name = models.CharField(max_length=100, unique=True)

    def __str__(self):
        return self.name

    class Meta:
        verbose_name_plural = "User Companies"
        ordering = ["name"]
        db_table = "django_companies"  # Changed from 'companies'

class Department(models.Model):
    name = models.CharField(max_length=100, unique=True)

    def __str__(self):
        return self.name

    class Meta:
        verbose_name_plural = "User Departments"
        ordering = ["name"]
        db_table = "django_departments"



class Position(models.Model):
    name = models.CharField(max_length=100, unique=True)

    def __str__(self):
        return self.name

    class Meta:
        verbose_name_plural = "User Positions"
        ordering = ["name"]
        db_table = "django_positions"  # Changed from 'positions'


class CustomUser(AbstractUser):
    # Remove the username field
    username = None
    employee_id = models.CharField(unique=True, max_length=6)
    first_name = models.CharField(max_length=100, null=True, blank=True)
    surname = models.CharField(max_length=100, null=True, blank=True)
    company = models.ForeignKey(
        Company, on_delete=models.SET_NULL, null=True, blank=True
    )
    position = models.ForeignKey(
        Position, on_delete=models.SET_NULL, null=True, blank=True
    )
    birth_date = models.DateField(null=True, blank=True)
    date_hired = models.DateField(null=True, blank=True)
    pin = models.CharField(
        max_length=4, validators=[MinLengthValidator(4)], null=True, blank=True
    )
    schedule_group = models.ForeignKey(
        "ScheduleGroup",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="users",
        verbose_name="Time Schedule",
    )
    # Remove other redundant fields
    email = None
    last_name = None  # Since you're using 'surname'
    is_staff = models.BooleanField(default=False)
    is_superuser = models.BooleanField(default=False)
    is_guard = models.BooleanField(default=False)
    if_first_login = models.BooleanField(default=True)

    USERNAME_FIELD = "employee_id"
    REQUIRED_FIELDS = []

    objects = CustomUserManager()

    @classmethod
    def authenticate_by_pin(cls, employee_id, pin):
        try:
            user = cls.objects.get(employee_id=employee_id)
            if not user.is_active:
                return None
            if user.is_superuser:
                if user.check_password(pin):
                    return user
            elif user.is_staff:
                if user.pin == pin:
                    return user
            elif user.if_first_login and pin == "0000":
                return {"status": "first_login", "user": user}
            elif user.pin == pin:
                return user
            return None
        except cls.DoesNotExist:
            return None

    def get_schedule_for_day(self, day_code):
        """Get the schedule that applies to this user for the specified day."""
        if self.schedule_group:
            return self.schedule_group.get_schedule_for_day(day_code)
        else:
            # Use the utility function to create default schedules
            return create_default_time_preset(day_code)

    class Meta:
        db_table = "django_users"  # Changed from 'users'
        verbose_name = "User"
        verbose_name_plural = "Users"


class TimeEntry(models.Model):
    ordering = ["-time_in"]
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    time_in = models.DateTimeField(default=timezone.now, editable=True)
    time_out = models.DateTimeField(null=True, blank=True)
    hours_worked = models.FloatField(null=True, blank=True)
    is_late = models.BooleanField(default=False)
    minutes_late = models.IntegerField(default=0)  # New field: positive for late, negative for early
    last_modified = models.DateTimeField(auto_now=True)
    image_path = models.CharField(max_length=255, null=True, blank=True)
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    location_accuracy = models.FloatField(null=True, blank=True)
    location_address = models.TextField(blank=True, null=True)
    checkout_latitude = models.FloatField(null=True, blank=True)
    checkout_longitude = models.FloatField(null=True, blank=True)
    checkout_location_accuracy = models.FloatField(null=True, blank=True)
    checkout_location_address = models.TextField(blank=True, null=True)

    @property
    def date(self):
        return self.time_in.date()

    def clock_out(self):
        self.time_out = timezone.now()

        if self.time_in and self.time_out:
            delta = self.time_out - self.time_in
            self.hours_worked = round(delta.total_seconds() / 3600, 2)

        # Use user's schedule for lateness check if available
        if self.time_in:
            try:
                time_in_local = self.time_in
                day_code = get_day_code(time_in_local)  # Using utility function

                # Get schedule using get_schedule_for_day
                preset = self.user.get_schedule_for_day(day_code)
                if preset:
                    expected_start = preset.start_time
                    grace_period = datetime.timedelta(minutes=preset.grace_period_minutes)

                    # Create datetime with schedule time
                    naive_expected_time = datetime.datetime.combine(
                        time_in_local.date(), expected_start
                    )

                    # Make timezone-aware
                    expected_start_dt = timezone.make_aware(naive_expected_time)
                    expected_with_grace = expected_start_dt + grace_period

                    # Ensure time_in_local is timezone aware for comparison
                    if not timezone.is_aware(time_in_local):
                        time_in_local = timezone.make_aware(time_in_local)

                    # Now both datetimes are timezone-aware for safe comparison
                    self.is_late = time_in_local > expected_with_grace

                    # Calculate minutes late/early
                    time_diff = time_in_local - expected_start_dt
                    self.minutes_late = round(time_diff.total_seconds() / 60)
                else:
                    self.is_late = False
                    self.minutes_late = 0
            except Exception as e:
                # In case of errors, don't mark as late
                self.is_late = False
                self.minutes_late = 0
                print(f"Error in clock_out: {e}")

        self.save()

    @classmethod
    def clock_in(cls, user):
        open_entries = cls.objects.filter(user=user, time_out__isnull=True)
        for entry in open_entries:
            entry.clock_out()

        new_entry = cls.objects.create(user=user)

        # Calculate lateness based on schedule
        try:
            time_in_local = new_entry.time_in
            # Use utility function instead of duplicating the day mapping
            day_code = get_day_code(time_in_local)

            # Get the appropriate schedule
            preset = user.get_schedule_for_day(day_code)
            if preset:
                # Create a datetime object with schedule time
                naive_expected_time = datetime.datetime.combine(
                    time_in_local.date(), preset.start_time
                )

                # Make timezone-aware
                expected_time = timezone.make_aware(naive_expected_time)

                # Ensure time_in_local is timezone-aware
                if not timezone.is_aware(time_in_local):
                    time_in_local = timezone.make_aware(time_in_local)

                # Calculate grace period
                grace_period = datetime.timedelta(minutes=preset.grace_period_minutes)
                expected_time_with_grace = expected_time + grace_period

                # Both datetimes are now timezone-aware for safe comparison
                new_entry.is_late = time_in_local > expected_time_with_grace

                # Calculate minutes late
                time_diff = time_in_local - expected_time
                new_entry.minutes_late = round(time_diff.total_seconds() / 60)
                new_entry.save()
        except Exception as e:
            # If timezone handling fails, set reasonable defaults
            new_entry.is_late = False
            new_entry.minutes_late = 0
            new_entry.save()
            print(f"Error in clock_in: {e}")

        return new_entry

    def __str__(self):
        return f"{self.user.employee_id} - {self.user.first_name} {self.user.surname} - {self.time_in.strftime('%Y-%m-%d %H:%M:%S')}"

    class Meta:
        verbose_name_plural = "Time Entries"
        db_table = "django_time_entries"


class Announcement(models.Model):
    content = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    is_posted = models.BooleanField(default=False)

    def __str__(self):
        return f"Announcement {self.id}"

    class Meta:
        db_table = "django_announcements"


class TimePreset(models.Model):
    name = models.CharField(max_length=100, blank=True, null=True)
    start_time = models.TimeField()
    end_time = models.TimeField()
    grace_period_minutes = models.IntegerField(default=5)
    created_at = models.DateTimeField(auto_now_add=True)

    def save(self, *args, **kwargs):
        if self.name is None:
            self.name = ""
        super(TimePreset, self).save(*args, **kwargs)

    def __str__(self):
        return f"{self.name} ({self.start_time.strftime('%I:%M %p')} - {self.end_time.strftime('%I:%M %p')})"

    class Meta:
        verbose_name = "Time Preset"
        verbose_name_plural = "Time Presets"
        ordering = ["start_time"]


class ScheduleGroup(models.Model):
    name = models.CharField(max_length=100, null=True, blank=True)
    default_schedule = models.ForeignKey(
        "TimePreset", on_delete=models.SET_NULL, null=True, blank=True, related_name="default_for_groups"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    def save(self, *args, **kwargs):
        if self.name is None or self.name == "":
            start_time = self.default_schedule.start_time.strftime("%I:%M %p")
            end_time = self.default_schedule.end_time.strftime("%I:%M %p")
            self.name = f"{start_time} - {end_time}"
        super(ScheduleGroup, self).save(*args, **kwargs)

    def __str__(self):
        return f"{self.name}"

    def get_schedule_for_day(self, day_code):
        """Get the appropriate TimePreset for a specific day"""
        # Check if there's a day-specific override
        try:
            override = self.day_overrides.get(day=day_code)
            return override.time_preset
        except DayOverride.DoesNotExist:
            # If no override exists, return the default schedule
            if self.default_schedule:
                return self.default_schedule
            else:
                # Use the utility function to create default schedules
                return create_default_time_preset(day_code)

    class Meta:
        verbose_name = "Time Schedule"
        verbose_name_plural = "Time Schedules"
        ordering = ["name"]


class DayOverride(models.Model):
    DAY_CHOICES = [
        ("mon", "Monday"),
        ("tue", "Tuesday"),
        ("wed", "Wednesday"),
        ("thu", "Thursday"),
        ("fri", "Friday"),
        ("sat", "Saturday"),
        ("sun", "Sunday"),
    ]

    schedule_group = models.ForeignKey(
        ScheduleGroup, on_delete=models.CASCADE, related_name="day_overrides"
    )
    day = models.CharField(max_length=3, choices=DAY_CHOICES)
    time_preset = models.ForeignKey(
        "TimePreset", on_delete=models.SET_NULL, null=True, blank=True, related_name="used_in_overrides"
    )

    class Meta:
        verbose_name = "Day Override"
        verbose_name_plural = "Day Overrides"
        unique_together = [
            "schedule_group",
            "day",
        ]  # Only one override per day per group
