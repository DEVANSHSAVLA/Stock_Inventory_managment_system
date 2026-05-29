import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.db import connection
from apps.tenants.models import Tenant
from apps.locations.models import Location
from apps.products.models import Product, Variant

demo_tenant = Tenant.objects.get(schema_name='demo')
connection.set_tenant(demo_tenant)

# Create a Location
loc, _ = Location.objects.get_or_create(
    name="Main Warehouse",
    defaults={"address": "123 Storage St", "is_active": True}
)
loc2, _ = Location.objects.get_or_create(
    name="Storefront",
    defaults={"address": "456 Retail Ave", "is_active": True}
)

# Create a Product and Variant
prod, _ = Product.objects.get_or_create(
    name="Premium T-Shirt",
    defaults={"category": "Apparel"}
)
var, _ = Variant.objects.get_or_create(
    product=prod,
    sku="TSHIRT-L-BLK",
    defaults={"size": "Large", "flavour": "Black"}
)

# Add some stock
from apps.stock.models import StockEntry
StockEntry.objects.get_or_create(
    variant=var,
    location=loc,
    defaults={"quantity": 100, "entry_type": "IN", "note": "Initial Stock"}
)

print("Successfully seeded locations and stock for the demo tenant!")
