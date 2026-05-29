from django.db import models
from django_tenants.models import TenantMixin, DomainMixin


class Tenant(TenantMixin):
    """
    Each company/organization gets its own Tenant record.
    TenantMixin provides: schema_name (unique), auto_create_schema, auto_drop_schema.
    """
    PLAN_FREE = 'FREE'
    PLAN_PRO = 'PRO'
    PLAN_ENTERPRISE = 'ENTERPRISE'
    PLAN_CHOICES = [
        (PLAN_FREE, 'Free'),
        (PLAN_PRO, 'Pro'),
        (PLAN_ENTERPRISE, 'Enterprise'),
    ]

    company_name = models.CharField(max_length=200)
    subdomain = models.CharField(max_length=63, unique=True,
                                 help_text='Unique subdomain for this tenant (e.g. acme)')
    owner_email = models.EmailField(help_text='Email of the tenant admin who signed up')
    plan = models.CharField(max_length=20, choices=PLAN_CHOICES, default=PLAN_FREE)
    is_active = models.BooleanField(default=True)
    logo = models.ImageField(upload_to='tenant_logos/', null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    # django-tenants settings
    auto_create_schema = True
    auto_drop_schema = True

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.company_name} ({self.schema_name})'


class Domain(DomainMixin):
    """
    Maps domains/subdomains to tenants.
    DomainMixin provides: domain, tenant (FK), is_primary.
    """
    pass


class Subscription(models.Model):
    """
    Tracks the subscription tier and resource limits for each tenant.
    Limits are enforced by PlanLimitMiddleware (Phase 6).
    """
    PLAN_FREE = 'FREE'
    PLAN_PRO = 'PRO'
    PLAN_ENTERPRISE = 'ENTERPRISE'
    PLAN_CHOICES = [
        (PLAN_FREE, 'Free'),
        (PLAN_PRO, 'Pro'),
        (PLAN_ENTERPRISE, 'Enterprise'),
    ]

    STATUS_ACTIVE = 'ACTIVE'
    STATUS_TRIAL = 'TRIAL'
    STATUS_CANCELLED = 'CANCELLED'
    STATUS_EXPIRED = 'EXPIRED'
    STATUS_CHOICES = [
        (STATUS_ACTIVE, 'Active'),
        (STATUS_TRIAL, 'Trial'),
        (STATUS_CANCELLED, 'Cancelled'),
        (STATUS_EXPIRED, 'Expired'),
    ]

    # Plan limits per tier
    PLAN_LIMITS = {
        PLAN_FREE: {'products': 50, 'users': 5, 'locations': 2},
        PLAN_PRO: {'products': 500, 'users': 200, 'locations': 10},
        PLAN_ENTERPRISE: {'products': 99999, 'users': 99999, 'locations': 99999},
    }

    tenant = models.OneToOneField(Tenant, on_delete=models.CASCADE, related_name='subscription')
    plan = models.CharField(max_length=20, choices=PLAN_CHOICES, default=PLAN_FREE)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_TRIAL)

    # Resource limits
    product_limit = models.IntegerField(default=50)
    user_limit = models.IntegerField(default=5)
    location_limit = models.IntegerField(default=2)

    # Stripe integration (Phase 6 — stubs for now)
    stripe_customer_id = models.CharField(max_length=100, blank=True)
    stripe_subscription_id = models.CharField(max_length=100, blank=True)

    # Dates
    trial_ends_at = models.DateTimeField(null=True, blank=True)
    current_period_end = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f'{self.tenant.company_name} — {self.plan} ({self.status})'

    def set_plan_limits(self):
        """Apply default limits based on the selected plan."""
        limits = self.PLAN_LIMITS.get(self.plan, self.PLAN_LIMITS[self.PLAN_FREE])
        self.product_limit = limits['products']
        self.user_limit = limits['users']
        self.location_limit = limits['locations']

    def save(self, *args, **kwargs):
        # Auto-set limits when plan changes
        if self.pk:
            try:
                old = Subscription.objects.get(pk=self.pk)
                if old.plan != self.plan:
                    self.set_plan_limits()
            except Subscription.DoesNotExist:
                self.set_plan_limits()
        else:
            self.set_plan_limits()
        super().save(*args, **kwargs)
