from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from rest_framework import status
from rest_framework.response import Response
from django.utils import timezone
from .models import StockEntry, StockTransfer
from .serializers import StockEntrySerializer, StockTransferSerializer
from .stock_engine import get_live_stock, invalidate_stock_cache, get_all_live_stock
from apps.audit.utils import log_audit
from apps.products.models import Variant


def ok(data=None, msg='', code=status.HTTP_200_OK):
    return Response({'success': True, 'data': data or {}, 'message': msg, 'errors': {}}, status=code)

def err(errors=None, msg='', code=status.HTTP_400_BAD_REQUEST):
    return Response({'success': False, 'data': {}, 'message': msg, 'errors': errors or {}}, status=code)


class StockIncomingView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        data = request.data.copy()
        s = StockEntrySerializer(data=data)
        if not s.is_valid():
            return err(errors=s.errors)
        is_approved = request.user.is_admin or request.user.is_manager
        approved_by = request.user if is_approved else None
        entry = s.save(logged_by=request.user, entry_type='IN', is_approved=is_approved, approved_by=approved_by)
        if is_approved:
            invalidate_stock_cache(entry.variant_id, entry.location_id)
            msg = 'Stock IN entry created and auto-approved.'
        else:
            msg = 'Stock IN entry created, pending approval.'
        log_audit(request, 'CREATE', 'StockEntry', entry.pk, None, s.data)
        return ok(data=s.data, msg=msg, code=status.HTTP_201_CREATED)


class StockOutgoingView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        data = request.data.copy()
        s = StockEntrySerializer(data=data)
        if not s.is_valid():
            return err(errors=s.errors)
        is_approved = request.user.is_admin or request.user.is_manager
        approved_by = request.user if is_approved else None
        entry = s.save(logged_by=request.user, entry_type='OUT', is_approved=is_approved, approved_by=approved_by)
        if is_approved:
            invalidate_stock_cache(entry.variant_id, entry.location_id)
            msg = 'Stock OUT entry created and auto-approved.'
        else:
            msg = 'Stock OUT entry created, pending approval.'
        log_audit(request, 'CREATE', 'StockEntry', entry.pk, None, s.data)
        return ok(data=s.data, msg=msg, code=status.HTTP_201_CREATED)


class StockAdjustmentView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        data = request.data.copy()
        qty = float(data.get('quantity', 0))
        if qty == 0:
            return err(msg='Quantity must be non-zero.')
        
        variant_id = data.get('variant')
        reason = data.get('reason', '')
        notes = data.get('notes', '')
        
        full_note = f'Adjustment: {reason}. {notes}'.strip()
        
        entry_type = 'IN' if qty > 0 else 'OUT'
        abs_qty = abs(qty)
        
        data['entry_type'] = entry_type
        data['quantity'] = abs_qty
        data['note'] = full_note
        
        s = StockEntrySerializer(data=data)
        if not s.is_valid():
            return err(errors=s.errors)
            
        is_approved = request.user.is_admin or request.user.is_manager
        approved_by = request.user if is_approved else None
        
        entry = s.save(
            logged_by=request.user, 
            entry_type=entry_type, 
            quantity=abs_qty,
            is_approved=is_approved, 
            approved_by=approved_by
        )
        
        if is_approved:
            invalidate_stock_cache(entry.variant_id, entry.location_id)
            msg = 'Stock adjustment auto-approved.'
        else:
            msg = 'Stock adjustment recorded, pending approval.'
            
        log_audit(request, 'CREATE', 'StockEntry', entry.pk, None, s.data)
        return ok(data=s.data, msg=msg, code=status.HTTP_201_CREATED)


class StockEntriesView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = StockEntry.objects.select_related('variant__product', 'location', 'logged_by', 'approved_by').all()
        date = request.query_params.get('date')
        variant = request.query_params.get('variant')
        entry_type = request.query_params.get('type')
        is_approved = request.query_params.get('status')
        location = request.query_params.get('location')
        if date:
            qs = qs.filter(timestamp__date=date)
        if variant:
            qs = qs.filter(variant_id=variant)
        if entry_type:
            qs = qs.filter(entry_type=entry_type.upper())
        if is_approved is not None:
            qs = qs.filter(is_approved=is_approved.lower() == 'true')
        if location:
            qs = qs.filter(location_id=location)
        # Staff can only see own entries
        if request.user.is_staff_role:
            qs = qs.filter(logged_by=request.user)
        qs = qs.order_by('-timestamp')
        return ok(data={'results': StockEntrySerializer(qs, many=True).data, 'count': qs.count()})


class StockEntryApproveView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        from django.db import transaction
        if not (request.user.is_admin or request.user.is_manager):
            return err(msg='Permission denied.', code=status.HTTP_403_FORBIDDEN)
        try:
            with transaction.atomic():
                # Lock row to prevent double-approval from concurrent requests
                entry = StockEntry.objects.select_for_update().get(pk=pk)
                if entry.is_approved:
                    return err(msg='Already approved.')
                entry.is_approved = True
                entry.approved_by = request.user
                entry.save()
                invalidate_stock_cache(entry.variant_id, entry.location_id)
                log_audit(request, 'UPDATE', 'StockEntry', entry.pk, {'is_approved': False}, {'is_approved': True})
                return ok(data=StockEntrySerializer(entry).data, msg='Entry approved.')
        except StockEntry.DoesNotExist:
            return err(msg='Entry not found.', code=status.HTTP_404_NOT_FOUND)


class LiveStockView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        today = timezone.now().date()
        location_id = request.query_params.get('location')
        variants = list(Variant.objects.filter(is_active=True).select_related('product'))
        
        # Optimize using bulk stock prefetching to eliminate N+1 queries
        from .stock_engine import bulk_get_live_stock
        v_ids = [v.id for v in variants]
        try:
            live_stock_map = bulk_get_live_stock(v_ids, int(location_id) if location_id else None, today)
        except Exception as e:
            import logging
            logging.getLogger('django').error(f"Error bulk prefetching stock in LiveStockView: {e}")
            live_stock_map = {}

        result = []
        for v in variants:
            live = float(live_stock_map.get(v.id, 0))
            case_qty = v.case_quantity or 1
            result.append({
                'variant_id': v.id,
                'sku': v.sku,
                'product_name': v.product.name,
                'size': v.size,
                'flavour': v.flavour,
                'live_stock': live,
                'live_stock_pcs': live,
                'live_stock_cases': round(live / case_qty, 3),
                'reorder_point': v.reorder_point,
                'is_low': live <= v.reorder_point,
            })
        return ok(data={'results': result, 'count': len(result)})


class LiveStockVariantView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, variant_id):
        today = timezone.now().date()
        location_id = request.query_params.get('location')
        try:
            v = Variant.objects.get(pk=variant_id)
        except Variant.DoesNotExist:
            return err(msg='Variant not found.', code=status.HTTP_404_NOT_FOUND)
        try:
            live = get_live_stock(v.id, int(location_id) if location_id else None, today)
        except Exception as e:
            import logging
            logging.getLogger('django').error(f"Error getting live stock for variant {v.id}: {e}")
            live = 0.0
        case_qty = v.case_quantity or 1
        return ok(data={
            'variant_id': v.id,
            'sku': v.sku,
            'live_stock': float(live),
            'live_stock_pcs': float(live),
            'live_stock_cases': round(float(live) / case_qty, 3),
            'reorder_point': v.reorder_point,
        })


class StockTransferListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = StockTransfer.objects.select_related(
            'from_location', 'to_location', 'variant__product', 'transferred_by'
        ).all()
        from_date = request.query_params.get('from_date')
        to_date = request.query_params.get('to_date')
        location = request.query_params.get('location')
        if from_date:
            qs = qs.filter(timestamp__date__gte=from_date)
        if to_date:
            qs = qs.filter(timestamp__date__lte=to_date)
        if location:
            qs = qs.filter(from_location_id=location) | qs.filter(to_location_id=location)
        qs = qs.order_by('-timestamp')
        return ok(data={'results': StockTransferSerializer(qs, many=True).data, 'count': qs.count()})

    def post(self, request):
        from django.db import transaction

        s = StockTransferSerializer(data=request.data)
        if not s.is_valid():
            return err(errors=s.errors)
        
        with transaction.atomic():
            transfer = s.save(transferred_by=request.user)
            # Auto-create OUT entry for source location
            StockEntry.objects.create(
                variant=transfer.variant,
                location=transfer.from_location,
                entry_type='OUT',
                quantity=transfer.quantity,
                note=f'Transfer to {transfer.to_location.name}: {transfer.note}',
                logged_by=request.user,
                is_approved=True,
                approved_by=request.user,
            )
            # Auto-create IN entry for destination location
            StockEntry.objects.create(
                variant=transfer.variant,
                location=transfer.to_location,
                entry_type='IN',
                quantity=transfer.quantity,
                note=f'Transfer from {transfer.from_location.name}: {transfer.note}',
                logged_by=request.user,
                is_approved=True,
                approved_by=request.user,
            )
            invalidate_stock_cache(transfer.variant_id, transfer.from_location_id)
            invalidate_stock_cache(transfer.variant_id, transfer.to_location_id)
        log_audit(request, 'CREATE', 'StockTransfer', transfer.pk, None, s.data)
        return ok(data=s.data, msg='Transfer recorded.', code=status.HTTP_201_CREATED)


class DashboardSummaryView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from apps.products.models import Product
        from django.db.models import Sum
        from django.core.cache import cache
        from django.db import connection
        from .models import Order

        today = timezone.now().date()
        schema = getattr(connection, 'schema_name', 'public')
        cache_key = f'dashboard:{schema}:{today}'
        user_role = request.user.role

        # ── Build base dashboard data ──────────────────────────────────
        # Try cache first
        base_data = None
        try:
            base_data = cache.get(cache_key)
        except Exception as e:
            import logging
            logging.getLogger('django').warning(f"Redis get failed: {e}")

        if not base_data:
            total_products = Product.objects.filter(is_active=True).count()
            variants = list(Variant.objects.filter(is_active=True))

            # Low stock count
            low_stock_count = 0
            v_ids = [v.id for v in variants]
            from .stock_engine import bulk_get_live_stock
            try:
                live_stock_map = bulk_get_live_stock(v_ids, None, today)
            except Exception as e:
                import logging
                logging.getLogger('django').error(f"Error bulk stock prefetch for dashboard: {e}")
                live_stock_map = {}

            for v in variants:
                live = float(live_stock_map.get(v.id, 0))
                if live <= v.reorder_point:
                    low_stock_count += 1

            today_entries = StockEntry.objects.filter(timestamp__date=today, is_approved=True)
            today_in = today_entries.filter(entry_type='IN').aggregate(total=Sum('quantity'))['total'] or 0
            today_out = today_entries.filter(entry_type='OUT').aggregate(total=Sum('quantity'))['total'] or 0

            # Top 5 movers today
            from django.db.models import Sum as DbSum
            top_movers_qs = today_entries.values(
                'variant__id', 'variant__sku', 'variant__product__name'
            ).annotate(total_qty=DbSum('quantity')).order_by('-total_qty')[:5]
            top_movers = list(top_movers_qs)

            # Recent 10 entries
            recent_entries = StockEntry.objects.select_related(
                'variant__product', 'location', 'logged_by'
            ).order_by('-timestamp')[:10]

            base_data = {
                'total_products': total_products,
                'low_stock_count': low_stock_count,
                'today_in_qty': float(today_in),
                'today_out_qty': float(today_out),
                'top_5_movers': top_movers,
                'recent_10_entries': StockEntrySerializer(recent_entries, many=True).data,
            }

            # Cache for 30 seconds
            try:
                cache.set(cache_key, base_data, timeout=30)
            except Exception as e:
                import logging
                logging.getLogger('django').warning(f"Redis set failed: {e}")

        result = dict(base_data)

        # ── U5: Balance stock (all roles except pure WAREHOUSE) ──────
        if user_role in ('ADMIN', 'MANAGER', 'VIEWER', 'SALES', 'STAFF'):
            result['balance_stock'] = get_all_live_stock(today)

        # ── U5: Pending for delivery ────────────────────────────────
        pending_orders_qs = Order.objects.filter(
            status__in=[Order.STATUS_PENDING, Order.STATUS_CONFIRMED, Order.STATUS_DISPATCHED]
        ).select_related('warehouse').order_by('-created_at')
        pending_count = pending_orders_qs.count()

        pending_list = []
        for o in pending_orders_qs[:20]:
            # Calculate total cases for the order
            total_cases = sum(
                item.cases or 0 for item in o.items.all()
            )
            pending_list.append({
                'order_number': o.order_number,
                'customer_name': o.customer_name,
                'cases': total_cases,
                'transport': o.transport or '',
                'status': o.status,
                'warehouse': o.warehouse.name if o.warehouse else '',
            })

        result['pending_for_delivery'] = {
            'count': pending_count,
            'orders': pending_list,
        }

        # ── Role gating: trim response per role ─────────────────────
        if user_role == 'WAREHOUSE':
            # Warehouse sees only pending_for_delivery
            return ok(data={
                'pending_for_delivery': result['pending_for_delivery'],
            })
        elif user_role in ('VIEWER', 'SALES'):
            # Viewer + Sales see balance_stock + pending only
            return ok(data={
                'balance_stock': result.get('balance_stock', []),
                'pending_for_delivery': result['pending_for_delivery'],
            })

        # ADMIN + MANAGER → full dashboard
        return ok(data=result)


class OrderListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from .models import Order
        from .serializers import OrderSerializer
        qs = Order.objects.select_related('created_by', 'approved_by', 'warehouse').prefetch_related(
            'items__variant__product', 'items__location'
        ).all()
        status_param = request.query_params.get('status')
        if status_param:
            qs = qs.filter(status=status_param.upper())
        qs = qs.order_by('-created_at')
        
        try:
            limit = int(request.query_params.get('limit', 50))
            offset = int(request.query_params.get('offset', 0))
        except ValueError:
            limit, offset = 50, 0
            
        count = qs.count()
        qs_slice = qs[offset:offset+limit]
        
        return ok(data={'results': OrderSerializer(qs_slice, many=True).data, 'count': count, 'limit': limit, 'offset': offset})

    def post(self, request):
        from .permissions import CanCreateOrder
        if not CanCreateOrder().has_permission(request, self):
            return err(msg='Permission denied.', code=403)
        
        from .services import create_order_with_reservation
        from .serializers import OrderSerializer
        try:
            order = create_order_with_reservation(request.data, request.data.get('items', []), request.user)
            return ok(data=OrderSerializer(order).data, msg='Order created and stock reserved.', code=201)
        except ValueError as e:
            return err(msg=str(e))
        except Exception as e:
            return err(msg=f'Error creating order: {str(e)}', code=500)


class OrderActionView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk, action):
        from django.db import transaction
        from .models import Order
        from .serializers import OrderSerializer
        from .services import release_reservation, confirm_delivery
        from .permissions import CanApproveOrder, CanDispatch, CanMarkDelivered

        try:
            with transaction.atomic():
                # Lock the order row to prevent concurrent state transitions
                order = Order.objects.select_for_update().get(pk=pk)

                if action == 'cancel':
                    if not CanApproveOrder().has_permission(request, self):
                        return err(msg='Permission denied.', code=403)
                    if order.status in [Order.STATUS_DELIVERED, Order.STATUS_CANCELLED]:
                        return err(msg='Cannot cancel this order.')
                    release_reservation(order)
                    order.status = Order.STATUS_CANCELLED
                    order.save()
                    return ok(data=OrderSerializer(order).data, msg='Order cancelled and reservations released.')

                elif action == 'confirm':
                    if not CanApproveOrder().has_permission(request, self):
                        return err(msg='Permission denied.', code=403)
                    if order.status != Order.STATUS_PENDING:
                        return err(msg='Only pending orders can be confirmed.')
                    order.status = Order.STATUS_CONFIRMED
                    order.approved_by = request.user
                    order.save()
                    return ok(data=OrderSerializer(order).data, msg='Order confirmed.')

                elif action == 'dispatch':
                    if not CanDispatch().has_permission(request, self):
                        return err(msg='Permission denied.', code=403)
                    if order.status != Order.STATUS_CONFIRMED:
                        return err(msg='Only confirmed orders can be dispatched.')
                    order.status = Order.STATUS_DISPATCHED
                    order.save()
                    return ok(data=OrderSerializer(order).data, msg='Order dispatched.')

                elif action == 'deliver':
                    if not CanMarkDelivered().has_permission(request, self):
                        return err(msg='Permission denied.', code=403)
                    if order.status != Order.STATUS_DISPATCHED:
                        return err(msg='Order must be dispatched before marking delivered.')
                    order = confirm_delivery(order, request.user)
                    return ok(data=OrderSerializer(order).data, msg='Order delivered. Stock updated.')

                return err(msg='Invalid action.')

        except Order.DoesNotExist:
            return err(msg='Order not found.', code=404)
        except ValueError as e:
            return err(msg=str(e))
