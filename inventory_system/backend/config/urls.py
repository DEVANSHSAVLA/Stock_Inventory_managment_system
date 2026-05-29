from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from django.http import JsonResponse

from apps.tenants.urls import public_urlpatterns, tenant_urlpatterns

def root_status_view(request):
    return JsonResponse({
        "status": "online",
        "message": "InventoryPro API Backend is fully operational",
        "tenant_resolve_endpoint": "/api/public/resolve-tenant/"
    })

urlpatterns = [
    path('', root_status_view),
    path('admin/', admin.site.urls),

    # ── Public endpoints (no tenant schema required) ──────────────────────
    path('api/public/', include(public_urlpatterns)),

    # ── Tenant-scoped endpoints (TenantMainMiddleware sets schema) ─────────
    path('api/auth/', include('apps.auth_app.urls')),
    path('api/', include('apps.auth_app.urls_users')),
    path('api/', include('apps.products.urls')),
    path('api/', include('apps.stock.urls')),
    path('api/', include('apps.reports.urls')),
    path('api/', include('apps.suppliers.urls')),
    path('api/', include('apps.locations.urls')),
    path('api/', include('apps.notifications.urls')),
    path('api/', include(tenant_urlpatterns)),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
