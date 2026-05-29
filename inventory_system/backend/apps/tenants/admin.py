from django.contrib import admin
from .models import Tenant, Domain, Subscription


@admin.register(Tenant)
class TenantAdmin(admin.ModelAdmin):
    list_display = ('company_name', 'schema_name', 'subdomain', 'plan', 'is_active', 'created_at')
    list_filter = ('plan', 'is_active')
    search_fields = ('company_name', 'subdomain', 'owner_email')
    readonly_fields = ('schema_name', 'created_at', 'updated_at')


@admin.register(Domain)
class DomainAdmin(admin.ModelAdmin):
    list_display = ('domain', 'tenant', 'is_primary')
    list_filter = ('is_primary',)
    search_fields = ('domain',)


@admin.register(Subscription)
class SubscriptionAdmin(admin.ModelAdmin):
    list_display = ('tenant', 'plan', 'status', 'product_limit', 'user_limit', 'location_limit', 'trial_ends_at')
    list_filter = ('plan', 'status')
    search_fields = ('tenant__company_name',)
    readonly_fields = ('created_at', 'updated_at')
