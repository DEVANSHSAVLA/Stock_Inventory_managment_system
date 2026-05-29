from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from rest_framework import status
from rest_framework.response import Response
from .models import Supplier, PurchaseOrder
from .serializers import SupplierSerializer, PurchaseOrderSerializer
from apps.audit.utils import log_audit


def ok(data=None, msg='', code=status.HTTP_200_OK):
    return Response({'success': True, 'data': data or {}, 'message': msg, 'errors': {}}, status=code)

def err(errors=None, msg='', code=status.HTTP_400_BAD_REQUEST):
    return Response({'success': False, 'data': {}, 'message': msg, 'errors': errors or {}}, status=code)


class SupplierListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = Supplier.objects.all().order_by('name')
        return ok(data={'results': SupplierSerializer(qs, many=True).data, 'count': qs.count()})

    def post(self, request):
        if not (request.user.is_admin or request.user.is_manager):
            return err(msg='Permission denied.', code=status.HTTP_403_FORBIDDEN)
        s = SupplierSerializer(data=request.data)
        if not s.is_valid():
            return err(errors=s.errors)
        supplier = s.save()
        log_audit(request, 'CREATE', 'Supplier', supplier.pk, None, s.data)
        return ok(data=s.data, msg='Supplier created.', code=status.HTTP_201_CREATED)


class SupplierDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get_object(self, pk):
        try:
            return Supplier.objects.get(pk=pk)
        except Supplier.DoesNotExist:
            return None

    def get(self, request, pk):
        s = self.get_object(pk)
        if not s:
            return err(msg='Not found.', code=status.HTTP_404_NOT_FOUND)
        return ok(data=SupplierSerializer(s).data)

    def put(self, request, pk):
        if not (request.user.is_admin or request.user.is_manager):
            return err(msg='Permission denied.', code=status.HTTP_403_FORBIDDEN)
        supplier = self.get_object(pk)
        if not supplier:
            return err(msg='Not found.', code=status.HTTP_404_NOT_FOUND)
        old_data = SupplierSerializer(supplier).data
        s = SupplierSerializer(supplier, data=request.data, partial=True)
        if not s.is_valid():
            return err(errors=s.errors)
        supplier = s.save()
        log_audit(request, 'UPDATE', 'Supplier', supplier.pk, old_data, s.data)
        return ok(data=s.data, msg='Supplier updated.')


class PurchaseOrderListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if request.user.is_staff_role:
            return err(msg='Permission denied.', code=status.HTTP_403_FORBIDDEN)
        qs = PurchaseOrder.objects.select_related('supplier', 'created_by').order_by('-created_at')
        return ok(data={'results': PurchaseOrderSerializer(qs, many=True).data, 'count': qs.count()})

    def post(self, request):
        if request.user.is_staff_role:
            return err(msg='Permission denied.', code=status.HTTP_403_FORBIDDEN)
        s = PurchaseOrderSerializer(data=request.data)
        if not s.is_valid():
            return err(errors=s.errors)
        po = s.save(created_by=request.user)
        log_audit(request, 'CREATE', 'PurchaseOrder', po.pk, None, s.data)
        return ok(data=s.data, msg='Purchase order created.', code=status.HTTP_201_CREATED)


class PurchaseOrderDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get_object(self, pk):
        try:
            return PurchaseOrder.objects.get(pk=pk)
        except PurchaseOrder.DoesNotExist:
            return None

    def get(self, request, pk):
        if request.user.is_staff_role:
            return err(msg='Permission denied.', code=status.HTTP_403_FORBIDDEN)
        po = self.get_object(pk)
        if not po:
            return err(msg='Not found.', code=status.HTTP_404_NOT_FOUND)
        return ok(data=PurchaseOrderSerializer(po).data)

    def put(self, request, pk):
        if not (request.user.is_admin or request.user.is_manager):
            return err(msg='Permission denied.', code=status.HTTP_403_FORBIDDEN)
        po = self.get_object(pk)
        if not po:
            return err(msg='Not found.', code=status.HTTP_404_NOT_FOUND)
        old_data = PurchaseOrderSerializer(po).data
        s = PurchaseOrderSerializer(po, data=request.data, partial=True)
        if not s.is_valid():
            return err(errors=s.errors)
        po = s.save()
        log_audit(request, 'UPDATE', 'PurchaseOrder', po.pk, old_data, s.data)
        return ok(data=s.data, msg='Purchase order updated.')


class PurchaseOrderReceiveView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        if not (request.user.is_admin or request.user.is_manager):
            return err(msg='Permission denied.', code=status.HTTP_403_FORBIDDEN)
        try:
            po = PurchaseOrder.objects.get(pk=pk)
        except PurchaseOrder.DoesNotExist:
            return err(msg='Not found.', code=status.HTTP_404_NOT_FOUND)
        if po.status == PurchaseOrder.STATUS_RECEIVED:
            return err(msg='Already received.')
        from apps.stock.models import StockEntry
        from apps.products.models import Variant
        from apps.locations.models import Location
        location_id = request.data.get('location_id')
        try:
            location = Location.objects.get(pk=location_id) if location_id else Location.objects.filter(is_active=True).first()
        except Location.DoesNotExist:
            return err(msg='Location not found.')
        for item in po.items:
            try:
                variant = Variant.objects.get(pk=item['variant_id'])
                StockEntry.objects.create(
                    variant=variant,
                    location=location,
                    entry_type='IN',
                    quantity=item['qty'],
                    supplier=po.supplier,
                    note=f'PO-{po.pk} received',
                    logged_by=request.user,
                    is_approved=True,
                    approved_by=request.user,
                )
            except (Variant.DoesNotExist, KeyError):
                continue
        po.status = PurchaseOrder.STATUS_RECEIVED
        po.save()
        log_audit(request, 'UPDATE', 'PurchaseOrder', po.pk, {'status': 'SENT'}, {'status': 'RECEIVED'})
        return ok(msg='Purchase order received and stock entries created.')
