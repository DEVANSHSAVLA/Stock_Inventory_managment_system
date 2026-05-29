import os
import uuid
import openpyxl
from django.conf import settings
from django.core.files.storage import default_storage
from django.core.files.base import ContentFile
from django.db import models, IntegrityError
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from rest_framework import status
from rest_framework.response import Response
from .models import Product, Variant
from .serializers import ProductSerializer, ProductListSerializer, VariantSerializer
from apps.audit.utils import log_audit
from apps.stock.stock_engine import get_live_stock


def ok(data=None, msg='', code=status.HTTP_200_OK):
    return Response({'success': True, 'data': data or {}, 'message': msg, 'errors': {}}, status=code)

def err(errors=None, msg='', code=status.HTTP_400_BAD_REQUEST):
    return Response({'success': False, 'data': {}, 'message': msg, 'errors': errors or {}}, status=code)


class ProductListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = Product.objects.all()
        category = request.query_params.get('category')
        is_active = request.query_params.get('is_active')
        search = request.query_params.get('search')
        if category:
            qs = qs.filter(category__icontains=category)
        if is_active is not None:
            qs = qs.filter(is_active=is_active.lower() == 'true')
        if search:
            qs = qs.filter(name__icontains=search)
        qs = qs.order_by('name')
        
        # Pagination
        try:
            limit = int(request.query_params.get('limit', 50))
            offset = int(request.query_params.get('offset', 0))
        except ValueError:
            limit, offset = 50, 0
            
        count = qs.count()
        qs_slice = qs[offset:offset+limit]
        serializer = ProductListSerializer(qs_slice, many=True)
        return ok(data={'results': serializer.data, 'count': count, 'limit': limit, 'offset': offset})

    def post(self, request):
        if not (request.user.is_admin or request.user.is_manager):
            return err(msg='Permission denied.', code=status.HTTP_403_FORBIDDEN)
        s = ProductSerializer(data=request.data)
        if not s.is_valid():
            return err(errors=s.errors)
        try:
            product = s.save()
        except IntegrityError as e:
            return err(msg=f'Database validation failed: {str(e)}', code=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            return err(msg=f'Error saving product: {str(e)}', code=status.HTTP_400_BAD_REQUEST)
        log_audit(request, 'CREATE', 'Product', product.pk, None, s.data)
        return ok(data=s.data, msg='Product created.', code=status.HTTP_201_CREATED)


class ProductDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get_object(self, pk):
        try:
            return Product.objects.get(pk=pk)
        except Product.DoesNotExist:
            return None

    def get(self, request, pk):
        product = self.get_object(pk)
        if not product:
            return err(msg='Not found.', code=status.HTTP_404_NOT_FOUND)
        return ok(data=ProductSerializer(product).data)

    def put(self, request, pk):
        if not (request.user.is_admin or request.user.is_manager):
            return err(msg='Permission denied.', code=status.HTTP_403_FORBIDDEN)
        product = self.get_object(pk)
        if not product:
            return err(msg='Not found.', code=status.HTTP_404_NOT_FOUND)
        old_data = ProductSerializer(product).data
        s = ProductSerializer(product, data=request.data, partial=True)
        if not s.is_valid():
            return err(errors=s.errors)
        try:
            product = s.save()
        except IntegrityError as e:
            return err(msg=f'Database validation failed: {str(e)}', code=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            return err(msg=f'Error saving product: {str(e)}', code=status.HTTP_400_BAD_REQUEST)
        log_audit(request, 'UPDATE', 'Product', product.pk, old_data, s.data)
        return ok(data=s.data, msg='Product updated.')

    def delete(self, request, pk):
        if not request.user.is_admin:
            return err(msg='Admin only.', code=status.HTTP_403_FORBIDDEN)
        product = self.get_object(pk)
        if not product:
            return err(msg='Not found.', code=status.HTTP_404_NOT_FOUND)
        old_data = ProductSerializer(product).data
        product.is_active = False
        product.save()
        log_audit(request, 'DELETE', 'Product', product.pk, old_data, None)
        return ok(msg='Product deactivated.')


class VariantListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = Variant.objects.select_related('product').all()
        product_id = request.query_params.get('product')
        search = request.query_params.get('search')
        barcode = request.query_params.get('barcode')
        if product_id:
            qs = qs.filter(product_id=product_id)
        if search:
            qs = qs.filter(sku__icontains=search) | qs.filter(product__name__icontains=search)
        if barcode:
            qs = qs.filter(barcode=barcode)
            
        qs = qs.order_by('id')
            
        # Pagination
        try:
            limit = int(request.query_params.get('limit', 50))
            offset = int(request.query_params.get('offset', 0))
        except ValueError:
            limit, offset = 50, 0
            
        count = qs.count()
        qs_slice = list(qs[offset:offset+limit])

        # Optimize using bulk stock prefetching to eliminate N+1 queries
        from apps.stock.stock_engine import bulk_get_live_stock
        from django.utils import timezone
        today = timezone.now().date()
        v_ids = [v.id for v in qs_slice]
        try:
            live_stock_map = bulk_get_live_stock(v_ids, None, today)
        except Exception as e:
            import logging
            logging.getLogger('django').error(f"Error bulk prefetching stock in VariantListCreateView: {e}")
            live_stock_map = {}

        serializer = VariantSerializer(qs_slice, many=True, context={'live_stock_map': live_stock_map})
        return ok(data={'results': serializer.data, 'count': count, 'limit': limit, 'offset': offset})

    def post(self, request):
        if not (request.user.is_admin or request.user.is_manager):
            return err(msg='Permission denied.', code=status.HTTP_403_FORBIDDEN)
        s = VariantSerializer(data=request.data)
        if not s.is_valid():
            return err(errors=s.errors)
        try:
            variant = s.save()
        except IntegrityError as e:
            msg = str(e).lower()
            if 'sku' in msg:
                return err(msg='Duplicate variant exists (SKU already taken).', code=status.HTTP_400_BAD_REQUEST)
            elif 'barcode' in msg:
                return err(msg='Duplicate variant exists (Barcode already taken).', code=status.HTTP_400_BAD_REQUEST)
            return err(msg=f'Database validation failed: {str(e)}', code=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            return err(msg=f'Error saving variant: {str(e)}', code=status.HTTP_400_BAD_REQUEST)
        log_audit(request, 'CREATE', 'Variant', variant.pk, None, s.data)
        return ok(data=s.data, msg='Variant created.', code=status.HTTP_201_CREATED)


class VariantDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get_object(self, pk):
        try:
            return Variant.objects.get(pk=pk)
        except Variant.DoesNotExist:
            return None

    def get(self, request, pk):
        v = self.get_object(pk)
        if not v:
            return err(msg='Not found.', code=status.HTTP_404_NOT_FOUND)
        return ok(data=VariantSerializer(v).data)

    def put(self, request, pk):
        if not (request.user.is_admin or request.user.is_manager):
            return err(msg='Permission denied.', code=status.HTTP_403_FORBIDDEN)
        v = self.get_object(pk)
        if not v:
            return err(msg='Not found.', code=status.HTTP_404_NOT_FOUND)
        old_data = VariantSerializer(v).data
        s = VariantSerializer(v, data=request.data, partial=True)
        if not s.is_valid():
            return err(errors=s.errors)
        try:
            v = s.save()
        except IntegrityError as e:
            msg = str(e).lower()
            if 'sku' in msg:
                return err(msg='Duplicate variant exists (SKU already taken).', code=status.HTTP_400_BAD_REQUEST)
            elif 'barcode' in msg:
                return err(msg='Duplicate variant exists (Barcode already taken).', code=status.HTTP_400_BAD_REQUEST)
            return err(msg=f'Database validation failed: {str(e)}', code=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            return err(msg=f'Error saving variant: {str(e)}', code=status.HTTP_400_BAD_REQUEST)
        log_audit(request, 'UPDATE', 'Variant', v.pk, old_data, s.data)
        return ok(data=s.data, msg='Variant updated.')

    def delete(self, request, pk):
        if not request.user.is_admin:
            return err(msg='Admin only.', code=status.HTTP_403_FORBIDDEN)
        v = self.get_object(pk)
        if not v:
            return err(msg='Not found.', code=status.HTTP_404_NOT_FOUND)
        v.is_active = False
        v.save()
        log_audit(request, 'DELETE', 'Variant', v.pk, VariantSerializer(v).data, None)
        return ok(msg='Variant deactivated.')


class VariantMatrixView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from django.utils import timezone
        today = timezone.now().date()
        location_id = request.query_params.get('location')
        variants = list(Variant.objects.select_related('product').filter(is_active=True))
        
        # Optimize with bulk stock prefetching
        from apps.stock.stock_engine import bulk_get_live_stock
        v_ids = [v.id for v in variants]
        try:
            live_stock_map = bulk_get_live_stock(v_ids, int(location_id) if location_id else None, today)
        except Exception as e:
            import logging
            logging.getLogger('django').error(f"Error bulk prefetching stock in VariantMatrixView: {e}")
            live_stock_map = {}

        matrix = {}
        for v in variants:
            pname = v.product.name
            if pname not in matrix:
                matrix[pname] = {}
            key = f'{v.size}|{v.flavour}'
            live = float(live_stock_map.get(v.id, 0))
            matrix[pname][key] = {
                'variant_id': v.id,
                'sku': v.sku,
                'size': v.size,
                'flavour': v.flavour,
                'live_stock': live,
                'reorder_point': v.reorder_point,
            }
        return ok(data={'matrix': matrix})


class VariantBulkImportView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        if not (request.user.is_admin or request.user.is_manager):
            return err(msg='Permission denied.', code=status.HTTP_403_FORBIDDEN)
        file = request.FILES.get('file')
        if not file:
            return err(msg='No file provided.')
        try:
            wb = openpyxl.load_workbook(file)
            ws = wb.active
            created = 0
            errors = []
            for i, row in enumerate(ws.iter_rows(min_row=2, values_only=True), start=2):
                if not row[0]:
                    continue
                try:
                    product_name, category, unit, size, flavour, barcode, reorder_pt, reorder_qty = (
                        row[0], row[1] or 'General', row[2] or 'units',
                        row[3] or '', row[4] or '', row[5] or '',
                        row[6] or 10, row[7] or 50
                    )
                    product, _ = Product.objects.get_or_create(
                        name=product_name,
                        defaults={'category': category, 'unit_of_measure': unit}
                    )
                    Variant.objects.create(
                        product=product, size=size, flavour=flavour,
                        barcode=barcode, reorder_point=reorder_pt, reorder_qty=reorder_qty
                    )
                    created += 1
                except Exception as e:
                    errors.append(f'Row {i}: {str(e)}')
            return ok(data={'created': created, 'errors': errors}, msg=f'{created} variants imported.')
        except Exception as e:
            return err(msg=str(e))


class ProductSearchView(APIView):
    """
    GET /api/products/search/?q=&size=&flavour=
    Joins Variant + Product + live_stock engine.
    Allowed roles: STAFF, SALES, MANAGER, ADMIN.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if request.user.role not in ('ADMIN', 'MANAGER', 'SALES', 'STAFF'):
            return err(msg='Permission denied.', code=status.HTTP_403_FORBIDDEN)

        from django.utils import timezone as tz
        from apps.stock.stock_engine import get_live_stock_with_cases

        q = request.query_params.get('q', '')
        size_filter = request.query_params.get('size', '')
        flavour_filter = request.query_params.get('flavour', '')

        qs = Variant.objects.filter(is_active=True).select_related('product')

        if q:
            qs = qs.filter(
                models.Q(product__name__icontains=q) |
                models.Q(sku__icontains=q) |
                models.Q(barcode__icontains=q)
            )
        if size_filter:
            qs = qs.filter(size__icontains=size_filter)
        if flavour_filter:
            qs = qs.filter(flavour__icontains=flavour_filter)

        today = tz.now().date()
        qs_slice = list(qs[:50])
        
        # Optimize with bulk stock prefetching
        from apps.stock.stock_engine import bulk_get_live_stock
        v_ids = [v.id for v in qs_slice]
        try:
            live_stock_map = bulk_get_live_stock(v_ids, None, today)
        except Exception as e:
            import logging
            logging.getLogger('django').error(f"Error bulk prefetching stock in ProductSearchView: {e}")
            live_stock_map = {}

        results = []
        for v in qs_slice:
            live_pcs = float(live_stock_map.get(v.id, 0))
            case_qty = v.case_quantity or 1
            available_cases = round(live_pcs / case_qty, 3)
            results.append({
                'variant_id': v.id,
                'product_name': v.product.name,
                'size': v.size,
                'flavour': v.flavour,
                'sku': v.sku,
                'available_cases': available_cases,
                'available_pcs': live_pcs,
                'erp_price': float(v.erp_price) if v.erp_price else None,
                'selling_price': float(v.selling_price) if v.selling_price else None,
                'case_weight': float(v.case_weight) if v.case_weight else None,
                'case_dimension': v.case_dimension,
                'drive_image_url': v.drive_image_url or v.product.drive_image_url,
            })

        return ok(data={'results': results, 'count': len(results)})


class ImageUploadView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        file = request.FILES.get('file')
        if not file:
            return err(msg='No file uploaded.')
        
        allowed_extensions = ['.png', '.jpg', '.jpeg', '.gif', '.webp']
        ext = os.path.splitext(file.name)[1].lower()
        if ext not in allowed_extensions:
            return err(msg='Unsupported file format. Only PNG, JPG, JPEG, GIF, WEBP are allowed.')
        
        if file.size > 5 * 1024 * 1024:
            return err(msg='File size exceeds 5MB limit.')

        path_dir = os.path.join(settings.MEDIA_ROOT, 'uploads')
        if not os.path.exists(path_dir):
            os.makedirs(path_dir)
            
        filename = f"{uuid.uuid4()}{ext}"
        full_path = os.path.join('uploads', filename)
        
        saved_path = default_storage.save(full_path, ContentFile(file.read()))
        
        url = request.build_absolute_uri(settings.MEDIA_URL + saved_path)
        return ok(data={'url': url}, msg='Image uploaded successfully.')
