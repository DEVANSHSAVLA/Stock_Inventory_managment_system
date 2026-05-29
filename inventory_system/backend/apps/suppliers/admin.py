from django.contrib import admin
from .models import Supplier, PurchaseOrder


@admin.register(Supplier)
class SupplierAdmin(admin.ModelAdmin):
    list_display = ('name', 'contact_person', 'phone', 'email', 'is_active')
    list_filter = ('is_active',)
    search_fields = ('name', 'contact_person', 'email', 'phone')
    filter_horizontal = ('products_supplied',)


@admin.register(PurchaseOrder)
class PurchaseOrderAdmin(admin.ModelAdmin):
    list_display = ('id', 'supplier', 'status', 'created_by', 'expected_date', 'created_at')
    list_filter = ('status',)
    search_fields = ('supplier__name', 'notes')
    ordering = ('-created_at',)
