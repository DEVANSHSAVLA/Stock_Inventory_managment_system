import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from apps.tenants.models import Tenant, Domain, Subscription
from apps.auth_app.models import User

# Create public tenant if it doesn't exist (django-tenants requires a public tenant)
public_tenant, created = Tenant.objects.get_or_create(
    schema_name='public',
    defaults={
        'company_name': 'Public',
        'subdomain': 'public',
        'owner_email': 'admin@public.com',
    }
)
if created:
    Domain.objects.get_or_create(
        domain='localhost',
        tenant=public_tenant,
        is_primary=True
    )
    # Also add the local IP domain to the public tenant so it routes to public schema if accessed directly via IP
    Domain.objects.get_or_create(
        domain='192.168.31.58',
        tenant=public_tenant,
        is_primary=False
    )
    print("Created public tenant.")

# Create demo tenant
demo_tenant, created = Tenant.objects.get_or_create(
    schema_name='demo',
    defaults={
        'company_name': 'Demo Company',
        'subdomain': 'demo',
        'owner_email': 'admin@demo.com',
    }
)

Domain.objects.get_or_create(
    domain='demo.localhost',
    tenant=demo_tenant,
    is_primary=True
)

# Create subscription
Subscription.objects.get_or_create(
    tenant=demo_tenant,
    defaults={'plan': 'PRO', 'status': 'ACTIVE'}
)

# Create superusers in the demo schema
from django.db import connection
connection.set_schema(demo_tenant.schema_name)

# Clean up any conflicting users to ensure fresh creation
User.objects.filter(username='admin').delete()
User.objects.filter(email='admin@inventory.local').delete()
User.objects.filter(email='admin@demo.com').delete()

User.objects.filter(username='manager1').delete()
User.objects.filter(email='manager1@inventory.local').delete()

# Create fresh admin user
user = User.objects.create_superuser(
    email='admin@inventory.local',
    username='admin',
    password='Admin@1234',
    role='ADMIN'
)
print("Created admin user: admin@inventory.local / Admin@1234")

# Create fresh manager user
user = User.objects.create_superuser(
    email='manager1@inventory.local',
    username='manager1',
    password='Manager@1234',
    role='MANAGER'
)
print("Created manager user: manager1@inventory.local / Manager@1234")
