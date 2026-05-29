from celery import shared_task
import logging

logger = logging.getLogger(__name__)


@shared_task
def auto_generate_purchase_orders():
    from apps.products.models import Variant
    from apps.stock.stock_engine import get_live_stock
    from .models import Supplier, PurchaseOrder
    from django.utils import timezone

    today = timezone.now().date()
    low_variants = []
    variants = list(Variant.objects.filter(is_active=True).select_related('product'))
    v_ids = [v.id for v in variants]
    from apps.stock.stock_engine import bulk_get_live_stock
    try:
        live_stock_map = bulk_get_live_stock(v_ids, None, today)
    except Exception as e:
        logger.error(f'Error doing bulk stock prefetch in auto_generate_purchase_orders: {e}')
        live_stock_map = {}

    for v in variants:
        live = float(live_stock_map.get(v.id, 0))
        if live <= v.reorder_point:
            low_variants.append(v)

    if not low_variants:
        logger.info('No low-stock variants found. No POs generated.')
        return

    # Group by supplier
    supplier_items = {}
    for v in low_variants:
        supplier = v.suppliers.filter(is_active=True).first()
        if supplier:
            if supplier.id not in supplier_items:
                supplier_items[supplier.id] = {'supplier': supplier, 'items': []}
            supplier_items[supplier.id]['items'].append({
                'variant_id': v.id,
                'qty': v.reorder_qty,
                'unit_price': 0,
            })

    for sid, data in supplier_items.items():
        existing = PurchaseOrder.objects.filter(
            supplier=data['supplier'],
            status=PurchaseOrder.STATUS_DRAFT,
            created_at__date=today
        ).exists()
        if not existing:
            PurchaseOrder.objects.create(
                supplier=data['supplier'],
                items=data['items'],
                notes=f'Auto-generated for low-stock variants on {today}',
            )
    logger.info(f'Auto-generated {len(supplier_items)} purchase orders.')
