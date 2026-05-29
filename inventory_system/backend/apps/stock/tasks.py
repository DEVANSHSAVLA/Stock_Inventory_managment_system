from celery import shared_task
from django.utils import timezone
from django.core.mail import send_mail
from django.conf import settings
from decimal import Decimal
import logging
from apps.tenants.models import Tenant
from django_tenants.utils import schema_context

logger = logging.getLogger(__name__)


@shared_task(bind=True, max_retries=3)
def midnight_rollover(self):
    from .models import DailyLedger
    from apps.products.models import Variant
    from apps.locations.models import Location
    from .stock_engine import bulk_get_live_stock
    from datetime import timedelta

    today = timezone.now().date()
    yesterday = today - timedelta(days=1)

    try:
        tenants = Tenant.objects.filter(is_active=True).exclude(schema_name='public')
        for tenant in tenants:
            with schema_context(tenant.schema_name):
                variants = list(Variant.objects.filter(is_active=True))
                locations = Location.objects.filter(is_active=True)
                if not variants or not locations:
                    continue
                v_ids = [v.id for v in variants]
                for loc in locations:
                    live_stock_map = bulk_get_live_stock(v_ids, loc.id, yesterday)
                    for v in variants:
                        live = live_stock_map.get(v.id, Decimal('0'))
                        # Lock yesterday
                        ledger, _ = DailyLedger.objects.get_or_create(
                            variant=v, location=loc, date=yesterday,
                            defaults={'opening_stock': Decimal('0')}
                        )
                        if not ledger.is_locked:
                            ledger.closing_stock = live
                            ledger.is_locked = True
                            ledger.save()
                        # Create today
                        DailyLedger.objects.get_or_create(
                            variant=v, location=loc, date=today,
                            defaults={'opening_stock': live}
                        )
                logger.info(f'Midnight rollover completed for tenant {tenant.schema_name} on {today}')
    except Exception as e:
        logger.error(f'Midnight rollover failed: {e}')
        raise self.retry(exc=e, countdown=60 * (2 ** self.request.retries))


@shared_task(bind=True, max_retries=3)
def check_low_stock(self):
    from apps.products.models import Variant
    from apps.notifications.models import Notification
    from apps.auth_app.models import User
    from .stock_engine import bulk_get_live_stock

    today = timezone.now().date()

    try:
        tenants = Tenant.objects.filter(is_active=True).exclude(schema_name='public')
        for tenant in tenants:
            with schema_context(tenant.schema_name):
                admin_manager_users = User.objects.filter(role__in=['ADMIN', 'MANAGER'], is_active=True)
                if not admin_manager_users:
                    continue
                variants = list(Variant.objects.filter(is_active=True).select_related('product'))
                if not variants:
                    continue
                v_ids = [v.id for v in variants]
                live_stock_map = bulk_get_live_stock(v_ids, None, today)

                for v in variants:
                    live = float(live_stock_map.get(v.id, Decimal('0')))
                    if live <= v.reorder_point:
                        msg = f'Low stock alert: {v.product.name} {v.size} {v.flavour} (SKU: {v.sku}) - Current: {live}, Reorder: {v.reorder_point}'
                        for user in admin_manager_users:
                            # Avoid duplicate notifications within 2 hours
                            recent = Notification.objects.filter(
                                user=user,
                                type='LOW_STOCK',
                                message__contains=v.sku,
                                created_at__gte=timezone.now() - timezone.timedelta(hours=2)
                            ).exists()
                            if not recent:
                                Notification.objects.create(user=user, message=msg, type='LOW_STOCK')
                logger.info(f'Low stock check completed for tenant {tenant.schema_name}.')
    except Exception as e:
        logger.error(f'Low stock check failed: {e}')
        raise self.retry(exc=e, countdown=60 * (2 ** self.request.retries))


@shared_task(bind=True, max_retries=3)
def check_expiring_batches(self):
    from .models import StockEntry
    from apps.notifications.models import Notification
    from apps.auth_app.models import User
    from datetime import timedelta

    cutoff = timezone.now().date() + timedelta(days=30)

    try:
        tenants = Tenant.objects.filter(is_active=True).exclude(schema_name='public')
        for tenant in tenants:
            with schema_context(tenant.schema_name):
                admin_manager_users = User.objects.filter(role__in=['ADMIN', 'MANAGER'], is_active=True)
                if not admin_manager_users:
                    continue
                expiring = StockEntry.objects.filter(
                    expiry_date__isnull=False,
                    expiry_date__lte=cutoff,
                    expiry_date__gte=timezone.now().date(),
                ).select_related('variant__product', 'location')
                if not expiring:
                    continue

                for entry in expiring:
                    days = (entry.expiry_date - timezone.now().date()).days
                    msg = (f'Expiry alert: {entry.variant.product.name} {entry.variant.size} {entry.variant.flavour} '
                           f'(Batch: {entry.batch_number}) expires in {days} days ({entry.expiry_date})')
                    for user in admin_manager_users:
                        recent = Notification.objects.filter(
                            user=user, type='EXPIRY',
                            message__contains=entry.batch_number or entry.variant.sku,
                            created_at__gte=timezone.now() - timezone.timedelta(hours=24)
                        ).exists()
                        if not recent:
                            Notification.objects.create(user=user, message=msg, type='EXPIRY')
                logger.info(f'Expiring batches check completed for tenant {tenant.schema_name}.')
    except Exception as e:
        logger.error(f'Expiring batches check failed: {e}')
        raise self.retry(exc=e, countdown=60 * (2 ** self.request.retries))
