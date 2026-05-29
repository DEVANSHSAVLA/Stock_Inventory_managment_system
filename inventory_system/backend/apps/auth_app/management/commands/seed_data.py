from django.core.management.base import BaseCommand
from django.utils import timezone
from datetime import timedelta, date
import random


class Command(BaseCommand):
    help = 'Seed database with realistic demo data'

    def handle(self, *args, **options):
        self.stdout.write('Seeding database...')
        self._create_users()
        self._create_locations()
        self._create_products()
        self._create_suppliers()
        self._create_stock_entries()
        self.stdout.write(self.style.SUCCESS('Seed data created successfully!'))
        self.stdout.write('\nDefault credentials:')
        self.stdout.write('  Admin:   admin@inventory.local / Admin@1234')
        self.stdout.write('  Manager: manager1@inventory.local / Manager@1234')
        self.stdout.write('  Staff:   staff1@inventory.local / Staff@1234')

    def _create_users(self):
        from apps.auth_app.models import User
        users_data = [
            {'email': 'admin@inventory.local', 'username': 'admin', 'first_name': 'Super', 'last_name': 'Admin', 'role': 'ADMIN', 'password': 'Admin@1234'},
            {'email': 'manager1@inventory.local', 'username': 'manager1', 'first_name': 'Alice', 'last_name': 'Manager', 'role': 'MANAGER', 'password': 'Manager@1234'},
            {'email': 'manager2@inventory.local', 'username': 'manager2', 'first_name': 'Bob', 'last_name': 'Manager', 'role': 'MANAGER', 'password': 'Manager@1234'},
            {'email': 'staff1@inventory.local', 'username': 'staff1', 'first_name': 'Charlie', 'last_name': 'Staff', 'role': 'STAFF', 'password': 'Staff@1234'},
            {'email': 'staff2@inventory.local', 'username': 'staff2', 'first_name': 'Diana', 'last_name': 'Staff', 'role': 'STAFF', 'password': 'Staff@1234'},
            {'email': 'staff3@inventory.local', 'username': 'staff3', 'first_name': 'Eve', 'last_name': 'Staff', 'role': 'STAFF', 'password': 'Staff@1234'},
            {'email': 'staff4@inventory.local', 'username': 'staff4', 'first_name': 'Frank', 'last_name': 'Staff', 'role': 'STAFF', 'password': 'Staff@1234'},
            {'email': 'staff5@inventory.local', 'username': 'staff5', 'first_name': 'Grace', 'last_name': 'Staff', 'role': 'STAFF', 'password': 'Staff@1234'},
        ]
        for ud in users_data:
            if not User.objects.filter(email=ud['email']).exists() and not User.objects.filter(username=ud['username']).exists():
                pw = ud.pop('password')
                u = User(**ud)
                u.set_password(pw)
                u.save()
        self.stdout.write(f'  Created {len(users_data)} users')

    def _create_locations(self):
        from apps.locations.models import Location
        locs = [
            {'name': 'Main Warehouse', 'type': 'WAREHOUSE', 'address': '123 Industrial Area, Mumbai'},
            {'name': 'Retail Branch - North', 'type': 'BRANCH', 'address': '45 Market Street, Delhi'},
            {'name': 'Retail Branch - South', 'type': 'BRANCH', 'address': '78 Commerce Road, Chennai'},
        ]
        self.locations = []
        for l in locs:
            loc, _ = Location.objects.get_or_create(name=l['name'], defaults=l)
            self.locations.append(loc)
        self.stdout.write(f'  Created {len(locs)} locations')

    def _create_products(self):
        from apps.products.models import Product, Variant
        categories = ['Beverages', 'Snacks', 'Dairy', 'Grains', 'Personal Care',
                      'Cleaning', 'Frozen', 'Bakery', 'Condiments', 'Health']
        product_names = [
            ('Orange Juice', 'Beverages'), ('Apple Juice', 'Beverages'), ('Mineral Water', 'Beverages'),
            ('Cola Drink', 'Beverages'), ('Green Tea', 'Beverages'),
            ('Potato Chips', 'Snacks'), ('Corn Chips', 'Snacks'), ('Popcorn', 'Snacks'),
            ('Peanut Butter Cookies', 'Snacks'), ('Trail Mix', 'Snacks'),
            ('Full Cream Milk', 'Dairy'), ('Skimmed Milk', 'Dairy'), ('Cheddar Cheese', 'Dairy'),
            ('Greek Yogurt', 'Dairy'), ('Butter Unsalted', 'Dairy'),
            ('Basmati Rice', 'Grains'), ('Brown Rice', 'Grains'), ('Whole Wheat Flour', 'Grains'),
            ('Oats Regular', 'Grains'), ('Quinoa', 'Grains'),
            ('Shampoo Moisturizing', 'Personal Care'), ('Body Wash', 'Personal Care'),
            ('Toothpaste Whitening', 'Personal Care'), ('Hand Cream', 'Personal Care'),
            ('Face Wash Gel', 'Personal Care'),
            ('Dish Soap', 'Cleaning'), ('Floor Cleaner', 'Cleaning'),
            ('Laundry Detergent', 'Cleaning'), ('Glass Cleaner', 'Cleaning'), ('Toilet Cleaner', 'Cleaning'),
            ('Frozen Peas', 'Frozen'), ('Frozen Corn', 'Frozen'),
            ('White Bread', 'Bakery'), ('Multigrain Bread', 'Bakery'),
            ('Tomato Ketchup', 'Condiments'), ('Soy Sauce', 'Condiments'),
            ('Vitamin C Tablets', 'Health'), ('Protein Powder', 'Health'),
            ('Multivitamin', 'Health'), ('Fish Oil', 'Health'),
            ('Energy Drink', 'Beverages'), ('Sparkling Water', 'Beverages'),
            ('Dark Chocolate', 'Snacks'), ('Granola Bar', 'Snacks'),
            ('Coconut Milk', 'Dairy'), ('Almond Milk', 'Dairy'),
            ('Pasta Penne', 'Grains'), ('Spaghetti', 'Grains'),
            ('Conditioner', 'Personal Care'), ('Sunscreen SPF50', 'Personal Care'),
        ]
        sizes = ['S', 'M', 'L']
        flavours = ['Original', 'Classic', 'Premium']
        self.variants = []
        for pname, cat in product_names:
            p, _ = Product.objects.get_or_create(name=pname, defaults={
                'category': cat, 'unit_of_measure': 'units'
            })
            for size in sizes:
                for flavour in flavours:
                    v, created = Variant.objects.get_or_create(
                        product=p, size=size, flavour=flavour,
                        defaults={
                            'reorder_point': random.randint(5, 20),
                            'reorder_qty': random.randint(50, 200),
                        }
                    )
                    self.variants.append(v)
        self.stdout.write(f'  Created {len(product_names)} products with variants')

    def _create_suppliers(self):
        from apps.suppliers.models import Supplier
        suppliers_data = [
            {'name': 'Global Foods Ltd', 'contact_person': 'Rajesh Kumar', 'phone': '9876543210', 'email': 'rajesh@globalfoods.com'},
            {'name': 'Fresh Supply Co', 'contact_person': 'Priya Patel', 'phone': '9876543211', 'email': 'priya@freshsupply.com'},
            {'name': 'Metro Distributors', 'contact_person': 'Amit Shah', 'phone': '9876543212', 'email': 'amit@metro.com'},
            {'name': 'National Traders', 'contact_person': 'Sunita Joshi', 'phone': '9876543213', 'email': 'sunita@nationaltraders.com'},
            {'name': 'Prime Wholesale', 'contact_person': 'Vikram Singh', 'phone': '9876543214', 'email': 'vikram@primewholesale.com'},
        ]
        self.suppliers = []
        for sd in suppliers_data:
            s, _ = Supplier.objects.get_or_create(name=sd['name'], defaults=sd)
            # Assign random variants
            sample_variants = random.sample(self.variants, min(30, len(self.variants)))
            s.products_supplied.set(sample_variants)
            self.suppliers.append(s)
        self.stdout.write(f'  Created {len(suppliers_data)} suppliers')

    def _create_stock_entries(self):
        from apps.stock.models import StockEntry, DailyLedger
        from apps.auth_app.models import User

        staff_users = list(User.objects.filter(role='STAFF'))
        manager_users = list(User.objects.filter(role='MANAGER'))
        approver = manager_users[0] if manager_users else User.objects.filter(role='ADMIN').first()

        today = timezone.now().date()
        # Create 30 days of entries
        for days_ago in range(30, 0, -1):
            entry_date = today - timedelta(days=days_ago)
            # Create initial ledger entries
            sample_variants = random.sample(self.variants, min(20, len(self.variants)))
            for v in sample_variants:
                loc = random.choice(self.locations)
                ledger, _ = DailyLedger.objects.get_or_create(
                    variant=v, location=loc, date=entry_date,
                    defaults={'opening_stock': random.randint(20, 200)}
                )
                # Create IN entries
                num_in = random.randint(1, 3)
                for _ in range(num_in):
                    qty = random.randint(10, 100)
                    StockEntry.objects.create(
                        variant=v, location=loc, entry_type='IN',
                        quantity=qty,
                        reference_number=f'REF-{random.randint(10000, 99999)}',
                        supplier=random.choice(self.suppliers),
                        note='Daily stock intake',
                        logged_by=random.choice(staff_users) if staff_users else approver,
                        is_approved=True,
                        approved_by=approver,
                        timestamp=timezone.make_aware(
                            timezone.datetime(entry_date.year, entry_date.month, entry_date.day,
                                             random.randint(8, 11), random.randint(0, 59))
                        ),
                    )
                # Create OUT entries
                num_out = random.randint(1, 4)
                for _ in range(num_out):
                    qty = random.randint(5, 50)
                    StockEntry.objects.create(
                        variant=v, location=loc, entry_type='OUT',
                        quantity=qty,
                        reference_number=f'OUT-{random.randint(10000, 99999)}',
                        note='Daily dispatch',
                        logged_by=random.choice(staff_users) if staff_users else approver,
                        is_approved=True,
                        approved_by=approver,
                        timestamp=timezone.make_aware(
                            timezone.datetime(entry_date.year, entry_date.month, entry_date.day,
                                             random.randint(12, 17), random.randint(0, 59))
                        ),
                    )
        self.stdout.write(f'  Created 30 days of stock entries')
