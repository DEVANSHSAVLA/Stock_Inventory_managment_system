from django.contrib import admin
from .models import DailyLedger, StockEntry, StockTransfer


@admin.register(DailyLedger)
class DailyLedgerAdmin(admin.ModelAdmin):
    list_display = ('variant', 'location', 'date', 'opening_stock', 'closing_stock', 'is_locked')
    list_filter = ('date', 'is_locked', 'location')
    search_fields = ('variant__sku', 'variant__product__name')
    ordering = ('-date',)


@admin.register(StockEntry)
class StockEntryAdmin(admin.ModelAdmin):
    list_display = ('id', 'variant', 'location', 'entry_type', 'quantity', 'is_approved', 'logged_by', 'timestamp')
    list_filter = ('entry_type', 'is_approved', 'location')
    search_fields = ('variant__sku', 'reference_number', 'batch_number')
    ordering = ('-timestamp',)


@admin.register(StockTransfer)
class StockTransferAdmin(admin.ModelAdmin):
    list_display = ('id', 'variant', 'from_location', 'to_location', 'quantity', 'transferred_by', 'timestamp')
    list_filter = ('from_location', 'to_location')
    search_fields = ('variant__sku',)
    ordering = ('-timestamp',)
