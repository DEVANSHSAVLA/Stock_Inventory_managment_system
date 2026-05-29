from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    ROLE_ADMIN = 'ADMIN'
    ROLE_MANAGER = 'MANAGER'
    ROLE_STAFF = 'STAFF'
    ROLE_WAREHOUSE = 'WAREHOUSE'
    ROLE_SALES = 'SALES'
    ROLE_VIEWER = 'VIEWER'
    ROLE_CHOICES = [
        (ROLE_ADMIN, 'Admin'),
        (ROLE_MANAGER, 'Manager'),
        (ROLE_STAFF, 'Staff'),
        (ROLE_WAREHOUSE, 'Warehouse'),
        (ROLE_SALES, 'Sales'),
        (ROLE_VIEWER, 'Viewer'),
    ]

    email = models.EmailField(unique=True)
    role = models.CharField(max_length=10, choices=ROLE_CHOICES, default=ROLE_STAFF)
    is_active = models.BooleanField(default=True)
    phone = models.CharField(max_length=20, blank=True)
    last_tenant_schema = models.CharField(max_length=63, blank=True, null=True)
    profile_image = models.ImageField(upload_to='profile_images/', null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['username']

    def __str__(self):
        return f'{self.email} ({self.role})'

    @property
    def is_admin(self):
        return self.role == self.ROLE_ADMIN

    @property
    def is_manager(self):
        return self.role == self.ROLE_MANAGER

    @property
    def is_staff_role(self):
        return self.role == self.ROLE_STAFF

    @property
    def is_warehouse(self):
        return self.role == self.ROLE_WAREHOUSE

    @property
    def is_sales(self):
        return self.role == self.ROLE_SALES

    @property
    def is_viewer(self):
        return self.role == self.ROLE_VIEWER

    @property
    def can_approve(self):
        return self.role in (self.ROLE_ADMIN, self.ROLE_MANAGER)

    @property
    def can_view_reports(self):
        return self.role in (self.ROLE_ADMIN, self.ROLE_MANAGER)

    @property
    def can_manage_users(self):
        return self.role == self.ROLE_ADMIN

