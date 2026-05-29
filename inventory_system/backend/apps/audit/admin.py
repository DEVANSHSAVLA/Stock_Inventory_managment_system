from django.contrib import admin
from .models import AuditLog


@admin.register(AuditLog)
class AuditLogAdmin(admin.ModelAdmin):
    list_display = ('action', 'model_name', 'object_id', 'user', 'timestamp', 'ip_address')
    list_filter = ('action', 'model_name')
    search_fields = ('model_name', 'object_id', 'user__email')
    ordering = ('-timestamp',)
    readonly_fields = ('action', 'model_name', 'object_id', 'old_value', 'new_value', 'timestamp', 'ip_address', 'user')
