from django.http import JsonResponse
from django.db import connection
import logging

logger = logging.getLogger(__name__)


class PlanLimitMiddleware:
    """
    Runs AFTER TenantMainMiddleware.
    On POST to resource-creating endpoints, checks if the tenant's
    current usage exceeds their subscription plan limits.
    Returns 402 with upgrade_required=True if limit exceeded.
    """
    LIMIT_ENDPOINTS = {
        '/api/products/': 'product_limit',
        '/api/variants/': 'product_limit',
        '/api/locations/': 'location_limit',
        '/api/users/': 'user_limit',
    }

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if request.method == 'POST':
            for path_prefix, limit_field in self.LIMIT_ENDPOINTS.items():
                if request.path.startswith(path_prefix):
                    result = self._check_limit(limit_field)
                    if result:
                        return result
                    break
        return self.get_response(request)

    def _check_limit(self, limit_field):
        try:
            tenant = getattr(connection, 'tenant', None)
            if not tenant:
                return None

            from apps.tenants.models import Subscription
            try:
                sub = Subscription.objects.get(tenant=tenant)
            except Subscription.DoesNotExist:
                return None

            limit = getattr(sub, limit_field, None)
            if limit is None or limit == 0:
                return None  # 0 = unlimited

            current_count = self._get_current_count(limit_field)
            if current_count >= limit:
                return JsonResponse({
                    'success': False,
                    'message': f'Plan limit reached. Your {sub.plan} plan allows {limit} {limit_field.replace("_limit", "")}s.',
                    'errors': {
                        'upgrade_required': True,
                        'current_count': current_count,
                        'limit': limit,
                        'plan': sub.plan,
                    },
                }, status=402)
        except Exception as e:
            logger.error(f'PlanLimitMiddleware error: {e}')
        return None

    def _get_current_count(self, limit_field):
        if limit_field == 'product_limit':
            from apps.products.models import Product
            return Product.objects.filter(is_active=True).count()
        elif limit_field == 'user_limit':
            from apps.auth_app.models import User
            return User.objects.filter(is_active=True).count()
        elif limit_field == 'location_limit':
            from apps.locations.models import Location
            return Location.objects.filter(is_active=True).count()
        return 0
