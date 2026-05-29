from rest_framework.permissions import BasePermission


class CanCreateOrder(BasePermission):
    """Admin, Manager, or Sales can create orders."""
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return request.user.role in ('ADMIN', 'MANAGER', 'SALES', 'STAFF')


class CanApproveOrder(BasePermission):
    """Only Admin or Manager can approve/confirm orders."""
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return request.user.role in ('ADMIN', 'MANAGER')


class CanDispatch(BasePermission):
    """Admin or Warehouse roles can dispatch orders."""
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return request.user.role in ('ADMIN', 'WAREHOUSE')


class CanMarkDelivered(BasePermission):
    """Admin or Warehouse roles can mark orders as delivered."""
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return request.user.role in ('ADMIN', 'WAREHOUSE')


class CanViewReports(BasePermission):
    """Admin or Manager can view reports."""
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return request.user.role in ('ADMIN', 'MANAGER')


class CanManageUsers(BasePermission):
    """Only Admin can manage users."""
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return request.user.role == 'ADMIN'


# ── U4: 4-Department Permission Classes ──────────────────────────────────

class IsStockIncomingDept(BasePermission):
    """STAFF role → only stock IN operations."""
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return request.user.role in ('ADMIN', 'MANAGER', 'STAFF')


class IsBookingDept(BasePermission):
    """SALES + MANAGER → orders + product search."""
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return request.user.role in ('ADMIN', 'MANAGER', 'SALES')


class IsDeliveryDept(BasePermission):
    """WAREHOUSE role → delivery status update only."""
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return request.user.role in ('ADMIN', 'WAREHOUSE')


class IsViewerDept(BasePermission):
    """VIEWER role → GET only (live stock + pending orders)."""
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        if request.user.role == 'VIEWER':
            return request.method == 'GET'
        return True  # Non-viewers pass through to more specific permissions
