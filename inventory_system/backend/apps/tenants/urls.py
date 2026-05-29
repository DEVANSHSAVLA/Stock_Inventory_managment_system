from django.urls import path
from .views import (
    SignupView, LoginView, ResolveTenantView, TenantDetailView,
    SubscriptionView, SubscriptionUsageView, UpgradePlanView,
    SuperAdminTenantsView,
)

# Public endpoints (no JWT required) — mounted at /api/public/
public_urlpatterns = [
    path('signup/', SignupView.as_view(), name='tenant-signup'),
    path('login/', LoginView.as_view(), name='tenant-login'),
    path('resolve-tenant/', ResolveTenantView.as_view(), name='resolve-tenant'),
]

# Tenant-scoped endpoints (JWT required) — mounted at /api/
tenant_urlpatterns = [
    path('tenant/', TenantDetailView.as_view(), name='tenant-detail'),
    path('subscription/', SubscriptionView.as_view(), name='subscription-detail'),
    path('subscription/usage/', SubscriptionUsageView.as_view(), name='subscription-usage'),
    path('subscription/upgrade/', UpgradePlanView.as_view(), name='subscription-upgrade'),
    path('superadmin/tenants/', SuperAdminTenantsView.as_view(), name='superadmin-tenants'),
]
