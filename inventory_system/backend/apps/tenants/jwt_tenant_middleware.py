"""
JWT-aware Tenant Schema Middleware (HTTP)
─────────────────────────────────────────
Runs AFTER TenantMainMiddleware and CorsMiddleware, but BEFORE
AuthenticationMiddleware.

Problem it solves:
  TenantMainMiddleware resolves the tenant by the Host header.
  When the Flutter app calls localhost:8000, the Host is "localhost",
  which maps to the PUBLIC schema.  But the user was created inside
  the tenant schema (e.g. "demo"), so JWTAuthentication cannot find
  the user → 401.

Solution:
  Before authentication runs, this middleware inspects:
    1. X-Tenant-ID header
    2. ?tenant= query parameter
    3. tenant_schema claim inside the JWT access token
  If any of these identify a valid tenant schema, it calls
  connection.set_tenant() to switch the DB connection so the user
  lookup happens in the correct schema.
"""

import logging
from django.db import connection
from django_tenants.utils import get_tenant_model

logger = logging.getLogger(__name__)


class JWTTenantMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        schema_name = self._resolve_schema(request)

        if schema_name and schema_name != 'public':
            try:
                TenantModel = get_tenant_model()
                tenant = TenantModel.objects.get(schema_name=schema_name)
                connection.set_tenant(tenant)
            except TenantModel.DoesNotExist:
                logger.warning(f'JWTTenantMiddleware: tenant "{schema_name}" not found')

        response = self.get_response(request)
        return response

    def _resolve_schema(self, request):
        # Priority 1: X-Tenant-ID header
        schema = request.META.get('HTTP_X_TENANT_ID', '').strip()
        if schema:
            return schema

        # Priority 2: ?tenant= query parameter
        schema = request.GET.get('tenant', '').strip()
        if schema:
            return schema

        # Priority 3: tenant_schema claim in the JWT access token
        auth_header = request.META.get('HTTP_AUTHORIZATION', '')
        if auth_header.startswith('Bearer '):
            token_str = auth_header[7:]
            try:
                from rest_framework_simplejwt.tokens import AccessToken
                token = AccessToken(token_str)
                schema = token.get('tenant_schema', '')
                if schema:
                    return schema
            except Exception:
                pass

        return None
