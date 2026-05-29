from rest_framework import serializers
from .models import Tenant, Subscription


class TenantSignupSerializer(serializers.Serializer):
    """Validates company signup data."""
    company_name = serializers.CharField(max_length=200)
    subdomain = serializers.SlugField(max_length=63)
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, min_length=8)
    first_name = serializers.CharField(max_length=30, required=False, default='')
    last_name = serializers.CharField(max_length=30, required=False, default='')

    def validate_subdomain(self, value):
        value = value.lower().strip()
        reserved = ['www', 'api', 'admin', 'app', 'mail', 'ftp', 'public', 'static', 'media']
        if value in reserved:
            raise serializers.ValidationError('This subdomain is reserved.')
        if Tenant.objects.filter(subdomain=value).exists():
            raise serializers.ValidationError('This subdomain is already taken.')
        return value

    def validate_email(self, value):
        from apps.auth_app.models import User
        # Check across all schemas — email must be globally unique for owner
        if Tenant.objects.filter(owner_email=value).exists():
            raise serializers.ValidationError('An account with this email already exists.')
        return value


class TenantLoginSerializer(serializers.Serializer):
    """Validates tenant-aware login: subdomain + email + password."""
    subdomain = serializers.CharField(max_length=63, required=False, allow_blank=True)
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)


class TenantDetailSerializer(serializers.ModelSerializer):
    """Read/update serializer for tenant info (admin only)."""
    plan = serializers.CharField(source='subscription.plan', read_only=True)
    status = serializers.CharField(source='subscription.status', read_only=True)

    class Meta:
        model = Tenant
        fields = ('schema_name', 'company_name', 'subdomain', 'owner_email',
                  'plan', 'status', 'is_active', 'created_at')
        read_only_fields = ('schema_name', 'owner_email', 'created_at')


class SubscriptionDetailSerializer(serializers.ModelSerializer):
    """Read serializer for subscription info — used in settings/billing screen."""
    company_name = serializers.CharField(source='tenant.company_name', read_only=True)

    class Meta:
        model = Subscription
        fields = ('plan', 'status', 'product_limit', 'user_limit', 'location_limit',
                  'trial_ends_at', 'current_period_end', 'company_name')
        read_only_fields = fields
