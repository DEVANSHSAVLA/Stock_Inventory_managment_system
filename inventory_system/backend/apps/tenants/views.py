from rest_framework import status
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from django.db import connection
from django_tenants.utils import schema_context

from .models import Tenant, Domain, Subscription
from .serializers import (
    TenantSignupSerializer, TenantLoginSerializer,
    TenantDetailSerializer, SubscriptionDetailSerializer
)
from .permissions import IsTenantAdmin, IsSuperAdmin


def success_response(data=None, message='', status_code=status.HTTP_200_OK):
    return Response({'success': True, 'data': data or {}, 'message': message, 'errors': {}},
                    status=status_code)


def error_response(errors=None, message='', status_code=status.HTTP_400_BAD_REQUEST):
    return Response({'success': False, 'data': {}, 'message': message, 'errors': errors or {}},
                    status=status_code)


class SignupView(APIView):
    """
    POST /api/public/signup/
    Creates a new tenant (schema), admin user, and FREE subscription.
    Returns JWT tokens + tenant metadata.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = TenantSignupSerializer(data=request.data)
        if not serializer.is_valid():
            return error_response(errors=serializer.errors, message='Signup validation failed.')

        data = serializer.validated_data
        subdomain = data['subdomain']
        schema_name = subdomain.replace('-', '_')

        try:
            # 1. Create Tenant in public schema (triggers auto schema creation)
            tenant = Tenant.objects.create(
                schema_name=schema_name,
                company_name=data['company_name'],
                subdomain=subdomain,
                owner_email=data['email'],
                plan=Tenant.PLAN_FREE,
            )

            # 2. Create Domain record
            from django.conf import settings
            base_domain = getattr(settings, 'TENANT_DEFAULT_DOMAIN', 'localhost')
            Domain.objects.create(
                domain=f'{subdomain}.{base_domain}',
                tenant=tenant,
                is_primary=True,
            )

            # 3. Create Subscription
            from datetime import timedelta
            from django.utils import timezone
            Subscription.objects.create(
                tenant=tenant,
                plan=Subscription.PLAN_FREE,
                status=Subscription.STATUS_TRIAL,
                trial_ends_at=timezone.now() + timedelta(days=14),
            )

            # 4. Create admin user inside the tenant schema
            with schema_context(schema_name):
                from apps.auth_app.models import User
                user = User.objects.create_user(
                    email=data['email'],
                    username=data['email'].split('@')[0],
                    password=data['password'],
                    first_name=data.get('first_name', ''),
                    last_name=data.get('last_name', ''),
                    role='ADMIN',
                    is_staff=True,
                )

                # 5. Issue JWT
                refresh = RefreshToken.for_user(user)
                # Add tenant info to token claims
                refresh['tenant_schema'] = schema_name
                refresh['tenant_name'] = data['company_name']

            return success_response(
                data={
                    'access': str(refresh.access_token),
                    'refresh': str(refresh),
                    'tenant': {
                        'schema_name': schema_name,
                        'company_name': data['company_name'],
                        'subdomain': subdomain,
                        'plan': 'FREE',
                    },
                    'user': {
                        'email': data['email'],
                        'role': 'ADMIN',
                    },
                },
                message='Company registered successfully.',
                status_code=status.HTTP_201_CREATED,
            )

        except Exception as e:
            # Cleanup on failure
            Tenant.objects.filter(subdomain=subdomain).delete()
            return error_response(
                message=f'Registration failed: {str(e)}',
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )


class LoginView(APIView):
    """
    POST /api/public/login/
    Tenant-aware login: resolves tenant by subdomain or email,
    validates credentials inside that schema, returns JWT + tenant meta.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = TenantLoginSerializer(data=request.data)
        if not serializer.is_valid():
            return error_response(errors=serializer.errors, message='Login validation failed.')

        data = serializer.validated_data
        email = data['email']
        password = data['password']
        subdomain = data.get('subdomain', '').strip()

        # Resolve tenant
        tenant = None
        if subdomain:
            tenant = Tenant.objects.filter(subdomain=subdomain, is_active=True).first()
        else:
            # Try to find tenant by owner email
            tenant = Tenant.objects.filter(owner_email=email, is_active=True).first()

        if not tenant:
            return error_response(message='Company not found. Check your subdomain.',
                                  status_code=status.HTTP_404_NOT_FOUND)

        # Authenticate inside tenant schema
        with schema_context(tenant.schema_name):
            from django.contrib.auth import authenticate
            from apps.auth_app.models import User
            from apps.auth_app.serializers import UserSerializer

            user = authenticate(username=email, password=password)
            if not user:
                return error_response(message='Invalid credentials.',
                                      status_code=status.HTTP_401_UNAUTHORIZED)
            if not user.is_active:
                return error_response(message='Account is deactivated.',
                                      status_code=status.HTTP_403_FORBIDDEN)

            refresh = RefreshToken.for_user(user)
            refresh['tenant_schema'] = tenant.schema_name
            refresh['tenant_name'] = tenant.company_name

            return success_response(data={
                'access': str(refresh.access_token),
                'refresh': str(refresh),
                'tenant': {
                    'schema_name': tenant.schema_name,
                    'company_name': tenant.company_name,
                    'subdomain': tenant.subdomain,
                    'plan': tenant.plan,
                },
                'user': UserSerializer(user).data,
            }, message='Login successful.')


class ResolveTenantView(APIView):
    """
    POST /api/public/resolve-tenant/
    Given a subdomain, returns tenant info for the Flutter app.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        subdomain = request.data.get('subdomain', '').strip().lower()
        if not subdomain:
            return error_response(message='Subdomain is required.')

        tenant = Tenant.objects.filter(subdomain=subdomain).first()
        if not tenant:
            return error_response(message='Company not found.',
                                  status_code=status.HTTP_404_NOT_FOUND)

        return success_response(data={
            'company_name': tenant.company_name,
            'subdomain': tenant.subdomain,
            'plan': tenant.plan,
            'is_active': tenant.is_active,
        })


class TenantDetailView(APIView):
    """
    GET/PUT /api/tenant/
    Tenant admin can view and update company details.
    """
    permission_classes = [IsAuthenticated, IsTenantAdmin]

    def get(self, request):
        tenant = connection.tenant
        serializer = TenantDetailSerializer(tenant)
        return success_response(data=serializer.data)

    def put(self, request):
        tenant = connection.tenant
        serializer = TenantDetailSerializer(tenant, data=request.data, partial=True)
        if not serializer.is_valid():
            return error_response(errors=serializer.errors)
        serializer.save()
        return success_response(data=serializer.data, message='Tenant updated.')


class SubscriptionView(APIView):
    """
    GET /api/subscription/
    Returns the current subscription details for the tenant.
    """
    permission_classes = [IsAuthenticated, IsTenantAdmin]

    def get(self, request):
        tenant = connection.tenant
        try:
            subscription = tenant.subscription
        except Subscription.DoesNotExist:
            return error_response(message='No subscription found.',
                                  status_code=status.HTTP_404_NOT_FOUND)
        serializer = SubscriptionDetailSerializer(subscription)
        return success_response(data=serializer.data)


class SubscriptionUsageView(APIView):
    """
    GET /api/subscription/usage/
    Returns current resource usage vs plan limits.
    """
    permission_classes = [IsAuthenticated, IsTenantAdmin]

    def get(self, request):
        tenant = connection.tenant
        try:
            sub = tenant.subscription
        except Subscription.DoesNotExist:
            return error_response(message='No subscription found.', status_code=404)

        from apps.products.models import Product
        from apps.auth_app.models import User
        from apps.locations.models import Location

        return success_response(data={
            'plan': sub.plan,
            'status': sub.status,
            'products': {
                'current': Product.objects.filter(is_active=True).count(),
                'limit': sub.product_limit,
            },
            'users': {
                'current': User.objects.filter(is_active=True).count(),
                'limit': sub.user_limit,
            },
            'locations': {
                'current': Location.objects.filter(is_active=True).count(),
                'limit': sub.location_limit,
            },
            'trial_ends_at': sub.trial_ends_at,
            'current_period_end': sub.current_period_end,
        })


class UpgradePlanView(APIView):
    """
    POST /api/subscription/upgrade/
    Upgrades the tenant's plan. In production, this would be triggered by a Stripe webhook.
    """
    permission_classes = [IsAuthenticated, IsTenantAdmin]

    def post(self, request):
        new_plan = request.data.get('plan', '').upper()
        valid_plans = dict(Subscription.PLAN_CHOICES).keys()
        if new_plan not in valid_plans:
            return error_response(message=f'Invalid plan. Choose from: {", ".join(valid_plans)}')

        tenant = connection.tenant
        try:
            sub = tenant.subscription
        except Subscription.DoesNotExist:
            return error_response(message='No subscription found.', status_code=404)

        # Update plan and limits based on tier
        plan_limits = {
            'FREE': {'product_limit': 50, 'user_limit': 5, 'location_limit': 2},
            'PRO': {'product_limit': 500, 'user_limit': 25, 'location_limit': 10},
            'ENTERPRISE': {'product_limit': 0, 'user_limit': 0, 'location_limit': 0},  # 0 = unlimited
        }
        limits = plan_limits.get(new_plan, {})
        sub.plan = new_plan
        sub.product_limit = limits.get('product_limit', 50)
        sub.user_limit = limits.get('user_limit', 5)
        sub.location_limit = limits.get('location_limit', 2)
        sub.status = Subscription.STATUS_ACTIVE
        sub.save()

        # Update tenant plan
        tenant.plan = new_plan
        tenant.save()

        return success_response(
            data=SubscriptionDetailSerializer(sub).data,
            message=f'Plan upgraded to {new_plan}.',
        )


class SuperAdminTenantsView(APIView):
    """
    GET /api/superadmin/tenants/
    Lists all tenants. Only accessible by super-admin.
    """
    permission_classes = [IsAuthenticated, IsSuperAdmin]

    def get(self, request):
        tenants = Tenant.objects.all().order_by('-created_at')
        data = []
        for t in tenants:
            tenant_data = TenantDetailSerializer(t).data
            try:
                tenant_data['subscription'] = SubscriptionDetailSerializer(t.subscription).data
            except Subscription.DoesNotExist:
                tenant_data['subscription'] = None
            data.append(tenant_data)
        return success_response(data={'results': data, 'count': len(data)})
