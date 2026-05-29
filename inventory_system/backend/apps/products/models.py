from django.db import models
from decimal import Decimal


class Product(models.Model):
    name = models.CharField(max_length=300)
    category = models.CharField(max_length=100, blank=True, default='')
    unit_of_measure = models.CharField(max_length=50, default='units')
    description = models.TextField(blank=True)
    drive_image_url = models.URLField(max_length=500, null=True, blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.name


class Variant(models.Model):
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='variants')
    size = models.CharField(max_length=50, blank=True)
    flavour = models.CharField(max_length=100, blank=True)
    sku = models.CharField(max_length=100, unique=True, blank=True)
    barcode = models.CharField(max_length=100, blank=True, db_index=True)
    reorder_point = models.PositiveIntegerField(default=10)
    reorder_qty = models.PositiveIntegerField(default=50)
    erp_price = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    mrp = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    weight = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    length = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    width = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    height = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    case_quantity = models.PositiveIntegerField(default=144)
    case_weight = models.DecimalField(max_digits=6, decimal_places=2, null=True, blank=True)
    case_dimension = models.CharField(max_length=100, null=True, blank=True)
    drive_image_url = models.URLField(max_length=500, null=True, blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    @property
    def selling_price(self):
        return round(self.erp_price * Decimal('1.12'), 2) if self.erp_price else None

    def save(self, *args, **kwargs):
        if not self.sku:
            parts = ['PROD', self.product.name[:4].upper()]
            if self.size:
                parts.append(self.size.upper())
            if self.flavour:
                parts.append(self.flavour[:4].upper())
            base_sku = '-'.join(parts)
            sku = base_sku
            counter = 1
            while Variant.objects.filter(sku=sku).exclude(pk=self.pk).exists():
                sku = f'{base_sku}-{counter}'
                counter += 1
            self.sku = sku
        super().save(*args, **kwargs)

    def __str__(self):
        return f'{self.product.name} - {self.size} {self.flavour} ({self.sku})'
