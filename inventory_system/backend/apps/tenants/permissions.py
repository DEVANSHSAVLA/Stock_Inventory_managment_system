from rest_framework.permissions import BasePermission


class IsSuperAdmin(BasePermission):
    """
    Only allows access to the super-admin user who manages all tenants
    from the public schema. Checked against SUPERADMIN_EMAIL in settings.
    """
    def has_permission(self, request, view):
        from django.conf import settings
        superadmin_email = getattr(settings, 'SUPERADMIN_EMAIL', '')
        return (
            request.user
            and request.user.is_authenticated
            and request.user.email == superadmin_email
        )


class IsTenantAdmin(BasePermission):
    """
    Allows access only to users with the ADMIN role within their tenant.
    """
    def has_permission(self, request, view):
        return (
            request.user
            and request.user.is_authenticated
            and hasattr(request.user, 'role')
            and request.user.role == 'ADMIN'
        )
