from django.db import transaction
from django.db.models import Sum
from django.utils import timezone
from .models import Order, OrderItem, StockReservation, StockEntry
from .stock_engine import get_live_stock, invalidate_stock_cache
import logging

logger = logging.getLogger(__name__)


def get_available_stock(variant_id, location_id):
    """
    Get available stock: total live stock minus active reservations.

    Uses select_for_update() on active reservations to acquire a row-level
    lock inside the calling transaction, preventing two concurrent orders
    from reading the same available quantity.
    """
    live = float(get_live_stock(variant_id, location_id, timezone.now().date()))
    reserved = StockReservation.objects.select_for_update().filter(
        variant_id=variant_id,
        location_id=location_id,
        released_at__isnull=True,
    ).aggregate(total=Sum('quantity'))['total'] or 0
    return live - float(reserved)


@transaction.atomic
def create_order_with_reservation(data, items_data, user):
    """
    Atomic: Create Order + OrderItems + StockReservations.

    The entire operation runs inside a transaction. get_available_stock
    acquires row-level locks on existing reservations, so concurrent
    requests will serialize on the same variant+location pair.

    Raises ValueError if insufficient stock for any line item.
    """
    if not items_data:
        raise ValueError('At least one item is required.')

    # Phase 1: Validate stock availability for ALL items (locks held)
    for item in items_data:
        variant_id = item.get('variant_id')
        location_id = item.get('location_id')
        quantity = float(item.get('quantity', 0))

        if not variant_id or not location_id:
            raise ValueError('Each item requires variant_id and location_id.')
        if quantity <= 0:
            raise ValueError('Quantity must be greater than zero.')

        available = get_available_stock(variant_id, location_id)
        if available < quantity:
            from apps.products.models import Variant
            variant = Variant.objects.get(pk=variant_id)
            raise ValueError(
                f'Insufficient stock for {variant.product.name} {variant.size} {variant.flavour}. '
                f'Available: {available}, Requested: {quantity}'
            )

    # Phase 2: Create Order
    is_delivered_at_booking = data.get('is_delivered_at_booking', False)
    
    order = Order.objects.create(
        customer_name=data['customer_name'],
        customer_phone=data.get('customer_phone', ''),
        customer_address=data.get('customer_address', ''),
        date=data.get('date', timezone.now().date()),
        transport=data.get('transport', ''),
        transport_carrier=data.get('transport_carrier', ''),
        transport_vehicle=data.get('transport_vehicle', ''),
        transport_driver=data.get('transport_driver', ''),
        warehouse_id=data.get('warehouse') if data.get('warehouse') else None,
        is_delivered_at_booking=is_delivered_at_booking,
        notes=data.get('notes', ''),
        created_by=user,
    )

    # Phase 3: Create OrderItems + StockReservations
    for item in items_data:
        OrderItem.objects.create(
            order=order,
            variant_id=item['variant_id'],
            location_id=item['location_id'],
            quantity=item['quantity'],
            cases=item.get('cases', 0),
            unit_price=item.get('unit_price', 0),
        )
        StockReservation.objects.create(
            variant_id=item['variant_id'],
            location_id=item['location_id'],
            order=order,
            quantity=item['quantity'],
        )
        invalidate_stock_cache(item['variant_id'], item['location_id'])

    logger.info(f'Order {order.order_number} created by {user.email} with {len(items_data)} items')
    
    if is_delivered_at_booking:
        # Confirm delivery directly if checked
        order.status = Order.STATUS_DISPATCHED
        order.save()
        order = confirm_delivery(order, user)
        
    return order


@transaction.atomic
def release_reservation(order):
    """
    Release all active reservations for a cancelled/delivered order.
    Uses select_for_update to prevent double-release under concurrency.
    """
    reservations = order.reservations.select_for_update().filter(released_at__isnull=True)
    now = timezone.now()
    count = 0
    for res in reservations:
        res.released_at = now
        res.save()
        invalidate_stock_cache(res.variant_id, res.location_id)
        count += 1
    logger.info(f'Released {count} reservations for order {order.order_number}')


@transaction.atomic
def confirm_delivery(order, user):
    """
    Mark order as Delivered:
    1. Lock order row to prevent concurrent delivery attempts.
    2. Create StockEntry(OUT) for each item.
    3. Release reservations.
    """
    # Lock the order row itself to prevent concurrent delivery attempts
    order = Order.objects.select_for_update().get(pk=order.pk)
    if order.status == Order.STATUS_DELIVERED:
        raise ValueError('Order is already delivered.')

    for item in order.items.select_for_update().all():
        StockEntry.objects.create(
            variant=item.variant,
            location=item.location,
            entry_type='OUT',
            quantity=item.quantity,
            reference_number=order.order_number,
            note=f'Order delivery: {order.order_number}',
            logged_by=user,
            approved_by=user,
            is_approved=True,
        )

    release_reservation(order)

    order.status = Order.STATUS_DELIVERED
    order.save()
    logger.info(f'Order {order.order_number} delivered by {user.email}')
    return order
