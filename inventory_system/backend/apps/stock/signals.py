from django.db.models.signals import post_save
from django.dispatch import receiver
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from django.db import connection
from .stock_engine import invalidate_stock_cache
import logging

logger = logging.getLogger(__name__)


@receiver(post_save, sender='stock.StockEntry')
def on_stock_entry_save(sender, instance, created, **kwargs):
    try:
        invalidate_stock_cache(instance.variant_id, instance.location_id)
        if instance.is_approved:
            channel_layer = get_channel_layer()
            if channel_layer:
                from .stock_engine import get_live_stock
                from django.utils import timezone
                live = get_live_stock(instance.variant_id, instance.location_id, timezone.now().date())
                logged_by_name = ''
                if instance.logged_by:
                    logged_by_name = instance.logged_by.get_full_name() or instance.logged_by.email
                
                schema = getattr(connection, 'schema_name', 'public')
                payload = {
                    'type': 'stock_update',
                    'schema_name': schema,
                    'variant_id': instance.variant_id,
                    'location_id': instance.location_id,
                    'live_stock': float(live),
                    'entry_type': instance.entry_type,
                    'qty': float(instance.quantity),
                    'logged_by': logged_by_name,
                    'timestamp': instance.timestamp.isoformat(),
                }
                # Broadcast to tenant-scoped group
                group_name = f'{schema}_stock_updates'
                async_to_sync(channel_layer.group_send)(
                    group_name,
                    {'type': 'stock_update', 'payload': payload}
                )
    except Exception as e:
        logger.error(f'WebSocket broadcast error: {e}')
