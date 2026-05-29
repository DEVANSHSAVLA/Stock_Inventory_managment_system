from django.db import models
from django.utils import timezone
from datetime import date


class DailyLedger(models.Model):
    variant = models.ForeignKey('products.Variant', on_delete=models.CASCADE, related_name='ledgers')
    location = models.ForeignKey('locations.Location', on_delete=models.CASCADE, related_name='ledgers')
    date = models.DateField()
    opening_stock = models.DecimalField(max_digits=12, decimal_places=3, default=0)
    closing_stock = models.DecimalField(max_digits=12, decimal_places=3, null=True, blank=True)
    is_locked = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('variant', 'location', 'date')

    def __str__(self):
        return f'{self.variant} @ {self.location} on {self.date}'


class StockEntry(models.Model):
    TYPE_IN = 'IN'
    TYPE_OUT = 'OUT'
    TYPE_CHOICES = [
        (TYPE_IN, 'Incoming'),
        (TYPE_OUT, 'Outgoing'),
    ]

    variant = models.ForeignKey('products.Variant', on_delete=models.CASCADE, related_name='stock_entries')
    location = models.ForeignKey('locations.Location', on_delete=models.CASCADE, related_name='stock_entries')
    entry_type = models.CharField(max_length=3, choices=TYPE_CHOICES)
    quantity = models.DecimalField(max_digits=12, decimal_places=3)
    cases = models.DecimalField(max_digits=10, decimal_places=3, null=True, blank=True)
    purchase_price = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    entry_date = models.DateField(null=True, blank=True)
    reference_number = models.CharField(max_length=100, blank=True)
    batch_number = models.CharField(max_length=100, blank=True, null=True)
    expiry_date = models.DateField(null=True, blank=True)
    supplier = models.ForeignKey('suppliers.Supplier', on_delete=models.SET_NULL, null=True, blank=True)
    note = models.TextField(blank=True)
    logged_by = models.ForeignKey('auth_app.User', on_delete=models.SET_NULL, null=True, related_name='stock_entries')
    approved_by = models.ForeignKey('auth_app.User', on_delete=models.SET_NULL, null=True, blank=True, related_name='approved_entries')
    is_approved = models.BooleanField(default=False)
    timestamp = models.DateTimeField(default=timezone.now)
    created_at = models.DateTimeField(auto_now_add=True)

    def save(self, *args, **kwargs):
        # Auto-convert cases to quantity using variant.case_quantity
        if self.cases and self.variant and self.variant.case_quantity:
            self.quantity = self.cases * self.variant.case_quantity
        if not self.entry_date:
            self.entry_date = date.today()
        super().save(*args, **kwargs)

    def __str__(self):
        return f'{self.entry_type} {self.quantity} of {self.variant} @ {self.location}'


class StockTransfer(models.Model):
    from_location = models.ForeignKey('locations.Location', on_delete=models.CASCADE, related_name='transfers_out')
    to_location = models.ForeignKey('locations.Location', on_delete=models.CASCADE, related_name='transfers_in')
    variant = models.ForeignKey('products.Variant', on_delete=models.CASCADE, related_name='transfers')
    quantity = models.DecimalField(max_digits=12, decimal_places=3)
    transferred_by = models.ForeignKey('auth_app.User', on_delete=models.SET_NULL, null=True, related_name='transfers')
    timestamp = models.DateTimeField(default=timezone.now)
    note = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f'Transfer {self.quantity} of {self.variant} from {self.from_location} to {self.to_location}'


class Order(models.Model):
    STATUS_PENDING = 'PENDING'
    STATUS_CONFIRMED = 'CONFIRMED'
    STATUS_DISPATCHED = 'DISPATCHED'
    STATUS_IN_TRANSIT = 'IN_TRANSIT'
    STATUS_DELIVERED = 'DELIVERED'
    STATUS_CANCELLED = 'CANCELLED'
    STATUS_CHOICES = [
        (STATUS_PENDING, 'Pending'),
        (STATUS_CONFIRMED, 'Confirmed'),
        (STATUS_DISPATCHED, 'Dispatched'),
        (STATUS_IN_TRANSIT, 'In Transit'),
        (STATUS_DELIVERED, 'Delivered'),
        (STATUS_CANCELLED, 'Cancelled'),
    ]

    order_number = models.CharField(max_length=30, unique=True, editable=False)
    customer_name = models.CharField(max_length=200)
    customer_phone = models.CharField(max_length=20, blank=True)
    customer_address = models.TextField(blank=True)
    date = models.DateField(default=timezone.now)
    transport = models.CharField(max_length=200, null=True, blank=True)
    transport_carrier = models.CharField(max_length=100, blank=True)
    transport_vehicle = models.CharField(max_length=100, blank=True)
    transport_driver = models.CharField(max_length=100, blank=True)
    warehouse = models.ForeignKey('locations.Location', on_delete=models.SET_NULL, null=True, blank=True, related_name='orders')
    is_delivered_at_booking = models.BooleanField(default=False)
    notes = models.TextField(blank=True)
    status = models.CharField(max_length=15, choices=STATUS_CHOICES, default=STATUS_PENDING)
    created_by = models.ForeignKey('auth_app.User', on_delete=models.SET_NULL, null=True, related_name='orders_created')
    approved_by = models.ForeignKey('auth_app.User', on_delete=models.SET_NULL, null=True, blank=True, related_name='orders_approved')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def save(self, *args, **kwargs):
        if not self.order_number:
            from django.utils.crypto import get_random_string
            self.order_number = f'ORD-{timezone.now().strftime("%Y%m%d")}-{get_random_string(5).upper()}'
        super().save(*args, **kwargs)

    def __str__(self):
        return f'{self.order_number} — {self.customer_name} ({self.status})'


class OrderItem(models.Model):
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='items')
    variant = models.ForeignKey('products.Variant', on_delete=models.CASCADE, related_name='order_items')
    location = models.ForeignKey('locations.Location', on_delete=models.CASCADE)
    quantity = models.DecimalField(max_digits=12, decimal_places=3)
    cases = models.IntegerField(default=0)
    unit_price = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    subtotal = models.DecimalField(max_digits=12, decimal_places=2, default=0)

    def save(self, *args, **kwargs):
        # Auto-convert cases to quantity if cases is provided
        if self.cases and self.cases > 0 and self.variant and self.variant.case_quantity:
            self.quantity = self.cases * self.variant.case_quantity
        self.subtotal = self.quantity * self.unit_price
        super().save(*args, **kwargs)

    def __str__(self):
        return f'{self.variant} x {self.quantity} in {self.order.order_number}'


class StockReservation(models.Model):
    variant = models.ForeignKey('products.Variant', on_delete=models.CASCADE, related_name='reservations')
    location = models.ForeignKey('locations.Location', on_delete=models.CASCADE, related_name='reservations')
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='reservations')
    quantity = models.DecimalField(max_digits=12, decimal_places=3)
    reserved_at = models.DateTimeField(auto_now_add=True)
    released_at = models.DateTimeField(null=True, blank=True)

    @property
    def is_active(self):
        return self.released_at is None

    def __str__(self):
        status = 'ACTIVE' if self.is_active else 'RELEASED'
        return f'Reservation {self.quantity} of {self.variant} for {self.order.order_number} [{status}]'
