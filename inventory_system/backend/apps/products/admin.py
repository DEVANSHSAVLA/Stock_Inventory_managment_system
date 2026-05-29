from django.contrib import admin
from .models import Product, Variant


@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = ('name', 'category', 'unit_of_measure', 'is_active', 'created_at')
    list_filter = ('category', 'is_active')
    search_fields = ('name', 'category', 'description')
    ordering = ('name',)


@admin.register(Variant)
class VariantAdmin(admin.ModelAdmin):
    list_display = ('sku', 'product', 'size', 'flavour', 'reorder_point', 'is_active')
    list_filter = ('is_active', 'product__category')
    search_fields = ('sku', 'barcode', 'product__name', 'size', 'flavour')
    ordering = ('product__name', 'size')
