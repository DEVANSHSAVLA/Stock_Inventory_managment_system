from decimal import Decimal
from django.db.models import Sum
from django.core.cache import cache
from django.db import connection
import logging

logger = logging.getLogger(__name__)


def _cache_key(variant_id, location_id, date):
    schema = getattr(connection, 'schema_name', 'public')
    return f'{schema}:stock:{variant_id}:{location_id}:{date}'


def get_live_stock(variant_id, location_id, date):
    """
    Compute live stock for a variant/location/date.
    Formula: opening_stock + SUM(approved IN) - SUM(approved OUT)
    Cached in Redis for 30 seconds.
    """
    key = _cache_key(variant_id, location_id, date)
    try:
        cached = cache.get(key)
        if cached is not None:
            return Decimal(str(cached))
    except Exception as e:
        logger.warning(f'Redis cache get failed: {e}')

    from .models import DailyLedger, StockEntry

    # Find or create today's ledger
    if location_id:
        ledger = DailyLedger.objects.filter(variant_id=variant_id, location_id=location_id, date=date).first()
        opening = ledger.opening_stock if ledger else Decimal('0')
    else:
        # Sum opening stock across all locations
        opening = DailyLedger.objects.filter(variant_id=variant_id, date=date).aggregate(t=Sum('opening_stock'))['t'] or Decimal('0')

    entry_filter = {
        'variant_id': variant_id,
        'timestamp__date': date,
        'is_approved': True,
    }
    if location_id:
        entry_filter['location_id'] = location_id

    total_in = StockEntry.objects.filter(
        entry_type='IN', **entry_filter
    ).aggregate(t=Sum('quantity'))['t'] or Decimal('0')

    total_out = StockEntry.objects.filter(
        entry_type='OUT', **entry_filter
    ).aggregate(t=Sum('quantity'))['t'] or Decimal('0')

    live = opening + total_in - total_out

    try:
        cache.set(key, float(live), timeout=30)
    except Exception as e:
        logger.warning(f'Redis cache set failed: {e}')

    return live


def bulk_get_live_stock(variant_ids, location_id, date):
    """
    Compute live stock in bulk for a list of variants/location/date.
    Returns a dict mapping variant_id to Decimal of live stock.
    Executes exactly 2 queries instead of N * 3.
    """
    from decimal import Decimal
    from django.db.models import Sum
    from .models import DailyLedger, StockEntry

    variant_ids = list(variant_ids)
    if not variant_ids:
        return {}

    # Initialize all requested variants with Decimal('0')
    stock_map = {vid: Decimal('0') for vid in variant_ids}

    # 1. Fetch opening stock
    if location_id:
        ledgers = DailyLedger.objects.filter(
            variant_id__in=variant_ids,
            location_id=location_id,
            date=date
        ).values('variant_id', 'opening_stock')
        for l in ledgers:
            stock_map[l['variant_id']] = l['opening_stock']
    else:
        # Sum opening stock across all locations
        ledgers = DailyLedger.objects.filter(
            variant_id__in=variant_ids,
            date=date
        ).values('variant_id').annotate(total_opening=Sum('opening_stock'))
        for l in ledgers:
            stock_map[l['variant_id']] = l['total_opening'] or Decimal('0')

    # 2. Fetch approved stock entries for today
    entry_filter = {
        'variant_id__in': variant_ids,
        'timestamp__date': date,
        'is_approved': True,
    }
    if location_id:
        entry_filter['location_id'] = location_id

    entries = StockEntry.objects.filter(**entry_filter).values('variant_id', 'entry_type').annotate(total_qty=Sum('quantity'))

    for e in entries:
        vid = e['variant_id']
        qty = e['total_qty'] or Decimal('0')
        if e['entry_type'] == 'IN':
            stock_map[vid] += qty
        elif e['entry_type'] == 'OUT':
            stock_map[vid] -= qty

    return stock_map


def get_live_stock_with_cases(variant_id, location_id, date):
    """
    Returns live stock in both pcs and cases.
    """
    from apps.products.models import Variant
    live_pcs = get_live_stock(variant_id, location_id, date)
    try:
        variant = Variant.objects.get(pk=variant_id)
        case_qty = variant.case_quantity or 1
        live_cases = float(live_pcs) / case_qty
    except Variant.DoesNotExist:
        live_cases = 0
    return {
        'live_stock_pcs': float(live_pcs),
        'live_stock_cases': round(live_cases, 3),
    }


def get_all_live_stock(date):
    """
    Returns a list of all active variants with their live stock in both cases and pcs.
    Cached for 30 seconds.
    """
    from apps.products.models import Variant
    schema = getattr(connection, 'schema_name', 'public')
    cache_key = f'{schema}:dashboard:balance_stock'

    try:
        cached = cache.get(cache_key)
        if cached is not None:
            return cached
    except Exception as e:
        logger.warning(f'Redis cache get failed: {e}')

    variants = list(Variant.objects.filter(is_active=True).select_related('product'))
    v_ids = [v.id for v in variants]
    
    try:
        live_stock_map = bulk_get_live_stock(v_ids, None, date)
    except Exception as e:
        logger.error(f'Error doing bulk live stock fetch in get_all_live_stock: {e}')
        live_stock_map = {}

    result = []
    for v in variants:
        live_pcs = float(live_stock_map.get(v.id, Decimal('0')))
        case_qty = v.case_quantity or 1
        live_cases = round(live_pcs / case_qty, 3)
        result.append({
            'variant_id': v.id,
            'product_name': v.product.name,
            'size': v.size,
            'flavour': v.flavour,
            'sku': v.sku,
            'live_stock_cases': live_cases,
            'live_stock_pcs': live_pcs,
            'erp_price': float(v.erp_price) if v.erp_price else None,
            'selling_price': float(v.selling_price) if v.selling_price else None,
        })

    try:
        cache.set(cache_key, result, timeout=30)
    except Exception as e:
        logger.warning(f'Redis cache set failed: {e}')

    return result


def invalidate_stock_cache(variant_id, location_id):
    """Invalidate the cached live stock for the given variant+location."""
    from django.utils import timezone
    today = timezone.now().date()
    key = _cache_key(variant_id, location_id, today)
    try:
        cache.delete(key)
        # Also invalidate the dashboard balance_stock cache
        schema = getattr(connection, 'schema_name', 'public')
        cache.delete(f'{schema}:dashboard:balance_stock')
    except Exception as e:
        logger.warning(f'Redis cache delete failed: {e}')
