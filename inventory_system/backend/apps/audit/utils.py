from .models import AuditLog


def log_audit(request, action, model_name, object_id, old_value=None, new_value=None):
    user = request.user if request and hasattr(request, 'user') and request.user.is_authenticated else None
    ip = None
    if request:
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        ip = x_forwarded_for.split(',')[0] if x_forwarded_for else request.META.get('REMOTE_ADDR')
    AuditLog.objects.create(
        user=user,
        action=action,
        model_name=model_name,
        object_id=str(object_id),
        old_value=old_value,
        new_value=new_value,
        ip_address=ip,
    )
